lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'rmre/version'

Gem::Specification.new do |s|
  s.name        = "rmre"
  s.version     = Rmre::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bosko Ivanisevic"]
  s.email       = ["bosko.ivanisevic@gmail.com"]
  s.homepage    = "http://github.com/bosko/rmre"
  s.summary     = %q{The easiest way to create ActiveRecord models for legacy database}
  s.description = %q{Rmre creates ActiveRecord models for legacy database with all constraints found.}

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "rmre"

  s.add_dependency "activerecord", ">= 3.0.0"
  s.add_dependency "erubis"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"

  s.files              = `git ls-files`.split("\n")
  s.test_files         = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables        = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths      = ["lib"]

  s.extra_rdoc_files   = ["README.rdoc", "LICENSE.txt"]
  s.rdoc_options << '--title' << 'Rmre -- Rails Models Reverse Engineering' <<
                       '--main' << 'README.rdoc'
end
