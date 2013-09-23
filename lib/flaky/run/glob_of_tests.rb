# encoding: utf-8
module Flaky
  def self.run_glob_of_tests
    flaky = Flaky::Run.new

    txt = File.join File.expand_path('../..', __FILE__), 'automation.txt'
    dir = File.readlines(txt)[0].strip
    spec_dir = File.join dir, 'appium', 'ios', 'specs'
    ios = File.join spec_dir, '**', '*.rb'

    appium = Appium.new

    Dir.glob(ios) do |file|
      next unless file.include?('view_album')
      next unless File.extname(file).downcase == '.rb'

      appium.go

      rake_file = File.basename file, '.*'
      run_cmd = "cd #{dir}; rake ios['#{rake_file}']"
      flaky.execute run_cmd: run_cmd, test_name: file.sub(dir, '').gsub('/', '_')
    end

    appium.stop
    flaky.report
  end
end # module Flaky