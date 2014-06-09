# encoding: utf-8
module Flaky
  def self.run_one_test opts={}
    raise 'Must pass :count and :name' unless opts && opts[:count] && opts[:os] && opts[:name]

    count = opts[:count].to_i
    os = opts[:os]
    name = opts[:name]

    raise ':count must be an int' unless count.kind_of?(Integer)
    raise ':os must be a string' unless os.kind_of?(String)
    raise ':name must be a string' unless name.kind_of?(String)

    # ensure file name does not contain an extension
    # don't expand the path because it's joined and expanded in final_path.
    name = File.join(File.dirname(name), File.basename(name, '.*'))

    running_on_sauce = ENV['SAUCE_USERNAME'] ? true : false
    flaky = Flaky::Run.new
    is_android = os.strip.downcase == 'android'
    appium = Appium.new(android: is_android) unless running_on_sauce

    current_dir = Dir.pwd

    raise "Rakefile doesn't exist in #{current_dir}" unless File.exists?(File.join(current_dir, 'Rakefile'))
    flaky_txt = File.expand_path(File.join(current_dir, 'flaky.txt'))
    parsed = TOML.load File.read flaky_txt
    puts "flaky.txt: #{parsed}"
    android_dir = parsed['android']
    ios_dir = parsed['ios']
    active_dir = is_android ? android_dir : ios_dir
    final_path = File.expand_path File.join current_dir, active_dir, name + '.rb'
    test_file = ''
    Dir.glob(final_path) do |file|
      test_file = file
    end

    raise "#{test_file} does not exist." unless File.exists?(test_file)

    test_name = test_file.sub(File.expand_path(File.join(current_dir, active_dir)), '')
    # remove leading /
    test_name.sub!(test_name.match(/^\//).to_s, '')
    test_name = File.join(File.dirname(test_name), File.basename(test_name, '.*'))

    count.times do
      appium.start unless running_on_sauce
      run_cmd = "cd #{current_dir}; rake #{os.downcase}['#{test_file}',#{Flaky.no_video}]"
      flaky.execute run_cmd: run_cmd, test_name: test_name, appium: appium, sauce: running_on_sauce
    end

    appium.stop unless running_on_sauce
    flaky.report
  end
end # module Flaky