# encoding: utf-8
module Flaky
  def self.run_from_file opts={}
    raise 'Must pass :count, :os, and :file' unless opts && opts[:count] && opts[:os] && opts[:file]

    count = opts[:count].to_i
    os = opts[:os]
    file = opts[:file]

    raise ':count must be an int' unless count.kind_of?(Integer)
    raise ':os must be a string' unless os.kind_of?(String)
    raise ':file must be a string' unless file.kind_of?(String)

    raise "#{file} doesn't exist" unless File.exists? file
    tests = File.readlines(file).map { |line| File.basename(line.chomp, '.*') }
    resolved_paths = []
    # Convert file names into full paths
    current_dir = Dir.pwd
    Dir.glob(File.join current_dir, 'appium', os, 'specs', '**/*.rb') do |test_file|
      if tests.include? File.basename(test_file, '.*')
        resolved_paths << File.expand_path(test_file)
      end
    end

    if tests.length != resolved_paths.length
      missing_tests = []
      tests.each do |test|
        missing_tests << test unless File.exists? test
      end
      raise "Missing tests #{missing_tests}"
    end

    flaky = Flaky::Run.new
    appium = Appium.new

    raise "Rakefile doesn't exist in #{current_dir}" unless File.exists?(File.join(current_dir, 'Rakefile'))

    resolved_paths.each do |test_file|
      file = test_file
      name = File.basename file, '.*'

      raise "#{test_file} does not exist." if file.empty?

      test_name = file.sub(current_dir + '/appium/', '')
      test_name = File.join(File.dirname(test_name), File.basename(test_name, '.*'))

      count.times do
        appium.start
        run_cmd = "cd #{current_dir}; rake #{os.downcase}['#{name}']"
        passed = flaky.execute run_cmd: run_cmd, test_name: test_name, appium: appium
        break if passed # move onto the next test after one successful run
      end
    end

    appium.stop
    flaky.report
  end
end # module Flaky