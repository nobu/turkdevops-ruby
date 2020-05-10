# frozen_string_literal: false
if $mswin||$mingw||$cygwin||$msys
  create_makefile('win32')
end
