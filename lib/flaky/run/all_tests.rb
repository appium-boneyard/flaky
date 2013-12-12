# encoding: utf-8
module Flaky
  def self.run_all_tests opts={}
    raise 'Must pass :count and :os' unless opts && opts[:count] && opts[:os]

    count = opts[:count].to_i
    os = opts[:os]

    raise ':count must be an int' unless count.kind_of?(Integer)
    raise ':os must be a string' unless os.kind_of?(String)

    running_on_sauce = ENV['SAUCE_USERNAME'] ? true : false
    flaky = Flaky::Run.new
    appium = Appium.new unless running_on_sauce

    current_dir = Dir.pwd
    raise "Rakefile doesn't exist in #{current_dir}" unless File.exists?(File.join(current_dir, 'Rakefile'))

    Dir.glob(File.join current_dir, 'appium', os, 'specs', '**/*.rb') do |test_file|
      file = test_file
      name = File.basename file, '.*'

      raise "#{test_file} does not exist." if file.empty?

      test_name = file.sub(current_dir + '/appium/', '')
      test_name = File.join(File.dirname(test_name), File.basename(test_name, '.*'))

      count.times do
        File.open('/tmp/flaky/current.txt', 'a') { |f| f.puts "Running: #{test_name} on #{os}" }
        appium.start unless running_on_sauce
        run_cmd = "cd #{current_dir}; rake #{os.downcase}['#{name}']"
        passed = flaky.execute run_cmd: run_cmd, test_name: test_name, appium: appium, sauce: running_on_sauce
        break if passed # move onto the next test after one successful run
      end
    end

    appium.stop unless running_on_sauce
    flaky.report
  end
end # module Flaky