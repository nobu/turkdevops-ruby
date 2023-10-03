require 'not_implemented'
require 'test/unit'

class TestNotImplemented < Test::Unit::TestCase
  class Area
    not_implemented :calculate
  end

  class Square < Area
    def initialize(line) = @line = line
    def calculate = @line * @line
  end

  def test_not_implemented_error
    a = Area.new
    assert_not_respond_to(a, :calculate)
    assert_not_operator(Area, :method_defined?, :calculate)
    assert_raise_with_message(NotImplementedError, /calculate/) do
      a.calculate
    end
  end

  def test_overridden
    a = Square.new(1)
    assert_respond_to(a, :calculate)
    assert_operator(Square, :method_defined?, :calculate)
    assert_equal(1, a.calculate)
  end
end
