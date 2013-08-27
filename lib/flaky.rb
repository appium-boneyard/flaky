require File.expand_path '../log', __FILE__
require File.expand_path '../run', __FILE__

FileUtils.rm_rf '/tmp/flaky/'
result_dir = '/tmp/flaky/'
flaky = Flaky::Run.new result_dir

dir = '/path/to/tests'
run_cmd = "cd #{dir}; rake ios['fail']"
run_cmd_pass = "cd #{dir}; rake ios['pass']"

#2.times { flaky.execute run_cmd }

1.times { flaky.execute run_cmd_pass }

flaky.report

# rake ios
# flake ios

# default is 1
# second argument will override the run count