# encoding: utf-8
require File.expand_path '../lib/flaky/run', __FILE__
require File.expand_path '../mock_execute', __FILE__

require 'rubygems'
require 'awesome_print'

flaky = Flaky::Run.new
4.times do |count|
  (rand(1..2)).times { flaky.execute run_cmd: '', test_name: "test_#{count}" }
end

flaky.report save_file: false