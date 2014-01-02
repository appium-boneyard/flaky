# encoding: utf-8
require 'rubygems'
require 'posix-spawn'

module Flaky
  class << self

    def screen_recording_binary
      @screen_recording_binary ||= File.expand_path('../screen-recording', __FILE__)
    end

    def screen_recording_start opts={}
      os = opts[:os]
      path = opts[:path]
      raise ':os is required' unless os
      raise ':path is required' unless path

      raise 'Invalid os. Must be ios or android' unless %w[ios android].include? os
      raise 'Invalid path. Must end with .mov' unless File.extname(path) == '.mov'

      pid = spawn(screen_recording_binary, os, path,
                  :in => '/dev/null', :out => '/dev/null', :err => '/dev/null')
      pid
    end

    def screen_recording_stop pid
      Process.kill(:SIGINT, pid)
      # Must wait 5 seconds for the video to end.
      # If we don't wait, the movie will be corrupt.
      # See: https://github.com/bootstraponline/screen_recording/blob/master/screen-recording/main.m#L137
      sleep 5
    end
  end
end