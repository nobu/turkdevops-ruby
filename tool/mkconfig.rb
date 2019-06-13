#!./miniruby

# This script, which is run when ruby is built, generates rbconfig.rb by
# parsing information from config.status.  rbconfig.rb contains build
# information for ruby (compiler flags, paths, etc.) and is used e.g. by
# mkmf to build compatible native extensions.

# avoid warnings with -d.

args = {}
ARGV.each do |arg|
  if /\A-(\w+)=(.*)/ =~ arg
    k, v = $1, $2
    k = k.upcase if k.start_with?("unicode_")
    args[k] = v
  end
end

version = args.delete('version') or raise "missing -version"
install_name = args.delete('install_name')
so_name = args.delete('so_name')

srcdir = File.expand_path('../..', __FILE__)
$:.replace [srcdir+"/lib"] unless args['cross_compiling'] == "yes"
$:.unshift(".")

mkconfig = File.basename($0)

fast = %w[
  MAJOR MINOR TEENY PATCHLEVEL
  ruby_install_name RUBY_INSTALL_NAME INSTALL
]
vars = {}
continued_name = nil
continued_line = nil
platform = nil
drive = File::PATH_SEPARATOR == ';'
dest = drive ? %r'= "(?!\$[\(\{])(?i:[a-z]:)' : %r'= "(?!\$[\(\{])'
File.foreach "config.status" do |line|
  next if /^#/ =~ line
  name = nil
  case line
  when /^s([%,])@(\w+)@\1(?:\|\#_!!_\#\|)?(.*)\1/
    name = $2
    val = $3.gsub(/\\(?=,)/, '')
  when /^S\["(\w+)"\]\s*=\s*"(.*)"\s*(\\)?$/
    name = $1
    val = $2
    if $3
      continued_line = [val]
      continued_name = name
      next
    end
  when /^"(.*)"\s*(\\)?$/
    next if !continued_line
    continued_line << $1
    next if $2
    continued_line.each {|s| s.sub!(/\\n\z/, "\n")}
    val = continued_line.join
    name = continued_name
    continued_line = nil
  when /^(?:ac_given_)?INSTALL=(['"])(.*)\1/
    name = "INSTALL"
    val = $2
  else
    next
  end

  case name
  when 'RUBY_INSTALL_NAME'
  when 'RUBY_SO_NAME'
  when 'DESTDIR'; next
  when 'prefix'
    val.sub!(%r[/\.\z], '/')
  when 'sitearch'; val = '$(arch)' if val.empty?
  when 'configure_args'
    val.gsub!(/--with-out-ext/, "--without-ext")
  when /RUBYGEMS/; next
  when /^(?:ac_.*|configure_input|(?:top_)?srcdir|\w+OBJS)$/; next
  when /^(?:X|(?:MINI|RUN|(?:HAVE_)?BASE|BOOTSTRAP|BTEST)RUBY(?:_COMMAND)?$)/; next
  when /^INSTALLDOC|TARGET$/; next
  when /^DTRACE/; next
  when /^MJIT_(CC|SUPPORT)$/; # pass
  when /^MJIT_/; next
  when /^(?:MAJOR|MINOR|TEENY)$/; vars[name] = val; next
  when /^LIBRUBY_D?LD/; next
  end

  case val
  when /^\$\(ac_\w+\)$/; next
  when /^\$\{ac_\w+\}$/; next
  when /^\$ac_\w+$/; next
  end

  if /^(?!abs_|old)[a-z]+(?:_prefix|dir)$/ =~ name
    next if val == "no"
    val.sub!(dest, '"$(DESTDIR)')
  end

  val = val.gsub(/\$(?:\$|\{?(\w+)\}?)/) {$1 ? "$(#{$1})" : $&}

  if vars[name]
    vars[name] << "\n" << val
  else
    vars[name] = val
  end
end

IO.foreach(File.join(srcdir, "version.h")) do |l|
  m = /^\s*#\s*define\s+RUBY_(PATCHLEVEL|VERSION_(\w+))\s+(-?\d+)/.match(l)
  if m
    vars[m[2] || m[1]] = m[3]
  end
end
IO.foreach(File.join(srcdir, "include/ruby/version.h")) do |l|
  m = /^\s*#\s*define\s+RUBY_API_VERSION_(\w+)\s+(-?\d+)/.match(l)
  if m
    vars[m[1]] ||= m[2]
    next
  end
end

vars.update(args)

vars['MAJOR'], vars['MINOR'], vars['TEENY'] = version.split('.')
vars['target'] = '$(target_cpu)-$(target_vendor)-$(target_os)'
vars['host'] = '$(host_cpu)-$(host_vendor)-$(host_os)'
vars.keys.grep(/\Ahost(_(?:os|vendor|cpu|alias))?\z/) {vars[$&] = "$(target#{$1})"}
vars["archdir"] = "$(rubyarchdir)"

vconf = {}
def vconf.expand(val, config = self)
  newval = val.gsub(/\$\$|\$\(([^()]+)\)|\$\{([^{}]+)\}/) {
    var = $&
    if !(v = $1 || $2)
      '$'
    elsif key = config[v = v[/\A[^:]+(?=(?::(.*?)=(.*))?\z)/]]
      pat, sub = $1, $2
      config[v] = false
      config[v] = expand(key, config)
      key = key.gsub(/#{Regexp.quote(pat)}(?=\s|\z)/n) {sub} if pat
      key
    else
      var
    end
  }
  val.replace(newval) unless newval == val
  val
end

arch = vars['arch']
if /universal/ =~ arch
  vars['ARCH_FLAG'][0, 0] = "arch_flag || "
  universal = vars['UNIVERSAL_ARCHNAMES']
  vars['UNIVERSAL_ARCHNAMES'] = 'universal'
  arch.sub!(/universal/, %q[#{universal[/(?:\A|\s)#{Regexp.quote(arch)}=(\S+)/, 1] || '\&'}])
  vars['target_cpu'] = 'cpu'
end
if /darwin/ =~ arch
  vars['includedir'][0, 0] = '$(SDKROOT)'
end

val = vars['program_transform_name']
val.sub!(/\As(\\?\W)(?:\^|\${1,2})\1\1(;|\z)/, '')
if val.empty?
  install_name ||= "ruby"
elsif !install_name
  install_name = "ruby"
  val.gsub!(/\$\$/, '$')
  val.scan(%r[\G[\s;]*(/(?:\\.|[^/])*+/)?([sy])(\\?\W)((?:(?!\3)(?:\\.|.))*)\3((?:(?!\3)(?:\\.|.))*+)\3([gi]*+)]) do
    |addr, cmd, sep, pat, rep, opt|
    if addr
      Regexp.new(addr[/\A\/(.*)\/\z/, 1]) =~ install_name or next
    end
    case cmd
    when 's'
      pat = Regexp.new(pat, opt.include?('i'))
      if opt.include?('g')
        install_name.gsub!(pat, rep)
      else
        install_name.sub!(pat, rep)
      end
    when 'y'
      install_name.tr!(Regexp.quote(pat), rep)
    end
  end
end

if install_name
  vars['RUBY_INSTALL_NAME'] = install_name
else
  install_name = vars['RUBY_INSTALL_NAME'] ||= 'ruby'
end
vars['ruby_install_name'] ||= vars['RUBY_INSTALL_NAME']
if so_name
  vars['RUBY_SO_NAME'] = so_name
end

prefix = (vars["prefix"] ||= "").dup
rubyarchdir = (vars["rubyarchdir"] ||= "").dup

vars.each {|k, v| vconf[k] = v.dup}

vconf.expand(prefix)
vconf.expand(rubyarchdir)
relative_archdir = rubyarchdir.rindex(prefix, 0) ? rubyarchdir[prefix.size..-1] : rubyarchdir

puts %[\
# encoding: ascii-8bit
# frozen-string-literal: false
#
# The module storing Ruby interpreter configurations on building.
#
# This file was created by #{mkconfig} when ruby was built.  It contains
# build information for ruby which is used e.g. by mkmf to build
# compatible native extensions.  Any changes made to this file will be
# lost the next time ruby is built.

module RbConfig
  RUBY_VERSION.start_with?("#{version[/^[0-9]+\.[0-9]+\./] || version}") or
    raise "ruby lib version (#{version}) doesn't match executable version (\#{RUBY_VERSION})"

]
print "  # Ruby installed directory.\n"
print "  TOPDIR = File.dirname(__FILE__).chomp!(#{relative_archdir.dump})\n"
print "  # DESTDIR on make install.\n"
print "  DESTDIR = ", (drive ? "TOPDIR && TOPDIR[/\\A[a-z]:/i] || " : ""), "'' unless defined? DESTDIR\n"
print <<"UNIVERSAL", <<'ARCH' if universal
  universal = #{universal.dump}
UNIVERSAL
  arch_flag = ENV['ARCHFLAGS'] || ((e = ENV['RC_ARCHS']) && e.split.uniq.map {|a| "-arch #{a}"}.join(' '))
  arch = arch_flag && arch_flag[/\A\s*-arch\s+(\S+)\s*\z/, 1]
  cpu = arch && universal[/(?:\A|\s)#{Regexp.quote(arch)}=(\S+)/, 1] || RUBY_PLATFORM[/\A[^-]*/]
ARCH
print "  # The hash configurations stored.\n"
print "  CONFIG = {}\n"
print "  CONFIG[\"DESTDIR\"] = DESTDIR\n"
print "  CONFIG[\"prefix\"] = (TOPDIR || DESTDIR + #{vars.delete('prefix').dump})\n"

fast.each do |n|
  v = vars.delete(n)
  print "  CONFIG[#{n.dump}] = #{(v || "").dump}\n"
end

vars.each do |n, v|
  unless v.include?("\n")
    print "  CONFIG[#{n.dump}] = #{v.dump}\n"
    next
  end
  sep = "="
  v.each_line do |_|
    print "  CONFIG[#{n.dump}] #{sep} #{_.dump}\n"
    sep = :<<
  end
end
print <<EOS if /darwin/ =~ arch
  if sdkroot = ENV["SDKROOT"]
    sdkroot = sdkroot.dup
  elsif File.exist?(File.join(CONFIG["prefix"], "include")) ||
        !(sdkroot = (IO.popen(%w[/usr/bin/xcrun --sdk macosx --show-sdk-path], in: IO::NULL, err: IO::NULL, &:read) rescue nil))
    sdkroot = +""
  else
    sdkroot.chomp!
  end
  CONFIG["SDKROOT"] = sdkroot
EOS
print <<EOS
  CONFIG["platform"] = #{platform || '"$(arch)"'}
  CONFIG["archdir"] = "$(rubyarchdir)"
  CONFIG["topdir"] = File.dirname(__FILE__)

  # Almost same with CONFIG. MAKEFILE_CONFIG has other variable
  # reference like below.
  #
  #   MAKEFILE_CONFIG["bindir"] = "$(exec_prefix)/bin"
  #
  # The values of this constant is used for creating Makefile.
  #
  #   require 'rbconfig'
  #
  #   print <<-END_OF_MAKEFILE
  #   prefix = \#{RbConfig::MAKEFILE_CONFIG['prefix']}
  #   exec_prefix = \#{RbConfig::MAKEFILE_CONFIG['exec_prefix']}
  #   bindir = \#{RbConfig::MAKEFILE_CONFIG['bindir']}
  #   END_OF_MAKEFILE
  #
  #   => prefix = /usr/local
  #      exec_prefix = $(prefix)
  #      bindir = $(exec_prefix)/bin  MAKEFILE_CONFIG = {}
  #
  # RbConfig.expand is used for resolving references like above in rbconfig.
  #
  #   require 'rbconfig'
  #   p RbConfig.expand(RbConfig::MAKEFILE_CONFIG["bindir"])
  #   # => "/usr/local/bin"
  MAKEFILE_CONFIG = {}
  CONFIG.each{|k,v| MAKEFILE_CONFIG[k] = v.dup}

  # call-seq:
  #
  #   RbConfig.expand(val)         -> string
  #   RbConfig.expand(val, config) -> string
  #
  # expands variable with given +val+ value.
  #
  #   RbConfig.expand("$(bindir)") # => /home/foobar/all-ruby/ruby19x/bin
  def RbConfig::expand(val, config = CONFIG)
    newval = val.gsub(/\\$\\$|\\$\\(([^()]+)\\)|\\$\\{([^{}]+)\\}/) {
      var = $&
      if !(v = $1 || $2)
	'$'
      elsif key = config[v = v[/\\A[^:]+(?=(?::(.*?)=(.*))?\\z)/]]
	pat, sub = $1, $2
	config[v] = false
	config[v] = RbConfig::expand(key, config)
	key = key.gsub(/\#{Regexp.quote(pat)}(?=\\s|\\z)/n) {sub} if pat
	key
      else
	var
      end
    }
    val.replace(newval) unless newval == val
    val
  end
  CONFIG.each_value do |val|
    RbConfig::expand(val)
  end

  # call-seq:
  #
  #   RbConfig.fire_update!(key, val)               -> array
  #   RbConfig.fire_update!(key, val, mkconf, conf) -> array
  #
  # updates +key+ in +mkconf+ with +val+, and all values depending on
  # the +key+ in +mkconf+.
  #
  #   RbConfig::MAKEFILE_CONFIG.values_at("CC", "LDSHARED") # => ["gcc", "$(CC) -shared"]
  #   RbConfig::CONFIG.values_at("CC", "LDSHARED")          # => ["gcc", "gcc -shared"]
  #   RbConfig.fire_update!("CC", "gcc-8")                  # => ["CC", "LDSHARED"]
  #   RbConfig::MAKEFILE_CONFIG.values_at("CC", "LDSHARED") # => ["gcc-8", "$(CC) -shared"]
  #   RbConfig::CONFIG.values_at("CC", "LDSHARED")          # => ["gcc-8", "gcc-8 -shared"]
  #
  # returns updated keys list, or +nil+ if nothing changed.
  def RbConfig.fire_update!(key, val, mkconf = MAKEFILE_CONFIG, conf = CONFIG) # :nodoc:
    return if mkconf[key] == val
    mkconf[key] = val
    keys = [key]
    deps = []
    begin
      re = Regexp.new("\\\\$\\\\((?:%1$s)\\\\)|\\\\$\\\\{(?:%1$s)\\\\}" % keys.join('|'))
      deps |= keys
      keys.clear
      mkconf.each {|k,v| keys << k if re =~ v}
    end until keys.empty?
    deps.each {|k| conf[k] = mkconf[k].dup}
    deps.each {|k| expand(conf[k])}
    deps
  end

  # call-seq:
  #
  #   RbConfig.ruby -> path
  #
  # returns the absolute pathname of the ruby command.
  def RbConfig.ruby
    File.join(
      RbConfig::CONFIG["bindir"],
      RbConfig::CONFIG["ruby_install_name"] + RbConfig::CONFIG["EXEEXT"]
    )
  end
end
CROSS_COMPILING = nil unless defined? CROSS_COMPILING
EOS

# vi:set sw=2:
