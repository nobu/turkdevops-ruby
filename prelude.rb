class Binding
  # :nodoc:
  def irb
    require 'irb'
    irb
  end

  # suppress redefinition warning
  alias irb irb # :nodoc:
end

module Kernel
  def pp(*objs)
    require 'pp'
    pp(*objs)
  end

  # suppress redefinition warning
  alias pp pp # :nodoc:

  private :pp
end

autoload :Set, "set"

module Enumerable
  def to_set(*args, &block)
    require 'set'
    to_set(*args, &block)
  end

  alias to_set to_set
end

