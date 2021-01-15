# gem "core-testlib", git: "https://github.com/ruby/ruby/tool"

Gem::Specification.new do |spec|
  spec.name          = "core-testlib"
  spec.version       = "0.0.0"
  spec.authors       = ["Ruby"]

  spec.summary       = %q{Core test libraries}
  spec.description   = spec.summary + %q{ for gemified standard libraries.}
  spec.homepage      = "https://github.com/ruby/ruby"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")
  spec.licenses      = ["Ruby", "BSD-2-Clause"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files         = %w[
    tool/lib/core_assertions.rb
    tool/lib/envutil.rb
    tool/lib/find_executable.rb
    tool/lib/helper.rb
  ]
  spec.require_paths = ["tool/lib"]
end
