
def inline_text argc, arg1
  raise "argc (#{argc}) of inline! should be 1" unless argc == 1
  raise "1st argument should be string literal" unless arg1.type == :STR
  arg1.children[0].rstrip
end

def make_cfunc_name inlines, name, lineno
  case name
  when /\[\]/
    name = '_GETTER'
  when /\[\]=/
    name = '_SETTER'
  else
    name = name.tr('!?', 'EP')
  end

  base = "builtin_inline_#{name}_#{lineno}"
  if inlines[base]
    1000.times{|i|
      name = "#{base}_#{i}"
      return name unless inlines[name]
    }
    raise "too many functions in same line..."
  else
    base
  end
end

def collect_builtin base, tree, name, bs, inlines
  while tree
    case tree.type
    when :SCOPE
      tree = tree.children[2]
      next
    when :DEFN
      name, tree = tree.children
      next
    when :DEFS
      _recv, name, tree = tree.children
      next
    when :CLASS
      name = 'class'
      tree = tree.children[2]
      next
    when :SCLASS, :MODULE
      name = 'class'
      tree = tree.children[1]
      next
    when :CALL, :FCALL, :VCALL
      if tree.type == :CALL
        recv, mid, args = tree.children
        func_name = (mid.to_s if recv.type == :VCALL and recv.children[0] == :__builtin__)
      else
        mid, args = tree.children
        func_name = mid[/\A__builtin_(.+)/, 1]
      end
      if func_name and (!args or %i[ARRAY LIST].include?(args.type))
        cfunc_name = func_name
        lineno = tree.first_lineno
        tree = args
        args.pop unless (args = args ? args.children : []).last
        argc = args.size

        if /(.+)\!\z/ =~ func_name
          case $1
          when 'cstmt'
            text = inline_text argc, args.first

            func_name = "_bi#{inlines.size}"
            cfunc_name = make_cfunc_name(inlines, name, lineno)
            inlines[cfunc_name] = [lineno, text, params, func_name]
            argc -= 1
          when 'cexpr', 'cconst'
            text = inline_text argc, args.first
            code = "return #{text};"

            func_name = "_bi#{inlines.size}"
            cfunc_name = make_cfunc_name(inlines, name, lineno)

            params = [] if $1 == 'cconst'
            inlines[cfunc_name] = [lineno, code, params, func_name]
            argc -= 1
          when 'cinit'
            text = inline_text argc, args.first
            func_name = nil
            inlines[inlines.size] = [nil, [lineno, text, nil, nil]]
            argc -= 1
          end
        end

        if bs[func_name] &&
           bs[func_name] != [argc, cfunc_name]
          raise "same builtin function \"#{func_name}\", but different arity (was #{bs[func_name]} but #{argc})"
        end

        bs[func_name] = [argc, cfunc_name] if func_name

        break unless tree
      end
    end

    k = tree.class
    tree.children.each do |t|
      collect_builtin base, t, name, bs, inlines if k === t
    end
    break
  end
end
# ruby mk_builtin_loader.rb TARGET_FILE.rb
# #=> generate TARGET_FILE.rbinc
#

def mk_builtin_header file
  base = File.basename(file, '.rb')
  ofile = "#{file}inc"

  # bs = { func_name => argc }
  collect_builtin(base, RubyVM::AbstractSyntaxTree.parse_file(file), 'top', bs = {}, inlines = {})

  begin
    f = open(ofile, 'w')
  rescue Errno::EACCES
    # Fall back to the current directory
    f = open(File.basename(ofile), 'w')
  end
  begin
    f.puts "// -*- c -*-"
    f.puts "// DO NOT MODIFY THIS FILE DIRECTLY."
    f.puts "// auto-generated file"
    f.puts "//   by #{__FILE__}"
    f.puts "//   with #{file}"
    f.puts '#include "internal/compilers.h"     /* for MAYBE_UNUSED */'
    f.puts '#include "internal/warnings.h"      /* for COMPILER_WARNING_PUSH */'
    f.puts '#include "ruby/ruby.h"              /* for VALUE */'
    f.puts '#include "builtin.h"                /* for RB_BUILTIN_FUNCTION */'
    f.puts 'struct rb_execution_context_struct; /* in vm_core.h */'
    f.puts
    lineno = 11
    line_file = file.gsub('\\', '/')

    inlines.each{|cfunc_name, (body_lineno, text, params, func_name)|
      if String === cfunc_name
        f.puts "static VALUE #{cfunc_name}(struct rb_execution_context_struct *ec, const VALUE self) {"
        lineno += 1

        params.reverse_each.with_index{|param, i|
          next unless Symbol === param
          f.puts "MAYBE_UNUSED(const VALUE) #{param} = rb_vm_lvar(ec, #{-3 - i});"
          lineno += 1
        }
        f.puts "#line #{body_lineno} \"#{line_file}\""
        lineno += 1

        f.puts text
        lineno += text.count("\n") + 1

        f.puts "#line #{lineno + 2} \"#{ofile}\"" # TODO: restore line number.
        f.puts "}"
        lineno += 2
      else
        # cinit!
        f.puts "#line #{body_lineno} \"#{line_file}\""
        lineno += 1
        f.puts text
        lineno += text.count("\n") + 1
        f.puts "#line #{lineno + 2} \"#{ofile}\"" # TODO: restore line number.
        lineno += 1
      end
    }

    f.puts "void Init_builtin_#{base}(void)"
    f.puts "{"

    table = "#{base}_table"
    f.puts "  // table definition"
    f.puts "  static const struct rb_builtin_function #{table}[] = {"
    bs.each.with_index{|(func, (argc, cfunc_name)), i|
      f.puts "    RB_BUILTIN_FUNCTION(#{i}, #{func}, #{cfunc_name}, #{argc}),"
    }
    f.puts "    RB_BUILTIN_FUNCTION(-1, NULL, NULL, 0),"
    f.puts "  };"

    f.puts
    f.puts "  // arity_check"
    f.puts "COMPILER_WARNING_PUSH"
    f.puts "#if GCC_VERSION_SINCE(5, 1, 0) || __clang__"
    f.puts "COMPILER_WARNING_ERROR(-Wincompatible-pointer-types)"
    f.puts "#endif"
    bs.each{|func, (argc, cfunc_name)|
      f.puts "  if (0) rb_builtin_function_check_arity#{argc}(#{cfunc_name});"
    }
    f.puts "COMPILER_WARNING_POP"


    f.puts
    f.puts "  // load"
    f.puts "  rb_load_with_builtin_functions(#{base.dump}, #{table});"

    f.puts "}"
  ensure
    f.close
  end
end

ARGV.each{|file|
  # feature.rb => load_feature.inc
  mk_builtin_header file
}
