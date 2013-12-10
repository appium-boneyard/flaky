# encoding: utf-8
require 'fileutils' # system requires
require 'open3'
require 'timeout' # to timeout long running color runs

require 'rubygems' # gem requires
require 'chronic_duration'
require 'posix/spawn' # http://rubygems.org/gems/posix-spawn
require 'digest/md5'

module Flaky
  VERSION = '0.0.17' unless defined? ::Flaky::VERSION
  DATE = '2013-12-10' unless defined? ::Flaky::DATE

  # https://github.com/appium/ruby_lib/blob/0e203d76610abd519ba9d2fe9c14b50c94df5bbd/lib/appium_lib.rb#L24
  def self.add_to_path file, path=false
    path = path ? "../#{path}/" : '..'
    path = File.expand_path path, file

    $:.unshift path unless $:.include? path
  end

  add_to_path __FILE__ # add this dir to path

  # TODO: Use require_relative instead of add_to_path
  # require internal files
  require 'flaky/appium'
  require 'flaky/applescript'
  require 'flaky/run'

  require 'flaky/run/all_tests'
  require 'flaky/run/from_file'
  require 'flaky/run/one_test'
end