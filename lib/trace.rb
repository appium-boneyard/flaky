
module Flaky
  ##
  # Trace file source to :io (default $stdout)
  #
  # spec_opts = {}
  #
  # @param :trace [Array<String>] the files to trace
  # @param :io [IO] io to print to
  def self.trace_specs spec_opts
    targets   = []
    files     = {}
    last_file = ''
    last_line = -1

    files_to_trace = spec_opts.fetch(:trace, []);
    io    = spec_opts.fetch(:io, $stdout)
    color = spec_opts.fetch(:color, "\e[32m") # ANSI.green default
    # target only existing readable files
    files_to_trace.each do |f|
      if File.exists?(f) && File.readable?(f)
        targets.push File.expand_path f
        targets.push File.basename f # sometimes the file is relative
      end
    end
    return if targets.empty?

    set_trace_func(lambda do |event, file, line, id, binding, classname|
      return unless targets.include?(file)

      # never repeat a line
      return if file == last_file && line == last_line

      file_sym        = file.intern
      files[file_sym] = IO.readlines(file) if files[file_sym].nil?
      lines           = files[file_sym]

      # arrays are 0 indexed and line numbers start at one.
      io.print color if color # ANSI code
      io.puts lines[line - 1]
      io.print "\e[0m" if color # ANSI.clear

      last_file = file
      last_line = line

    end)
  end
end
