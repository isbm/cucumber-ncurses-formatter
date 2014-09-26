require 'cucumber/formatter/console'
require 'cucumber/formatter/io'
require 'ansi'
require 'cucumber/formatter/term'

class Mock
  def method_missing(name, *args)
    puts "D: #{name}(#{args.join(',')})"
  end
end

module Cucumber
  module Formatter
    class Terminal
      include Io
      attr_reader :runtime

      def initialize(runtime, path_or_io, options)
        @runtime, @io, @options = runtime, ensure_io(path_or_io, "progress"), options
        @term_height = ANSI::Terminal.terminal_height
        @term_width = ANSI::Terminal.terminal_width
	@term = TermApp.new(@term_width, @term_height)
        @p = Thread.new {
          @term.run()
        }
        #@term = Mock.new
      end

      def after_feature_element(*args)
        @term.inc_step(0)
        if (defined? @exception_raised) and (@exception_raised)
          @term.inc_step(1)
        else
          @term.inc_step(2)
        end
        @exception_raised = false
      end

      def after_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background, file_colon_line)
        #@term.console("#{keyword}: #{step_match.step_definition}")
      end

      def step_name(keyword, step_match, status, source_indent, background, file_colon_line)
        #@term.inc_step(0)
        if status == :passed
	  @term.inc_step(2)
	elsif status == :failed
	  @term.inc_step(1)
	elsif status == :skipped
	  @term.inc_step(3)
	else
	  @term.inc_step(0)
	end
        msg = %q{%s %10s %s %-10s @ %s} % [Time.new.inspect, status, keyword,
                                           step_match.format_args(lambda{|param| param}),
                                           step_match.file_colon_line]
        @term.console(msg);
      end

      def after_features(features)
        @term.do_finish()
        @p.join()
      end
    end
  end
end
