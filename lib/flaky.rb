# encoding: utf-8
require 'fileutils' # system requires
require 'open3'
require 'timeout' # to timeout long running color runs

require 'rubygems' # gem requires
require 'chronic_duration'
require 'posix/spawn' # http://rubygems.org/gems/posix-spawn
require 'digest/md5'

module Flaky
  VERSION = '0.0.19' unless defined? ::Flaky::VERSION
  DATE = '2013-12-23' unless defined? ::Flaky::DATE

  # require internal files
  require_relative 'flaky/appium'
  require_relative 'flaky/applescript'
  require_relative 'flaky/run'

  require_relative 'flaky/run/all_tests'
  require_relative 'flaky/run/from_file'
  require_relative 'flaky/run/one_test'
  require_relative 'flaky/run/two_pass'
end