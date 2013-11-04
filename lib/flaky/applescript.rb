# encoding: utf-8
module Flaky
  class AppleScript
    def self.beat_security_agent
      flaky_password = ENV['FLAKY_PASSWORD']
      raise 'FLAKY_PASSWORD must be defined' if flaky_password.nil? || flaky_password.empty?
      flaky_user = ENV['FLAKY_USER']
      raise 'FLAKY_USER must be defined' if flaky_user.nil? || flaky_user.empty?

      script = File.expand_path('../../BeatSecurityAgent.applescript', __FILE__)
      osascript = 'osascript'
      Appium.kill_all osascript
      Process::waitpid(POSIX::Spawn::spawn("/usr/bin/#{osascript} #{script} #{flaky_user} #{flaky_password}"))
    end
  end
end