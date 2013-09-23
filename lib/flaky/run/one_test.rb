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
    name = File.basename name, '.*'

    flaky = Flaky::Run.new
    appium = Appium.new

    current_dir = Dir.pwd

    raise "Rakefile doesn't exist in #{current_dir}" unless File.exists?(File.join(current_dir, 'Rakefile'))

    file = ''
    Dir.glob(File.join current_dir, 'appium', os, 'specs', "**/#{name}.rb") do |test_file|
      file = test_file
    end

    raise "#{test_file} does not exist." if file.empty?
    test_name = file.sub(current_dir + '/appium/', '').gsub('/', '_')

    puts "Running #{name} #{count}x"
    count.times do
      appium.go # start appium
      run_cmd = "cd #{current_dir}; rake ios['#{name}']"
      flaky.execute run_cmd: run_cmd, test_name: test_name, appium: appium
    end

    flaky.report
  end
end # module Flaky