# encoding: utf-8
# log = Flaky::Logcat.new
# log.start; log.stop
module Flaky
  class Logcat
    attr_reader :pid, :in, :out, :err
    @@thread = nil
    @@data = nil

    # Start the logcat process and capture the output
    def start
      # make sure the adb devices command doesn't error.
      while (!POSIX::Spawn::Child.new('adb kill-server; adb devices').err.empty?)
        sleep 0.5
      end

      cmd = 'adb logcat'
      @pid, @in, @@out, @err = POSIX::Spawn::popen4 cmd
      @in.close
      @data = ''

      @@thread.exit if @@thread
      @@thread = Thread.new do
        # out.read blocks until the process ends
        @@data = @@out.read
      end
    end

    # Stop and return the data
    def stop
      begin
        [@in, @out, @err].each { |io| io.close unless io.nil? || io.closed? }
        Process.kill 'KILL', @pid
        Process.waitpid @pid
      rescue
      end

      @@data
    end
  end
end