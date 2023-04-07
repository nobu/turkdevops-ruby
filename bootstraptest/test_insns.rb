# C0 coverage of each instructions

# :NOTE: This is for development purpose; never consider this file as
# ISeq compilation specification.

begin
  # This library brings some additional coverage.
  # Not mandatory.
  require 'rbconfig/sizeof'
rescue LoadError
  # OK, just skip
else
  if defined? RbConfig::LIMITS
    $FIXNUM_MAX = RbConfig::LIMITS["FIXNUM_MAX"]
    $FIXNUM_MIN = RbConfig::LIMITS["FIXNUM_MIN"]
  end
end

# +expr+ is  expression to generate +insn+
def assert_insn(insn, expr, *a, **kw)
  # normal path
  assert_equal 'true', expr, insn, *a, **kw

  # with trace
  progn = "set_trace_func(proc{})\n" + expr
  assert_equal 'true', progn, 'trace_' + insn, *a, **kw
end

assert_insn('nop',   %q{ raise rescue true })

assert_insn('setlocal *, 0', %q{ x = true })
assert_insn('setlocal *, 1', %q{ x = nil; -> { x = true }.call })
assert_insn('setlocal',      %q{ x = nil; -> { -> { x = true }.() }.() })
assert_insn('getlocal *, 0', %q{ x = true; x })
assert_insn('getlocal *, 1', %q{ x = true; -> { x }.call })
assert_insn('getlocal',      %q{ x = true; -> { -> { x }.() }.() })

assert_insn('setblockparam', "#{<<'{'}#{<<'}'}")
{
  def m&b
    b = # here
      proc { true }
  end
  m { false }.call
}
assert_insn('getblockparam', "#{<<'{'}#{<<'}'}")
{
  def m&b
    b # here
  end
  m { true }.call
}
assert_insn('getblockparamproxy', "#{<<'{'}#{<<'}'}")
{
  def m&b
    b # here
      .call
  end
  m { true }
}

assert_insn('setspecial', %q{ true if true..true })
assert_insn('getspecial', %q{ $&.nil? })
assert_insn('getspecial', %q{ $`.nil? })
assert_insn('getspecial', %q{ $'.nil? })
assert_insn('getspecial', %q{ $+.nil? })
assert_insn('getspecial', %q{ $1.nil? })
assert_insn('getspecial', %q{ $128.nil? })

assert_insn('getglobal', %q{ String === $0 })
assert_insn('getglobal', %q{ $_.nil? })
assert_insn('setglobal', %q{ $0 = "true" })

assert_insn('setinstancevariable', %q{ @x = true })
assert_insn('getinstancevariable', %q{ @x = true; @x })

assert_insn('setclassvariable', %q{ class A; @@x = true; end })
assert_insn('getclassvariable', %q{ class A; @@x = true; @@x end })

assert_insn('setconstant', %q{ X = true })
assert_insn('setconstant', %q{ Object::X = true })
assert_insn('getconstant', %q{ X = true; X })
assert_insn('getconstant', %q{ X = true; Object::X })

assert_insn('getinlinecache / setinlinecache', %q{ def x; X; end; X = true; x; x; x })

assert_insn('putnil',               %q{ $~ == nil })
assert_insn('putself',              %q{ $~ != self })
assert_insn('putobject INT2FIX(0)', %q{ $~ != 0 })
assert_insn('putobject INT2FIX(1)', %q{ $~ != 1 })
assert_insn('putobject',            %q{ $~ != -1 })
assert_insn('putobject',            %q{ $~ != /x/ })
assert_insn('putobject',            %q{ $~ != :x })
assert_insn('putobject',            %q{ $~ != (1..2) })
assert_insn('putobject',            %q{ $~ != true })
assert_insn('putobject',            %q{ /(?<x>x)/ =~ "x"; x == "x" })

assert_insn('putspecialobject',         %q{ {//=>true}[//] })
assert_insn('putstring',                %q{ "true" })
assert_insn('tostring / concatstrings', %q{ "#{true}" })
assert_insn('toregexp',                 %q{ /#{true}/ =~ "true" && $~ })
assert_insn('intern',                   %q{ :"#{true}" })

assert_insn('newarray',    %q{ ["true"][0] })
assert_insn('newarraykwsplat', %q{ [**{x:'true'}][0][:x] })
assert_insn('duparray',    %q{ [ true ][0] })
assert_insn('expandarray', %q{ y = [ true, false, nil ]; x, = y; x })
assert_insn('expandarray', %q{ y = [ true, false, nil ]; x, *z = y; x })
assert_insn('expandarray', %q{ y = [ true, false, nil ]; x, *z, w = y; x })
assert_insn('splatarray',  %q{ x, = *(y = true), false; x })
assert_insn('concatarray', %q{ ["t", "r", *x = "u", "e"].join })
assert_insn('concatarray', "#{<<'{'}#{<<'}'}")
{
  class X; def to_a; ['u']; end; end
  ['t', 'r', *X.new, 'e'].join
}
assert_insn('concatarray', "#{<<'{'}#{<<'}'}")
{
  r = false
  t = [true, nil]
  q, w, e = r, *t             # here
  w
}

assert_insn('newhash',  %q{ x = {}; x[x] = true })
assert_insn('newhash',  %q{ x = true; { x => x }[x] })
assert_insn('newhashfromarray', %q{ { a: true }[:a] })
assert_insn('newrange', %q{ x = 1; [*(0..x)][0] == 0 })
assert_insn('newrange', %q{ x = 1; [*(0...x)][0] == 0 })

assert_insn('pop',     %q{ def x; true; end; x })
assert_insn('dup',     %q{ x = y = true; x })
assert_insn('dupn',    %q{ Object::X ||= true })
assert_insn('reverse', %q{ q, (w, e), r = 1, [2, 3], 4; e == 3 })
assert_insn('swap',    %q{ !!defined?([[]]) })
assert_insn('swap',    "#{<<'{'}#{<<'}'}")
{
  x = [[false, true]]
  for i, j in x               # here
    ;
  end
  j
}

assert_insn('topn',        %q{ x, y = [], 0; x[*y], = [true, false]; x[0] })
assert_insn('setn',        %q{ x, y = [], 0; x[*y]  =  true        ; x[0] })
assert_insn('adjuststack', %q{ x = [true]; x[0] ||= nil; x[0] })

assert_insn('defined',      %q{ !defined?(x) })
assert_insn('checkkeyword', %q{ def x x:rand;x end; x x: true })
assert_insn('checktype',    %q{ x = true; "#{x}" })
assert_insn('checkmatch',   "#{<<'{'}#{<<'}'}")
{
  x = y = true
  case x
  when false
    y = false
  when true                   # here
    y = nil
  end
  y == nil
}
assert_insn('checkmatch',   "#{<<'{'}#{<<'}'}")
{
  x, y = true, [false]
  case x
  when *y                     # here
    z = false
  else
    z = true
  end
  z
}
assert_insn('checkmatch',   "#{<<'{'}#{<<'}'}")
{
  x = false
  begin
    raise
  rescue                      # here
    x = true
  end
  x
}

assert_insn('defineclass', %q{                 module X;    true end })
assert_insn('defineclass', %q{ X = Module.new; module X;    true end })
assert_insn('defineclass', %q{                 class X;     true end })
assert_insn('defineclass', %q{ X = Class.new;  class X;     true end })
assert_insn('defineclass', %q{ X = Class.new;  class Y < X; true end })
assert_insn('defineclass', %q{ X = Class.new;  class << X;  true end })
assert_insn('defineclass', "#{<<'{'}#{<<'}'}")
{
  X = Class.new
  Y = Class.new(X)
  class Y < X
    true
  end
}

assert_insn('opt_send_without_block', %q{ true.to_s })
assert_insn('send',                   %q{ true.tap {|i| i.to_s } })
assert_insn('leave',                  %q{ def x; true; end; x })
assert_insn('invokesuper',            "#{<<'{'}#{<<'}'}")
{
  class X < String
    def empty?
      super                   # here
    end
  end
  X.new.empty?
}
assert_insn('invokeblock',            "#{<<'{'}#{<<'}'}")
{
  def x
    return yield self         # here
  end
  x do
    true
  end
}

assert_insn('opt_str_freeze', %q{ 'true'.freeze })
assert_insn('opt_nil_p',      %q{ nil.nil? })
assert_insn('opt_nil_p',      %q{ !Object.nil? })
assert_insn('opt_nil_p',      %q{ Class.new{def nil?; true end}.new.nil? })
assert_insn('opt_str_uminus', %q{ -'true' })
assert_insn('opt_str_freeze', "#{<<'{'}#{<<'}'}")
{
  class String
    def freeze
      true
    end
  end
  'true'.freeze
}

assert_insn('opt_newarray_max', %q{ [ ].max.nil? })
assert_insn('opt_newarray_max', %q{ [1, x = 2, 3].max == 3 })
assert_insn('opt_newarray_max', "#{<<'{'}#{<<'}'}")
{
  class Array
    def max
      true
    end
  end
  [1, x = 2, 3].max
}
assert_insn('opt_newarray_min', %q{ [ ].min.nil? })
assert_insn('opt_newarray_min', %q{ [3, x = 2, 1].min == 1 })
assert_insn('opt_newarray_min', "#{<<'{'}#{<<'}'}")
{
  class Array
    def min
      true
    end
  end
  [3, x = 2, 1].min
}

assert_insn('throw',        %q{ false.tap { break true } })
assert_insn('branchif',     %q{ x = nil;  x ||= true })
assert_insn('branchif',     %q{ x = true; x ||= nil; x })
assert_insn('branchunless', %q{ x = 1;    x &&= true })
assert_insn('branchunless', %q{ x = nil;  x &&= true; x.nil? })
assert_insn('branchnil',    %q{ x = true; x&.to_s })
assert_insn('branchnil',    %q{ x = nil;  (x&.to_s).nil? })
assert_insn('jump',         "#{<<'{'}#{<<'}'}")
{
  y = 1
  x = if y == 0 then nil elsif y == 1 then true else nil end
  x
}
assert_insn('jump',         "#{<<'{'}#{<<'}'}")
{
  # ultra complicated situation: this ||= assignment only generates
  # 15 instructions, not including the class definition.
  class X; attr_accessor :x; end
  x = X.new
  x&.x ||= true               # here
}

assert_insn('once', %q{ /#{true}/o =~ "true" && $~ })
assert_insn('once', "#{<<'{'}#{<<'}'}")
{
  def once expr
    return /#{expr}/o         # here
  end
  x = once(true); x = once(false); x = once(nil);
  x =~ "true" && $~
}
assert_insn('once', "#{<<'{'}#{<<'}'}")
{
  # recursive once
  def once n
    return %r/#{
      if n == 0
        true
      else
        once(n-1)             # here
      end
    }/ox
  end
  x = once(128); x = once(7); x = once(16);
  x =~ "true" && $~
}
assert_insn('once', "#{<<'{'}#{<<'}'}")
{
  # inter-thread lockup situation
  def once n
    return Thread.start n do |m|
      Thread.pass
      next %r/#{
        sleep m               # here
        true
      }/ox
    end
  end
  x = once(1); y = once(0.1); z = y.value
  z =~ "true" && $~
}

assert_insn('opt_case_dispatch', %q{ case   0 when 1.1 then false else true end })
assert_insn('opt_case_dispatch', %q{ case 1.0 when 1.1 then false else true end })

assert_insn('opt_plus',    %q{ 1 + 1 == 2 })
if defined? $FIXNUM_MAX then
  assert_insn('opt_plus',  %Q{ #{ $FIXNUM_MAX } + 1 == #{ $FIXNUM_MAX + 1 } })
end
assert_insn('opt_plus',    %q{ 1.0 + 1.0 == 2.0 })
assert_insn('opt_plus',    %q{ x = +0.0.next_float; x + x >= x })
assert_insn('opt_plus',    %q{ 't' + 'rue' })
assert_insn('opt_plus',    %q{ ( ['t'] + ['r', ['u', ['e'], ], ] ).join })
assert_insn('opt_plus',    %q{ Time.at(1) + 1 == Time.at(2) })
assert_insn('opt_minus',   %q{ 1 - 1 == 0 })
if defined? $FIXNUM_MIN then
  assert_insn('opt_minus', %Q{ #{ $FIXNUM_MIN } - 1 == #{ $FIXNUM_MIN - 1 } })
end
assert_insn('opt_minus',   %q{ 1.0 - 1.0 == 0.0 })
assert_insn('opt_minus',   %q{ x = -0.0.prev_float; x - x == 0.0 })
assert_insn('opt_minus',   %q{ ( [false, true] - [false] )[0] })
assert_insn('opt_mult',    %q{ 1 * 1 == 1 })
assert_insn('opt_mult',    %q{ 1.0 * 1.0 == 1.0 })
assert_insn('opt_mult',    %q{ x = +0.0.next_float; x * x <= x })
assert_insn('opt_mult',    %q{ ( "ruet" * 3 )[7,4] })
assert_insn('opt_div',     %q{ 1 / 1 == 1 })
assert_insn('opt_div',     %q{ 1.0 / 1.0 == 1.0 })
assert_insn('opt_div',     %q{ x = +0.0.next_float; x / x >= x })
assert_insn('opt_div',     %q{ x = 1/2r; x / x == 1 })
assert_insn('opt_mod',     %q{ 1 % 1 == 0 })
assert_insn('opt_mod',     %q{ 1.0 % 1.0 == 0.0 })
assert_insn('opt_mod',     %q{ x = +0.0.next_float; x % x == 0.0 })
assert_insn('opt_mod',     %q{ '%s' % [ true ] })

assert_insn('opt_eq', %q{ 1 == 1 })
assert_insn('opt_eq', "#{<<'{'}#{<<'}'}")
{
  class X; def == other; true; end; end
  X.new == true
}
assert_insn('opt_neq', %q{ 1 != 0 })
assert_insn('opt_neq', "#{<<'{'}#{<<'}'}")
{
  class X; def != other; true; end; end
  X.new != true
}

assert_insn('opt_lt', %q{            -1   <  0 })
assert_insn('opt_lt', %q{            -1.0 <  0.0 })
assert_insn('opt_lt', %q{ -0.0.prev_float <  0.0 })
assert_insn('opt_lt', %q{              ?a <  ?z })
assert_insn('opt_le', %q{            -1   <= 0 })
assert_insn('opt_le', %q{            -1.0 <= 0.0 })
assert_insn('opt_le', %q{ -0.0.prev_float <= 0.0 })
assert_insn('opt_le', %q{              ?a <= ?z })
assert_insn('opt_gt', %q{             1   >  0 })
assert_insn('opt_gt', %q{             1.0 >  0.0 })
assert_insn('opt_gt', %q{ +0.0.next_float >  0.0 })
assert_insn('opt_gt', %q{              ?z >  ?a })
assert_insn('opt_ge', %q{             1   >= 0 })
assert_insn('opt_ge', %q{             1.0 >= 0.0 })
assert_insn('opt_ge', %q{ +0.0.next_float >= 0.0 })
assert_insn('opt_ge', %q{              ?z >= ?a })

assert_insn('opt_ltlt', %q{  '' << 'true' })
assert_insn('opt_ltlt', %q{ ([] << 'true').join })
assert_insn('opt_ltlt', %q{ (1 << 31) == 2147483648 })

assert_insn('opt_aref', %q{ ['true'][0] })
assert_insn('opt_aref', %q{ { 0 => 'true'}[0] })
assert_insn('opt_aref', %q{ 'true'[0] == ?t })
assert_insn('opt_aset', %q{ [][0] = true })
assert_insn('opt_aset', %q{ {}[0] = true })
assert_insn('opt_aset', %q{ x = 'frue'; x[0] = 't'; x })
assert_insn('opt_aset', "#{<<'{'}#{<<'}'}")
{
  # opt_aref / opt_aset mixup situation
  class X; def x; {}; end; end
  x = X.new
  x&.x[true] ||= true         # here
}

assert_insn('opt_aref_with', %q{ { 'true' => true }['true'] })
assert_insn('opt_aref_with', %q{ Struct.new(:nil).new['nil'].nil? })
assert_insn('opt_aset_with', %q{ {}['true'] = true })
assert_insn('opt_aset_with', %q{ Struct.new(:true).new['true'] = true })

assert_insn('opt_length',  %q{   'true'       .length == 4 })
assert_insn('opt_length',  %q{   :true        .length == 4 })
assert_insn('opt_length',  %q{ [ 'true' ]     .length == 1 })
assert_insn('opt_length',  %q{ { 'true' => 1 }.length == 1 })
assert_insn('opt_size',    %q{   'true'       .size   == 4 })
assert_insn('opt_size',    %q{               1.size   >= 4 })
assert_insn('opt_size',    %q{ [ 'true' ]     .size   == 1 })
assert_insn('opt_size',    %q{ { 'true' => 1 }.size   == 1 })
assert_insn('opt_empty_p', %q{ ''.empty? })
assert_insn('opt_empty_p', %q{ [].empty? })
assert_insn('opt_empty_p', %q{ {}.empty? })
assert_insn('opt_empty_p', %q{ Thread::Queue.new.empty? })

assert_insn('opt_succ',  %q{ 1.succ == 2 })
if defined? $FIXNUM_MAX then
  assert_insn('opt_succ',%Q{ #{ $FIXNUM_MAX }.succ == #{ $FIXNUM_MAX + 1 } })
end
assert_insn('opt_succ',  %q{ '1'.succ == '2' })

assert_insn('opt_not',  %q{ ! false })
assert_insn('opt_neq', "#{<<'{'}#{<<'}'}")
{
  class X; def !; true; end; end
  ! X.new
}

assert_insn('opt_regexpmatch2',  %q{ /true/ =~ 'true' && $~ })
assert_insn('opt_regexpmatch2', "#{<<'{'}#{<<'}'}")
{
  class Regexp; def =~ other; true; end; end
  /true/ =~ 'true'
}
assert_insn('opt_regexpmatch2',  %q{ 'true' =~ /true/ && $~ })
assert_insn('opt_regexpmatch2', "#{<<'{'}#{<<'}'}")
{
  class String; def =~ other; true; end; end
  'true' =~ /true/
}

assert_normal_exit("#{<<-"begin;"}\n#{<<-'end;'}")
begin;
  RubyVM::InstructionSequence.compile("", debug_level: 5)
end;
