lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "soracom_summary/version"

Gem::Specification.new do |spec|
  spec.name          = "soracom_summary"
  spec.version       = SoracomSummary::VERSION
  spec.authors       = ["1stship"]
  spec.email         = ["1peifunyaq@gmail.com"]

  spec.summary       = 'tool to create SORACOM usage summary'
  spec.description   = 'Scraping SORACOM usage via SORACOM API and uploading these data to SORACOM Harvest'
  spec.homepage      = 'https://github.com/1stship/soracom-summary/'
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'ruby-debug-ide'
  spec.add_development_dependency 'debase'
end
