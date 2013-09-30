#### flaky

Run Appium iOS tests to measure flakiness.

- `gem install flaky`
- `flake 3 ios[nop]` - Run the iOS test named nop 3 times.

Results are stored in `/tmp/flaky`

This only works with Ruby and the directory layout must match [appium_lib iOS](https://github.com/appium/ruby_lib_ios).