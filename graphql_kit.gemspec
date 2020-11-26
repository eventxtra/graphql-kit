require_relative 'lib/graphql_kit/version'

Gem::Specification.new do |spec|
  spec.name          = "graphql_kit"
  spec.version       = GraphqlKit::VERSION
  spec.authors       = ["Kenneth Law (Author)", "Jimmy Law (Publisher)"]
  spec.email         = ["kennethlaw@eventxtra.com", "jimmy@eventxtra.com"]

  spec.summary       = %q{Graphql Kit for extending and modifying Ruby Graphql functionality}
  spec.homepage      = "https://github.com/eventxtra/graphql-kit.git"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/eventxtra/graphql-kit.git"
  spec.metadata["changelog_uri"] = "https://github.com/eventxtra/graphql-kit.git"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", "~> 6.0.0"
  spec.add_dependency "base58"
  spec.add_dependency "graphql", "~> 1.8"
  spec.add_dependency "graphql-batch", "~> 0.4.3"
  spec.add_dependency "memoizer"
  spec.add_dependency "priority_queue_cxx"
end
