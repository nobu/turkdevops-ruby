# Simple DSL implementation for Ripper code generation
#
# input: /*% ripper: stmts_add(stmts_new, void_stmt) %*/
# output:
#   VALUE v1, v2;
#   v1 = dispatch0(stmts_new);
#   v2 = dispatch0(void_stmt);
#   $<ripper.value>$ = dispatch2(stmts_add, v1, v2);

$RIPPER_VALUE = "$<ripper.value>$"
alias $$ $RIPPER_VALUE

class DSL
  def initialize(code, options)
    @events = {}
    @error = options.include?("error")
    @brace = options.include?("brace")
    @final = options.include?("final")
    @vars = 0

    # create $1 == "$<ripper.value>1", $2 == "$<ripper.value>2", ...
    s = (1..9).map {|n| "$<ripper.value>#{ n }" }
    re = Array.new(s.size, "([^\0]+)")
    /#{ re.join("\0") }/ =~ s.join("\0")

    # struct parser_params *p
    p = "p"

    @code = ""
    @last_value = eval(code)
  end

  attr_reader :events

  undef lambda
  undef hash
  undef class

  def generate
    s = "$<ripper.value>$"
    s = "p->result" if @final
    s = "#@code#{ s }=#@last_value;"
    if @vars > 0
      vars = (1..@vars).map {|v| "v#{ v }" }.join(",")
      s = "{VALUE #{vars};#{s}}"
    end
    s << "ripper_error(p);" if @error
    s = "{#{ s }}" if @brace
    s
  end

  def new_var
    "v#{ @vars += 1 }"
  end

  def opt_event(event, default, addend)
    add_event(event, [default, addend], true)
  end

  def add_event(event, args, qundef_check = false)
    event = event.to_s.sub(/!\z/, "")
    @events[event] = args.size
    vars = []
    args.each do |arg|
      vars << v = new_var
      @code << "#{ v }=#{ arg };"
    end
    v = new_var
    d = "dispatch#{ args.size }(#{ [event, *vars].join(",") })"
    d = "#{ vars.last }==Qundef ? #{ vars.first } : #{ d }" if qundef_check
    @code << "#{ v }=#{ d };"
    v
  end

  def method_missing(event, *args)
    if event.to_s =~ /!\z/
      add_event(event, args)
    elsif args.empty? and /\Aid[A-Z_]/ =~ event.to_s
      event
    elsif /\AID2/ =~ event and args.size == 1 and String === args[0] and args[0].size == 1
      "#{event}('#{args[0]}')"
    else
      "#{ event }(#{ args.join(", ") })"
    end
  end

  def self.const_missing(name)
    name
  end
end

