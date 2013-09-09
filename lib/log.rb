# encoding: utf-8
require 'rubygems'
require 'escape_utils'
require 'fileutils'

module Flaky
  class << self
    def html_before
      <<-'HTML'
<html>
<head>
<style>
* {
  padding: 0;
  margin: 0;
  border: 0;
  width: 0;
  height: 0;
}
div { display: inline; }
body { background-color: #262626; }
#terminal {
  display: inherit;
  white-space: pre;
  font-family: "Monaco";
  font-size: 14px;
  color: #f4f4f4;
  padding-left: 18px;
}
div.cyan  { color: #00eee9; }
div.green { color: #00e800; }
</style>
</head>
<body>
<!--
Monaco 18 pt
ANSI colors

[36m = 00eee9 = cyan
[32m = 00e800 = green
[0m  = f4f4f4 = reset
-->
<div id="terminal">
      HTML
    end

    def html_after
      <<-'HTML'
</div>
</body>
</html>
      HTML
    end

    def write log_file, log
      # directory must exist
      FileUtils.mkdir_p File.dirname log_file
      # Pry & Awesome Print use the ruby objects to insert term colors.
      # this can't be done with the raw text output.

      # must escape for rendering HTML in the browser
      log = EscapeUtils.escape_html log

      # replace ANSI color with divs
      log.gsub! /\[36m/, '<div class="cyan">'
      log.gsub! /\[32m/, '<div class="green">'
      log.gsub! /\[0m/, '</div>'

      File.open(log_file, 'w') do |f|
        f.write html_before + log + html_after
      end
    end
  end # class << self
end # module Flaky