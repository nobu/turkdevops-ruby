# This file includes the settings for "make test-all".
# Note that this file is loaded not only by test/runner.rb but also by tool/lib/test/unit/parallel.rb.

ENV["GEM_SKIP"] = ENV["GEM_HOME"] = ENV["GEM_PATH"] = "".freeze
tmpdir = ENV["TMPDIR"]
if tmpdir
  tmpdir = File.realpath(tmpdir) # TMPDIR must be an existing path.
  tmpdir = nil if tmpdir.size > 50
end
tmpdir ||= gemtmpdir = (require 'tmpdir'; Dir.mktmpdir("gemtest.", "/tmp"))
ENV["GEM_TEST_TMPDIR"] = tmpdir
warn "GEM_TEST_TMPDIR: #{tmpdir.inspect}"
if gemtmpdir
  pid = $$
  at_exit do
    Dir.rmdir(gemtmpdir) if pid == $$
  rescue SystemCallError
  end
end

ENV.delete("RUBY_CODESIGN")

Warning[:experimental] = false

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require 'test/unit'

require "profile_test_all" if ENV.key?('RUBY_TEST_ALL_PROFILE')
require "tracepointchecker"
require "zombie_hunter"
require "iseq_loader_checker"
require "gc_checker"
require_relative "../test-coverage.rb" if ENV.key?('COVERAGE')
