# frozen_string_literal: true
$INCFLAGS << " -I$(topdir) -I$(top_srcdir)"
$VPATH << '$(topdir)' << '$(top_srcdir)' # for id.h.
have_func("malloc_stats_print")
create_makefile('objspace')
