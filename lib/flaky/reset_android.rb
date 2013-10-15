# encoding: utf-8
module Flaky

  # Flaky::Android.new.reset
  class Android
    def initialize
      apk_path = ENV['APK_PATH']
      raise 'Environment variable APK_PATH must be set' if apk_path.nil? ||
          apk_path.empty? || File.extname(apk_path).downcase != '.apk'
      @md5 = Digest::MD5.file(apk_path).hexdigest
      @apk = apk_path

      app_package = ENV['APP_PACKAGE']
      raise 'Environment variable APP_PACKAGE must be set' if app_package.nil? ||
          app_package.empty?
      @package = app_package
    end

    def _remove_old_apks
      list_apks = POSIX::Spawn::Child.new 'adb shell "ls /data/local/tmp/*.apk"'
      raise "list_apks errored with: #{list_apks.err}" unless list_apks.err.empty?

      apk_on_device = false
      remove_apks = ''
      list_apks.out.split(/\r?\n/).each do |path|
        if path.include?(@md5)
          apk_on_device = true
        else
          remove_apks += ' rm \\"' + path + '\\";'
        end
      end

      # must return if there are no apks to remove
      return if remove_apks.empty?

      remove_apks = 'adb shell "' + remove_apks + '"'
      remove_apks = POSIX::Spawn::Child.new remove_apks
      raise "remove_apks errored with: #{remove_apks.err}" unless remove_apks.err.empty?
    end

    def _push_apk
      # dir must exist before pushing
      POSIX::Spawn::Child.new 'adb shell "mkdir /data/local/tmp/"'
      push_apk = POSIX::Spawn::Child.new %Q(adb push "#{@apk}" "/data/local/tmp/#{@md5}.apk")
      raise "push_apk errored with: #{push_apk.err}" unless push_apk.err.empty?
    end

    def _reinstall_apk
      POSIX::Spawn::Child.new %Q(adb shell "am force-stop #{@package}")
      apk_uninstall = POSIX::Spawn::Child.new "adb uninstall #{@package}"
      raise "apk_uninstall errored with: #{apk_uninstall.err}" unless apk_uninstall.err.empty?
      apk_install = POSIX::Spawn::Child.new "adb shell pm install /data/local/tmp/#{@md5}.apk"
      raise "apk_install errored with: #{apk_install.err}" unless apk_install.err.empty?
    end

    def reset
      apk_on_device = _remove_old_apks
      _push_apk unless apk_on_device
      _reinstall_apk
    end
  end
end