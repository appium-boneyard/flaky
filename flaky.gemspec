# encoding: utf-8

def self.add_to_path path
 path = File.expand_path "../#{path}/", __FILE__

 $:.unshift path unless $:.include? path
end

add_to_path 'lib'

require 'flaky'

Gem::Specification.new do |s|
  # 1.8.x is not supported
  s.required_ruby_version = '>= 1.9.3'

  s.name = 'flaky'
  s.version = Flaky::VERSION
  s.date = Flaky::DATE
  s.license = 'http://www.apache.org/licenses/LICENSE-2.0.txt'
  s.description = s.summary = 'Measure flaky Ruby Appium tests'
  s.description += '.' # avoid identical warning
  s.authors = s.email = %w(code@bootstraponline.com)
  s.homepage = 'https://github.com/bootstraponline/flaky'
  s.require_paths = %w(lib)

  s.add_runtime_dependency 'chronic_duration', '~> 0.10.2'
  s.add_runtime_dependency 'posix-spawn', '~> 0.3.6'
  s.add_runtime_dependency 'toml', '~> 0.1.1'

  s.add_development_dependency 'rake', '~> 10.1.0'

  s.executables = %w(flake)
  s.files = `git ls-files`.split "\n"
end
