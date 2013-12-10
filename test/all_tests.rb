# encoding: utf-8
require File.expand_path '../lib/flaky/run', __FILE__
require File.expand_path '../mock_execute', __FILE__

flaky = Flaky::Run.new

dir = File.readlines('automation.txt')[0].strip
ios = File.join dir, 'appium', 'ios', 'specs', '**', '*.rb'

Dir.glob(ios) do |file|
  run_cmd = "cd #{dir}; rake ios['#{file}']"
  flaky.execute run_cmd: run_cmd, test_name: file.sub(dir, '')
end

flaky.report