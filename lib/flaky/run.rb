# encoding: utf-8
module Flaky
  module Color
    def cyan str
      "\e[36m#{str}\e[0m"
    end

    def red str
      "\e[31m#{str}\e[0m"
    end

    def green str
      "\e[32m#{str}\e[0m"
    end
  end

  class LogArtifact
    def initialize opts={}
      @result_dir = opts.fetch :result_dir, ''
      @pass_str = opts.fetch :pass_str, ''
      @test_name = opts.fetch :test_name, ''
    end

    def name str
      file_name = File.basename(str)

      str = str[0..-1-file_name.length].gsub('/', '_')
      str = str + '_' if str[-1] != '_'
      str += @test_name.split('/').last

      filename_only = File.basename(@test_name)

      File.join @result_dir, @pass_str, filename_only, str, file_name
    end
  end

  class Run
    include Flaky::Color
    attr_reader :tests, :result_dir, :result_file

    def initialize result_dir_postfix=''
      @tests = {}
      @start_time = Time.now

      result_dir = '/tmp/flaky/' + result_dir_postfix
      # rm -rf result_dir
      FileUtils.rm_rf result_dir
      FileUtils.mkdir_p result_dir

      @result_dir = result_dir
      @result_file = File.join result_dir, 'result.txt'
      @fail_file = File.join result_dir, 'fail.txt'
    end

    def report opts={}
      save_file = opts.fetch :save_file, true
      puts "\n" * 2
      success = ''
      failure = ''
      failure_name_only = ''
      total_success = 0
      total_failure = 0
      @tests.each do |name, stats|
        runs = stats[:runs]
        pass = stats[:pass]
        fail = stats[:fail]
        timedout = ''
        timedout = '-- TIMED OUT' if stats[:timedout] == true
        line = "#{name}, runs: #{runs}, pass: #{pass}," +
            " fail: #{fail} #{timedout}\n"
        if fail > 0 && pass <= 0
          failure_name_only += "#{File.basename(name)}\n"
          failure += line
          total_failure += 1
        else
          success += line
          total_success += 1
        end
      end

      total_tests = total_success + total_failure
      out = "#{total_tests} Tests\n\n"
      out += "Failure (#{total_failure}):\n#{failure}\n" unless failure.empty?
      out += "Success (#{total_success}):\n#{success}" unless success.empty?

      time_now = Time.now
      duration = time_now - @start_time
      duration = ChronicDuration.output(duration.round) || '0s'
      out += "\nFinished in #{duration}\n"
      time_format = '%b %d %l:%M %P'
      time_format2 = '%l:%M %P'
      out += "#{@start_time.strftime(time_format)} - #{time_now.strftime(time_format2)}"

      month_day_year = Time.now.strftime '%-m/%-d/%Y'
      success_percent = (total_success.to_f/total_tests.to_f*100).round(2)
      success_percent = 100 if total_failure <= 0
      google_docs_line = [month_day_year, total_tests, total_failure, total_success, success_percent].join("\t")
      out += "\n#{google_docs_line}"
      out += "\n--\n"

      if save_file
        File.open(@fail_file, 'w') do |f|
          f.puts failure_name_only
        end

        # overwrite file
        File.open(@result_file, 'w') do |f|
          f.puts out
        end
      end

      puts out
    end

    def process_exists pid
      begin
        Process.waitpid(pid, Process::WNOHANG)
        true
      rescue
        false
      end
    end

    def _execute run_cmd, test_name, runs, appium, sauce
      # must capture exit code or log is an array.
      result = /\d+ runs, \d+ assertions, \d+ failures, \d+ errors, \d+ skips/
      success = /0 failures, 0 errors, 0 skips/
      passed = true

      exit_code = -1
      timedout = false
      rake_pid = -1
      # we need the minitest log in memory to scan for results.
      log = ''
      tmp_ruby_log = '/tmp/flaky/ruby_log_tmp.txt'
      File.delete(tmp_ruby_log) if File.exists? tmp_ruby_log

      flaky_logs_txt = '/tmp/flaky_logs.txt'
      File.delete flaky_logs_txt if File.exist? flaky_logs_txt
      tail_cmd = "tail -f -n1 /Users/#{ENV['USER']}/Library/Logs/iOS\\ Simulator/7.0.3/system.log > #{flaky_logs_txt}"
      tail_cmd = "adb logcat > #{flaky_logs_txt}" if !sauce && !appium.ios

      tail_system_log = Flaky::Cmd.new tail_cmd
      begin
        ten_minutes = 10 * 60
        timeout ten_minutes do
          rake = Flaky::Cmd.new run_cmd
          rake_pid = rake.pid

          while process_exists rake_pid
            begin
              # readpartial throws end of file reached error
              new_out = rake.out.readpartial 999_999 # blocks on 0 data
              log += new_out

              File.open(tmp_ruby_log, 'a') do |f|
                f.write new_out
              end
            rescue
            end
          end

          # must write rake.err. it's not included in rake.out
          begin
            new_err = rake.err.read_nonblock 999_999

            log += new_err if new_err
            File.open(tmp_ruby_log, 'a') do |f|
              f.write new_err
            end if new_err
          rescue
          end
        end
      rescue Exception => e
        timedout = true
        passed = false
        # after_run in run.rb is triggered by sigint
        Process.kill :SIGINT, rake_pid

        begin
          two_minutes = 2 * 60
          timeout two_minutes do
            Process::waitpid rake_pid
          end
        rescue # if the process still isn't done after sigint, use sigkill
          Process.kill :SIGKILL, rake_pid
        end
      end

      # waitpid may throw if the pid doesn't exist by the time we're ready to wait.
      begin
        tail_system_log_pid = tail_system_log.pid
        Process.kill :SIGKILL, tail_system_log_pid
        Process::waitpid tail_system_log_pid
      rescue
      end

      unless timedout
        found_results = log.scan result
        # all result instances must match success
        found_results.each do |result|
          # runs must be >= 1. 0 runs mean no tests were run.
          r_count = result.match /(\d+) runs/
          runs_not_zero = r_count && r_count[1] && r_count[1].to_i > 0 ? true : false

          unless result.match(success) && runs_not_zero
            passed = false
            break
          end
        end

        # no results found.
        passed = false if found_results.length <= 0
      end
      pass_str = passed ? 'pass' : 'fail'
      test = @tests[test_name]
      # save log
      if passed
        pass = test[:pass] += 1
        postfix = "pass_#{pass}"
      else
        fail = test[:fail] += 1
        postfix = "fail_#{fail}"
        test[:timedout] = true if timedout
      end

      postfix = "#{runs}_#{test_name}_" + postfix
      postfix = '0' + postfix if runs <= 9

      log_file = LogArtifact.new result_dir: result_dir, pass_str: pass_str, test_name: test_name

      # File.open 'w' will not create folders. Use mkdir_p before.
      test_file_path = log_file.name("#{postfix}.txt")
      FileUtils.mkdir_p File.dirname(test_file_path)
      # html Ruby test log
      File.open(test_file_path, 'w') do |f|
        f.write log
      end

      unless sauce
        movie_path = log_file.name("#{postfix}.mov")
        FileUtils.mkdir_p File.dirname(movie_path)
        movie_src = '/tmp/video.mov'
        if File.exists?(movie_src)
          unless Flaky.no_video
            # save movie on failure
            FileUtils.copy movie_src, movie_path if !passed
          end
          # always clean up movie
          File.delete movie_src if File.exists? movie_src
        end

        # save .TIMED_OUT.txt in timeout fails
        if timedout
          timeout_path = log_file.name("#{postfix}.TIMED_OUT.txt")
          FileUtils.mkdir_p File.dirname(timeout_path)
          File.open(timeout_path, 'w') {}
        end

        src_system_log = '/tmp/flaky_logs.txt'
        if File.exists? src_system_log
          # postfix is required! or the log will be saved to an incorrect path
          system_log_path = log_file.name("#{postfix}.system.txt")
          FileUtils.mkdir_p File.dirname(system_log_path)
          FileUtils.copy_file src_system_log, system_log_path
          File.delete src_system_log if File.exists? src_system_log
        end

        # appium server log
        appium_server_path = log_file.name("#{postfix}.appium.txt")
        FileUtils.mkdir_p File.dirname(appium_server_path)

        tmp_file = appium.flush_buffer
        if File.exists?(tmp_file) && !tmp_file.nil? && !tmp_file.empty?
          FileUtils.copy_file tmp_file, appium_server_path
        end
        File.delete tmp_file if File.exists? tmp_file
        # also delete the temp ruby log
        File.delete tmp_ruby_log if File.exists? tmp_ruby_log

        # copy app logs
        app_logs = '/tmp/flaky_tmp_log_folder'
        dest_dir = File.dirname(appium_server_path)
        if File.exists? app_logs
          Dir.glob(File.join(app_logs, '*')).each { |f| FileUtils.cp f, dest_dir }
        end
        FileUtils.rm_rf app_logs
      end

      passed
    end

    def collect_crashes array
      Dir.glob(File.join(Dir.home, '/Library/Logs/DiagnosticReports/*.crash')) do |crash|
        array << crash
      end
      array
    end

    def execute opts={}
      run_cmd = opts[:run_cmd]
      test_name = opts[:test_name]
      appium = opts[:appium]
      sauce = opts[:sauce]

      old_crash_files = []
      # appium is nil when on sauce
      if !sauce && appium
        collect_crashes old_crash_files
      end

      raise 'must pass :run_cmd' unless run_cmd
      raise 'must pass :test_name' unless test_name
      # local appium is not required when running on Sauce
      raise 'must pass :appium' unless appium || sauce

      test = @tests[test_name] ||= {runs: 0, pass: 0, fail: 0, timedout: false}
      runs = test[:runs] += 1

      passed = _execute run_cmd, test_name, runs, appium, sauce
      unless sauce
        print cyan("\n #{test_name} ") if @last_test.nil? ||
            @last_test != test_name

        print passed ? green(' ✓') : red(' ✖')
      else
        print cyan("\n #{test_name} ")
        print passed ? green(' ✓') : red(' ✖')
        print " https://saucelabs.com/tests/#{File.read('/tmp/appium_lib_session').chomp}\n"
      end

      # androids adb may crash also and it ends up in the same location as iOS.
      # appium is nil when running on Sauce
      if !sauce && appium
        new_crash_files = []
        collect_crashes new_crash_files

        new_crash_files = new_crash_files - old_crash_files
        if new_crash_files.length > 0
          File.open('/tmp/flaky/crashes.txt', 'a') do |f|
            f.puts '--'
            f.puts "Test: #{test_name} crashed on #{appium.ios ? 'ios' : 'android'}:"
            new_crash_files.each { |crash| f.puts crash }
            f.puts '--'
          end
        end
      end

      @last_test = test_name
      passed
    end
  end # class Run
end # module Flaky