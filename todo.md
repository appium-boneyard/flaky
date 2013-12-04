#### To Do

- Save execution time for each test. (this may already be in the minitest logs)
- Save overall execution time.
- Fix test numbering. 01, 02, etc.
- Better ways to format test names

```ruby
 lines.split("\n").each { |l| puts File.basename(l.split(',').first) }; nil
```
