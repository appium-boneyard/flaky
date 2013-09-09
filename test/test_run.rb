# encoding: utf-8

require File.expand_path '../../lib/run', __FILE__
require File.expand_path '../mock_execute', __FILE__

require 'rubygems'
require 'awesome_print'

result_dir = '/tmp/flaky/'
flaky = Flaky::Run.new result_dir
4.times do |count|
  (rand(1..2)).times { flaky.execute run_cmd: '', test_name: "test_#{count}" }
end

flaky.report save_file: false

=begin
  1. Run one test x times
  2. Run all tests x times.

- Store success / failure logs

results_dir/pass/test_name/pass_logs_*
results_dir/fail/test_name/fail-logs_*

- print status to stdout
- persist logs & status to disk
=end