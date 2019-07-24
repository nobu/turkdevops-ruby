# frozen_string_literal: true
require 'rbconfig'

$LOAD_PATH.unshift __dir__

require 'test/unit'

require_relative "profile_test_all" if ENV.key?('RUBY_TEST_ALL_PROFILE')
require_relative "tracepointchecker"
require_relative "zombie_hunter"
require_relative "iseq_loader_checker"
require_relative "../test-coverage.rb" if ENV.key?('COVERAGE')
