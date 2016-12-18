# frozen_string_literal: true
#
#   irb/ruby-lex.rb - ruby lexcal analyzer
#   	$Release Version: 0.9.6$
#   	$Revision$
#   	by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#

require "e2mmap"
require "ripper"

# :stopdoc:
class RubyLex

  extend Exception2MessageMapper
  def_exception(:TerminateLineInput, "Terminate Line Input")

  class << self
    attr_accessor :debug_level
    def debug?
      @debug_level > 0
    end
  end
  @debug_level = 0

  def initialize
    set_input(STDIN)

    @exp_line_no = @line_no = 1
    @readed = []
    @line = ""
    @exception_on_syntax_error = true
    @prompt = nil
  end

  attr_accessor :exception_on_syntax_error

  attr_reader :line_no
  attr_reader :indent

  # io functions
  def set_input(io, p = nil, &block)
    @io = io
    if p.respond_to?(:call)
      @input = p
    elsif block_given?
      @input = block
    else
      @input = Proc.new{@io.gets}
    end
  end

  def get_readed
    readed = @readed.join("")
    @readed = []
    readed
  end

  def eof?
    @io.eof?
  end

  def gets
    @ltype = @lexer.string?
    @indent = @lexer.nesting_level
    @line_no = @lexer.lineno
    prompt
    line = @input.call
    return nil unless line
    @readed << line
    @continue = true
    line
  end

  def set_prompt(p = nil, &block)
    p = block if block_given?
    if p.respond_to?(:call)
      @prompt = p
    else
      @prompt = Proc.new{print p}
    end
  end

  def prompt
    if @prompt
      @prompt.call(@ltype, @indent, @continue, @line_no)
    end
  end

  def initialize_input
    @ltype = nil
    @indent = 0
    @continue = false

    prompt

    @line = ""
    @exp_line_no = @line_no
    @readed.clear
    @lexer = Lexer.new(self, "(irb)", @line_no + 1)
  end

  def compile_error(str)
    raise SyntaxError, str if @exception_on_syntax_error
    top_statement
  end

  def top_statement
    @ltype = @lexer.string?
    @indent = @lexer.nesting_level
    @line_no = @lexer.lineno
    result = @block.call get_readed, @exp_line_no
    @exp_line_no = @line_no
    @continue = false
    result
  end

  def each_top_level_statement(&block)
    @block = block
    begin initialize_input end until @lexer.parse?
  end

  # def getline(rip)
  #   gets or throw :TERM_INPUT
  # end

  class Lexer < Ripper
    def initialize(*)
      super
      self.immediate_toplevel_statement = true
      self
    end

    def parse?
      parse
    rescue TerminateLineInput
      false
    else
      !error?
    end

    def compile_error(str)
      lex_input.compile_error(str)
    end

    def on_parse_error(str)
      lex_input.compile_error(str)
      raise TerminateLineInput
    end

    def on_top_stmt(str)
      lex_input.top_statement if eol?
    end
  end
end
# :startdoc:
