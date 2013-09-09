module Flaky
  class Run
    def _execute run_cmd, test_name, count
      passed = rand(0..1) == 0 ? false : true
      test = @tests[test_name]
      if passed
        test[:pass] += 1
      else
        test[:fail] += 1
      end

      passed
    end
  end
end