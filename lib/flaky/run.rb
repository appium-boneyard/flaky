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

  class Run
    include Flaky::Color
    attr_reader :tests, :result_dir, :result_file

    def initialize
      @tests = {}
      @start_time = Time.now

      result_dir = '/tmp/flaky/'
      # rm -rf result_dir
      FileUtils.rm_rf result_dir
      FileUtils.mkdir_p result_dir

      @result_dir = result_dir
      @result_file = File.join result_dir, 'result.txt'
    end

    def report opts={}
      save_file = opts.fetch :save_file, true
      puts "\n" * 2
      success = ''
      failure = ''
      @tests.each do |name, stats|
        runs = stats[:runs]
        pass = stats[:pass]
        fail = stats[:fail]
        line = "#{name}, runs: #{runs}, pass: #{pass}," +
            " fail: #{fail}\n"
        if fail > 0
          failure += line
        else
          success += line
        end
      end

      out = ''
      out += "Failure:\n#{failure}\n" unless failure.empty?
      out += "Success:\n#{success}" unless success.empty?

      duration = Time.now - @start_time
      duration = ChronicDuration.output(duration.round) || '0s'
      out += "\nFinished in #{duration}"

      # overwrite file
      File.open(@result_file, 'w') do |f|
        f.puts out
      end if save_file

      puts out
    end

    def _execute run_cmd, test_name, runs, appium
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

      log_name = "#{postfix}.html"
      log_name = File.join result_dir, pass_str, log_name
      Flaky.write log_name, log

      appium_log_name = File.join result_dir, pass_str, "#{postfix}.appium.html"
      Flaky.write appium_log_name, appium.log

      # save uncolored version
      File.open(appium_log_name + '.nocolor.txt', 'w') do |f|
        f.write appium.log
      end

      passed
    end

    def execute opts={}
      run_cmd = opts[:run_cmd]
      test_name = opts[:test_name]
      appium = opts[:appium]

      raise 'must pass :run_cmd' unless run_cmd
      raise 'must pass :test_name' unless test_name
      raise 'must pass :appium' unless appium

      test = @tests[test_name] ||= {runs: 0, pass: 0, fail: 0}
      runs = test[:runs] += 1

      passed = _execute run_cmd, test_name, runs, appium

      print cyan("\n #{test_name} ") if @last_test.nil? ||
          @last_test != test_name

      print passed ? green(' ✓') : red(' ✖')

      @last_test = test_name
      passed
    end
  end # class Run
end # module Flaky