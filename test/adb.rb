require 'rubygems'
require 'posix-spawn'

Process::waitpid(POSIX::Spawn::spawn('killall', '-9', 'adb', :in => '/dev/null', :out => '/dev/null', :err => '/dev/null'))

last_result = ''

puts 'Locating device...'

while `adb shell echo "ping"`.strip != 'ping'
  `adb kill-server`

  result = `adb devices`
  if result != last_result
    puts result
  end

  last_result = result
  sleep 5
end

puts 'Device found!'