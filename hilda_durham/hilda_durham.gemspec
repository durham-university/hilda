$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "hilda_durham/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "hilda_durham"
  s.version     = HildaDurham::VERSION
  s.authors     = ["Olli Lyytinen"]
  s.email       = ["olli.lyytinen@durham.ac.uk"]
  s.homepage    = "https://source.dur.ac.uk/university-library/HILDA"
  s.summary     = "Durham University Library specific modules for HILDA"
  s.description = "Durham University Library specific modules for HILDA"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails"
  s.add_dependency "hilda"
  s.add_dependency "schmit_api", '~> 0.1.0'
  s.add_dependency "oubliette_api"
  s.add_dependency "trifle_api"

  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'factory_girl_rails'
  s.add_development_dependency 'database_cleaner'

end
