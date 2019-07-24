# frozen_string_literal: true
require_relative '../tool/lib/test-runner'

module Gem
end
class Gem::TestCase < MiniTest::Unit::TestCase
  @@project_dir = File.dirname(__dir__)
end

ENV["GEM_SKIP"] = ENV["GEM_HOME"] = ENV["GEM_PATH"] = "".freeze

exit Test::Unit::AutoRunner.run(true, __dir__)
