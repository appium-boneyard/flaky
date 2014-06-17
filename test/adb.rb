require 'rubygems'
require 'posix-spawn'

Process::waitpid(POSIX::Spawn::spawn('killall', '-9', 'adb', :in => '/dev/null', :out => '/dev/null', :err => '/dev/null'))

puts 'Locating device...'

while `adb shell echo "ping"`.strip != 'ping'
  `adb kill-server`
  `adb devices` # std err is printed
  sleep 5
end

puts 'Device found!'