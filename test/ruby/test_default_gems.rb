# frozen_string_literal: false
require 'rubygems'

class TestDefaultGems < Test::Unit::TestCase
  def self.load(file)
    code = File.read(file, encoding: Encoding::UTF_8)
    code.sub!(/`git .*?`/, '""')
    eval code, binding, file
  end

  def test_validate_gemspec
    specs = 0
    Dir.chdir(File.expand_path('../../..', __FILE__)) do
      unless system("git", "rev-parse", %i[out err]=>IO::NULL)
        omit "git not found"
      end
      Dir.glob("{lib,ext}/**/*.gemspec").map do |file|
        specs += 1
        assert_kind_of(Gem::Specification, self.class.load(file))
      end
    end
    assert_operator specs, :>, 0, "gemspecs not found"
  end

end
