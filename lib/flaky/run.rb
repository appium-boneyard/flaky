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
      @pass_str   = opts.fetch :pass_str, ''
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
        line = "#{name}, runs: #{runs}, pass: #{pass}," +
            " fail: #{fail}\n"
        if fail > 0 && pass <= 0
          failure_name_only += "#{File.basename(name)}\n"
          failure += line
          total_failure += 1
        else
          success += line
          total_success += 1
        end
      end

      out = "#{total_success + total_failure} Tests\n\n"
      out += "Failure (#{total_failure}):\n#{failure}\n" unless failure.empty?
      out += "Success (#{total_success}):\n#{success}" unless success.empty?

      time_now = Time.now
      duration = time_now - @start_time
      duration = ChronicDuration.output(duration.round) || '0s'
      out += "\nFinished in #{duration}\n"
      time_format = '%b %d %l:%M %P'
      time_format2 = '%l:%M %P'
      out += "#{@start_time.strftime(time_format)} - #{time_now.strftime(time_format2)}"
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

    def _execute run_cmd, test_name, runs, appium, sauce
      # must capture exit code or log is an array.
      log, exit_code = Open3.capture2e run_cmd

      result = /\d+ runs, \d+ assertions, \d+ failures, \d+ errors, \d+ skips/
      success = /0 failures, 0 errors, 0 skips/
      passed = true

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
      pass_str = passed ? 'pass' : 'fail'
      test = @tests[test_name]
      # save log
      if passed
        pass = test[:pass] += 1
        postfix = "pass_#{pass}"
      else
        fail = test[:fail] += 1
        postfix = "fail_#{fail}"
      end

      postfix = "#{runs}_#{test_name}_" + postfix
      postfix = '0' + postfix if runs <= 9

      log_file = LogArtifact.new result_dir: result_dir, pass_str: pass_str, test_name: test_name

      # File.open 'w' will not create folders. Use mkdir_p before.
      test_file_path = log_file.name("#{postfix}.html")
      FileUtils.mkdir_p File.dirname(test_file_path)
      # html Ruby test log
      File.open(test_file_path, 'w') do |f|
        f.write log
      end

      # TODO: Get iOS simulator system log from appium
      # File.open(log_file.name("#{postfix}.server.log.txt"), 'w') do |f|
      #  f.write appium.tail.out.readpartial(999_999_999)
      # end

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

        src_system_log = '/tmp/flaky_logs.txt'
        if File.exists? src_system_log
          # postfix is required! or the log will be saved to an incorrect path
          system_log_path = log_file.name("#{postfix}.system.txt")
          FileUtils.mkdir_p File.dirname(system_log_path)
          FileUtils.copy_file src_system_log, system_log_path
          File.delete src_system_log if File.exists? src_system_log
        end

        # appium server log
        appium_server_path = log_file.name("#{postfix}.appium.html")
        FileUtils.mkdir_p File.dirname(appium_server_path)

        tmp_file = appium.flush_buffer
        if File.exists?(tmp_file) && !tmp_file.nil? && !tmp_file.empty?
          FileUtils.copy_file tmp_file, appium_server_path
        end
        File.delete tmp_file if File.exists? tmp_file
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

      test = @tests[test_name] ||= {runs: 0, pass: 0, fail: 0}
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