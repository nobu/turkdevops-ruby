#
# make builtin_binary.inc file.
#

def dump_bin iseq
  bin = iseq.to_binary
  bin.each_byte.with_index{|b, index|
    print "\n " if (index%20) == 0
    print " 0x#{'%02x' % b.ord},"
  }
  print "\n"
end

ary = []
RubyVM::each_builtin{|feature, iseq|
  ary << [feature, iseq]
}

$stdout = open('builtin_binary.inc', 'wb')

puts <<H
// -*- c -*-
// DO NOT MODIFY THIS FILE DIRECTLY.
// auto-generated file by #{File.basename(__FILE__)}

H

ary.each{|feature, iseq|
  print "\n""static const unsigned char #{feature}_bin[] = {"
    dump_bin(iseq)
  puts "};"
}

def make_trie(a, i = 0)
  indent = "    "*(i+1)
  if a.size == 1
    feature = a[0]
    print indent, "if ("
    feature[i, 2].each_char do |c|
      print "*feature++ == '#{c}' && "
    end
    if feature.size > i+2
      print "strcmp(feature, #{feature[i+2..-1].dump}) == 0"
    else
      print "!*feature"
    end
    print ") RETURN_BIN(#{feature});\n"
  else
    print indent, "switch (*feature++) {\n"
    a.group_by {|n| n[i]}.each {|c, e|
      print indent, "  case '#{c || '\\0'}':\n"
      if c
        make_trie(e, i+1)
      else
        print indent, "    RETURN_BIN(#{e[0]});\n"
      end
      print indent, "    break;\n"
    }
    print indent, "}\n"
  end
end

puts "
static const unsigned char*
builtin_lookup(const char *feature, size_t *psize)
{
#define RETURN_BIN(f) do {*psize = sizeof(f##_bin); return f##_bin;} while (0)
"
make_trie(ary.map{|n,i|n})
puts "#undef RETURN_BIN
    return 0;
}"
