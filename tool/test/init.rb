# This file includes the settings for "make test-all".
# Note that this file is loaded not only by test/runner.rb but also by tool/lib/test/unit/parallel.rb.

ENV["GEM_SKIP"] = "".freeze
ENV.delete("RUBY_CODESIGN")

Warning[:experimental] = false

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

gem_path = [
  File.realdirpath(".bundle"),
  File.realdirpath("../.bundle", __dir__),
]
ENV["GEM_PATH"] = gem_path.join(File::PATH_SEPARATOR)
ENV["GEM_HOME"] = gem_path.first

require 'test/unit'

require "profile_test_all" if ENV.key?('RUBY_TEST_ALL_PROFILE')
require "tracepointchecker"
require "zombie_hunter"
require "iseq_loader_checker"
require "gc_checker"
require_relative "../test-coverage.rb" if ENV.key?('COVERAGE')
