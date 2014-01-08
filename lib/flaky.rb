# encoding: utf-8
require 'fileutils' # system requires
require 'open3'
require 'timeout'

require 'rubygems' # gem requires
require 'chronic_duration'
require 'posix/spawn' # http://rubygems.org/gems/posix-spawn
require 'digest/md5'

module Flaky
  VERSION = '0.0.22' unless defined? ::Flaky::VERSION
  DATE = '2014-01-03' unless defined? ::Flaky::DATE

  class << self; attr_accessor :no_video; end
  self.no_video = false; # set default value

  # require internal files
  require_relative 'flaky/appium'
  require_relative 'flaky/applescript'
  require_relative 'flaky/run'

  require_relative 'flaky/run/all_tests'
  require_relative 'flaky/run/from_file'
  require_relative 'flaky/run/one_test'
  require_relative 'flaky/run/two_pass'
end