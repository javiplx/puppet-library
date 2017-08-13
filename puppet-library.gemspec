# -*- encoding: utf-8 -*-
# Puppet Library
# Copyright (C) 2014 drrb
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'puppet_library/version'

Gem::Specification.new do |spec|
  spec.name          = "puppet-library"
  spec.version       = PuppetLibrary::VERSION
  spec.authors       = ["drrb"]
  spec.email         = ["drrrrrrrrrrrb@gmail.com"]
  spec.description   = "A private Puppet forge"
  spec.summary       = <<-EOF
    Puppet Library is a private Puppet module server that's compatible with librarian-puppet.
  EOF
  spec.homepage      = "https://github.com/drrb/puppet-library"
  spec.license       = "GPL-3"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "sinatra", "~> 1.4"
  spec.add_dependency "json"
  spec.add_dependency "haml", "~> 4.0"
  spec.add_dependency "docile", ">= 1.0.0"
  spec.add_dependency "open4"
  spec.add_dependency "redcarpet", "~> 2.1.1"
  spec.add_dependency "tilt", "2.0.7"

end
