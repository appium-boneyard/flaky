module Flaky
  class Cmd
    attr_reader :pid, :in, :out, :err

    def initialize cmd
      # redirect err to child's out
      @pid, @in, @out, @err = POSIX::Spawn::popen4 cmd, { :err => [:child, :out] }
      @in.close
    end

    def stop
      [@in, @out, @err].each { |io| io.close unless io.nil? || io.closed? }
      begin
        Process.kill 'KILL', @pid
        Process.waitpid @pid
      rescue # no such process
      end
    end
  end
end
