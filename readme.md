#### flaky [![Gem Version](https://badge.fury.io/rb/flaky.png)](http://rubygems.org/gems/flaky) [![Dependency Status](https://gemnasium.com/appium/flaky.png)](https://gemnasium.com/appium/flaky) 

Run Appium iOS tests to measure flakiness.

- `gem install flaky`
- `flake 3 ios[nop]` - Run the iOS test named nop 3 times.

Results are stored in `/tmp/flaky`

Must set `ENV['APPIUM_HOME']` to point to the appium folder containing `server.js`.

This only works with:

- [Ruby / appium_lib iOS](https://github.com/appium/ruby_lib_ios)
- iOS iPhone Simulator 6.1
