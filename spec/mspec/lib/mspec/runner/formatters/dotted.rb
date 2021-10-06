require 'mspec/runner/formatters/base'

class DottedFormatter < BaseFormatter
  def initialize(out = nil)
    super
    @dot_width = nil
    @dot_count = 0
    if @out.tty?
      require 'io/console'
      @dot_width = @out.winsize[1] rescue 80
      # Maybe decrement for the right margin on Windows?
    end
  end

  def register
    super
    MSpec.register :after, self
  end

  # Callback for the MSpec :after event. Prints an indicator
  # for the result of evaluating this example as follows:
  #   . = No failure or error
  #   F = An SpecExpectationNotMetError was raised
  #   E = Any exception other than SpecExpectationNotMetError
  def after(state = nil)
    super(state)

    if exception?
      print failure? ? "F" : "E"
    else
      print "."
    end
    if @dot_width and (@dot_count += 1) >= @dot_width
      print "\n"
      @dot_count = 0
    end
  end
end
