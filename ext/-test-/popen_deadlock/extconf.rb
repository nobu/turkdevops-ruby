# frozen_string_literal: false
case RUBY_PLATFORM
when /solaris/i, /linux/i
  $LDFLAGS << " -ldl"
  link = true
end
create_makefile("-test-/popen_deadlock/infinite_loop_dlsym") do |mk|
  mk.sub!(/^all: .*/, 'all: Makefile') unless link
  mk
end
