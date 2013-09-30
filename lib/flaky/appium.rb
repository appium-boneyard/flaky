# encoding: utf-8
module Flaky
  #noinspection RubyResolve
  class Appium
    include POSIX::Spawn
    attr_reader :ready, :pid, :in, :out, :err, :log
    @@thread = nil

    def self.remove_ios_apps
      user = ENV['USER']
      raise 'User must be defined' unless user

      # Must kill iPhone simulator or strange install errors will occur.
      self.kill_all 'iPhone Simulator'

      app_glob = "/Users/#{user}/Library/Application Support/iPhone Simulator/6.1/Applications/*"
      Dir.glob(app_glob) do |ios_app_folder|
        FileUtils.rm_rf ios_app_folder
      end
    end

    def self.kill_all process_name
      _pid, _in, _out, _err =  POSIX::Spawn::popen4('killall', '-9', process_name)
      raise "Unable to kill #{process_name}" unless _pid
      _in.close
      _out.read
      _err.read
    ensure
      [_in, _out, _err].each { |io| io.close unless io.nil? || io.closed? }
      Process::waitpid(_pid) if _pid
    end

    def initialize
      @ready = false
      @pid, @in, @out, @err = nil
      @log = ''
    end

    def go
      @log = ''
      self.stop # stop existing process
      self.class.remove_ios_apps

      @@thread.exit if @@thread
      @@thread = Thread.new do
        Thread.current.abort_on_exception = true
        self.start.wait
      end

      while !self.ready
        sleep 0.5
      end
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

        ready_for_reading.each do |stream|
          begin
            capture = stream.readpartial 999_999
            @log += capture if capture
            @ready = true if !@ready && capture.include?('Appium REST http interface listener started')
          rescue EOFError
            out_err.delete stream
            stream.close
          end
        end
      end
    end

    # https://github.com/rtomayko/posix-spawn#posixspawn-as-a-mixin
    def end_all_nodes
      self.class.kill_all 'node'
    end

    # Invoked inside a thread by `self.go`
    def start
      @log = ''
      self.end_all_nodes
      @ready = false
      appium_home = ENV['APPIUM_HOME']
      raise "ENV['APPIUM_HOME'] must be set!" if appium_home.nil? || appium_home.empty?
      contains_appium = File.exists?(File.join(ENV['APPIUM_HOME'], 'server.js'))
      raise "Appium home `#{appium_home}` doesn't contain server.js!" unless contains_appium
      cmd = %Q(cd "#{appium_home}"; node server.js)
      @pid, @in, @out, @err = popen4 cmd
      @in.close
      self # used to chain `start.wait`
    end

    def stop
      @log = ''
      # https://github.com/tmm1/pygments.rb/blob/master/lib/pygments/popen.rb
      begin
        Process.kill 'KILL', @pid
        Process.waitpid @pid
      rescue
      end unless @pid.nil?
      @pid = nil
      self.end_all_nodes
    end
  end # class Appium
end # module Flaky