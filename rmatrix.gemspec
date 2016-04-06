# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rmatrix/version'

Gem::Specification.new do |spec|
  spec.name          = "rmatrix"
  spec.version       = Rmatrix::VERSION
  spec.authors       = ["Wouter Coppieters"]
  spec.email         = ["wouter.coppieters@youdo.co.nz"]

  spec.summary       = "Fast matrix/linear algebra library for Ruby"
  spec.description   = %Q(RMatrix is a lightning fast library for Ruby. It provides numerous enhancements over the Matrix class in the standard library.
  Features include the ability to calculate Matrix inverse, transpose, determinant, minor, adjoint, cofactor_matrix, hadamard product and other elementwise operations, slicing, masking and more.
  RMatrix makes use of backing instances of NArray to allow for great performance.)
  spec.homepage      = "https://github.com/wouterken/RMatrix"
  spec.license       = "MIT"

  # # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # # delete this section to allow pushing this gem to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
  spec.add_runtime_dependency "narray"
end
