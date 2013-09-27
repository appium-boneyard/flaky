# encoding: utf-8
module Flaky
  class << self
    # Monaco 18 pt
    # ANSI colors
    #
    # [36m = 00eee9 = cyan
    # [32m = 00e800 = green
    # [0m  = f4f4f4 = reset
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
div.grey  { color: #666666; }
</style>
</head>
<body>
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

      # [90mPOST /wd/hub/session [36m303 [90m6877ms - 9[0m

      scan = StringScanner.new log

      new_log = '<div>'

      color_rgx = /\[(\d+)m/
      while !scan.eos?
        match = scan.scan_until color_rgx
        match_size = scan.matched_size

        # no more color codes
        if match_size.nil?
          new_log += scan.rest
          new_log += '</div>'
          break
        end

        # save before the color code, excluding the color code
        new_log += match[0..-1 - match_size]
        new_log += '</div>'

        found_number = match.match(color_rgx).to_a.last.gsub(/[^\d]/,'').to_i

        # now make a new colored div
        color = case(found_number)
          when 39, 0 # white text
            '<div>'
          when 90 # grey
            '<div class="grey">'
          when 36
            '<div class="cyan">'
          when 32
            '<div class="green">'
          else
            '<div>' # Unknown color code
          end

        new_log += color
      end

      File.open(log_file, 'w') do |f|
        f.write html_before + new_log + html_after
      end
    end
  end # class << self
end # module Flaky