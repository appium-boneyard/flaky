# encoding: utf-8
module Flaky
  #noinspection RubyResolve
  class Appium
    include POSIX::Spawn
    attr_reader :ready, :pid, :in, :out, :err, :log, :ios, :android
    @@thread = nil

    def self.remove_ios_apps
      # nop -- this feature has moved into the appium server
    end

    def self.kill_all process_name
      POSIX::Spawn::Child.new("killall -9 #{process_name}")
    end

    # android: true to activate Android mode
    def initialize opts={}
      @ready                = false
      @pid, @in, @out, @err = nil
      @log                  = ''
      @buffer               = ''
      @android              = opts.fetch(:android, false)
      @ios                  = !@android
    end

    def start
      @ready = false
      self.stop # stop existing process
      @log = '/tmp/flaky/appium_tmp_log.txt'
      File.delete(@log) if File.exists? @log

      # appium should reset at startup

      @@thread.exit if @@thread
      @@thread = Thread.new do
        Thread.current.abort_on_exception = true
        self.launch.wait
      end

      begin
        timeout 30 do # timeout in seconds
          while !@ready
            sleep 0.5
          end
        end
      rescue Timeout::Error => ex
        # try again if appium fails to become ready
        # sometimes the simulator never launches.
        # the sim crashes or any number of issues.
        #self.start
        raise ex
      end

      # -e = -A = include other user's processes
      # -a = include your own processes
      # -x = include processes without a controlling terminal
      # ps -eax | grep "tail"
      # http://askubuntu.com/questions/157075/why-does-ps-aux-grep-x-give-better-results-than-pgrep-x
    end

    def update_buffer data
      @buffer += data
      self.flush_buffer
    end

    def flush_buffer
      return @log if @buffer.nil? || @buffer.empty?
      File.open(@log, 'a') do |f|
        f.write @buffer
      end
      @buffer = ''
      @log
    end

    ##
    # Internal methods

    def wait
      out_err = [@out, @err]

      # https://github.com/rtomayko/posix-spawn/blob/1d498232660763ff0db6a2f0ab5c1c47fe593896/lib/posix/spawn/child.rb
      while out_err.any?
        io_array = IO.select out_err, [], out_err
        raise 'Appium never spawned' if io_array.nil?

        ready_for_reading = io_array[0]
        stream            = ready_for_reading[0]

        begin
          capture = stream.readpartial 999_999
          if capture
            # $stdout.puts "#{capture}" # verbose logging
            update_buffer(capture)

            # info: Appium REST http interface listener started on 0.0.0.0:4723
            if capture.include?('Appium REST http interface listener started')
              # $stdout.puts 'Appium server successfully started' # verbose logging
              @ready = true
            end
          end
        rescue EOFError
          out_err.delete stream
          stream.close
        end
      end
    end

    # if this is defined using self, then instance methods must refer using
    # self.class.end_all_nodes
    # instead self.end_all_nodes is cleaner.
    # https://github.com/rtomayko/posix-spawn#posixspawn-as-a-mixin
    def end_all_nodes
      self.class.kill_all 'node'
    end

    def end_all_instruments
      self.class.kill_all 'instruments'
    end

    # Invoked inside a thread by `self.go`
    def launch
      @ready = false
      self.end_all_nodes
      appium_home = ENV['APPIUM_HOME']
      raise "ENV['APPIUM_HOME'] must be set!" if appium_home.nil? || appium_home.empty?
      contains_appium = File.exists?(File.join(ENV['APPIUM_HOME'], 'bin', 'appium.js'))
      raise "Appium home `#{appium_home}` doesn't contain bin/appium.js!" unless contains_appium
      cmd                   = %Q(node "#{appium_home}" --log-level debug)
      @pid, @in, @out, @err = popen4 cmd
      @in.close
      self # used to chain `launch.wait`
    end

    def stop
      @ready = false
      # https://github.com/tmm1/pygments.rb/blob/master/lib/pygments/popen.rb
      begin
        Process.kill 'KILL', @pid
      rescue
      end unless @pid.nil?
      @pid = nil
      self.end_all_nodes
      self.end_all_instruments unless @android
    end
  end # class Appium
end # module Flaky