# encoding: utf-8
# test
require File.expand_path '../log', __FILE__
require File.expand_path '../run', __FILE__

flaky = Flaky::Run.new

dir = File.readlines('automation.txt')[0].strip
spec_dir = File.join dir, 'appium', 'ios', 'specs'
ios = File.join spec_dir, '**', '*.rb'

Dir.glob(ios) do |file|
  rake_file = File.basename file, '.*'
  next unless %w[view_album].include? rake_file
  run_cmd = "cd #{dir}; rake ios['#{rake_file}']"
  flaky.execute run_cmd: run_cmd, test_name: file.sub(dir, '').gsub('/', '_')
end

flaky.report