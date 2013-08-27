require 'fileutils'
require 'open3'

module Flaky
  class Run
    attr_reader :count, :pass, :fail, :result_dir, :result_file

    def initialize result_dir
      @pass = 0
      @fail = 0
      @count = 0

      FileUtils.mkdir_p result_dir unless Dir.exists? result_dir

      @result_dir = result_dir
      @result_file = File.join result_dir, 'result.txt'
    end

    def report
      # overwrite file
      File.open(@result_file, 'w') do |f|
        f.puts "#{@count} tests"
        f.puts "#{@pass} Passed"
        f.puts "#{@fail} Failed"
      end
    end

    def execute run_cmd
      @count += 1

      # must capture exit code or log is an array.
      log, exit_code = Open3.capture2e(run_cmd)

      result = /\d+ runs, \d+ assertions, \d+ failures, \d+ errors, \d+ skips/
      success = /0 failures, 0 errors, 0 skips/
      passed = true

      found_results = log.scan result
      # all result instances must match success
      found_results.each do |result|
        unless result.match success
          passed = false
          break
        end
      end

      # no results found.
      passed = false if found_results.length <= 0

      if passed
        @pass += 1
        postfix = "pass_#{@pass}"
      else
        @fail += 1
        postfix = "fail_#{@fail}"
      end

      postfix = "#{@count}_" + postfix
      postfix = '0' + postfix if @count <= 9

      log_name = "#{postfix}.html"
      log_name = File.join result_dir, log_name
      Flaky.write log_name, log

      passed
    end
  end # class Run
end # module Flaky