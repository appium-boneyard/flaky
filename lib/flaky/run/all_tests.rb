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
    is_android = os.strip.downcase == 'android'
    appium = Appium.new(android: is_android) unless running_on_sauce

    current_dir = Dir.pwd
    rakefile = File.expand_path(File.join(current_dir, 'Rakefile'))
    raise "Rakefile doesn't exist in #{current_dir}" unless File.exists? rakefile
    flaky_txt = File.expand_path(File.join(current_dir, 'flaky.txt'))

    parsed = TOML.load File.read flaky_txt
    puts "flaky.txt: #{parsed}"
    android_dir = parsed['android']
    ios_dir = parsed['ios']
    glob = parsed.fetch 'glob', '**/*.rb'

    active_dir = is_android ? android_dir : ios_dir
    final_path = File.expand_path File.join current_dir, active_dir, glob
    puts "Globbing: #{final_path}"

    Dir.glob(final_path) do |test_file|
      raise "#{test_file} does not exist." unless File.exist?(test_file)
      test_file = File.expand_path test_file

      test_name = test_file.sub(File.expand_path(File.join(current_dir, active_dir)), '')

      # remove leading /
      test_name.sub!(test_name.match(/^\//).to_s, '')

      test_name = File.join(File.dirname(test_name), File.basename(test_name, '.*'))

      count.times do
        File.open('/tmp/flaky/current.txt', 'a') { |f| f.puts "Running: #{test_name} on #{os}" }
        appium.start unless running_on_sauce
        run_cmd = "cd #{current_dir}; rake #{os.downcase}['#{test_file}',#{Flaky.no_video}]"
        passed = flaky.execute run_cmd: run_cmd, test_name: test_name, appium: appium, sauce: running_on_sauce
        break if passed # move onto the next test after one successful run
      end
    end

    appium.stop unless running_on_sauce
    flaky.report
  end
end # module Flaky