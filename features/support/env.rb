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

require 'puppet_library'
require 'capybara/cucumber'
require 'capybara/poltergeist'

class ServerWorld
    def server
        @server ||= PuppetLibrary::Server.new(forge)
    end

    def forge
        @forge ||= PuppetLibrary::Forge::Multi.new
    end
end

world = ServerWorld.new
Capybara.app = world.server
Capybara.javascript_driver = :poltergeist

World do
    world
end

