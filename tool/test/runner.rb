# frozen_string_literal: true
require_relative '../lib/test-runner'
exit Test::Unit::AutoRunner.run(true, __dir__)
