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

require 'puppet_library/forge/forge'
require 'puppet_library/forge/search_result'
require 'puppet_library/util/dependency'
require 'puppet_library/util/patches'

module PuppetLibrary::Forge

    # An abstract forge implementation that makes it easier to create new forge
    # types.
    #
    # See PuppetLibrary::Forge::Directory for an example
    class Abstract < Forge
        def initialize
            @modules = []
            load_modules
        end

        def search_modules(params)
            results = []
            @modules.each do |current_module|
                results.push current_module if current_module.match?(params)
            end
            results
        end

        def search_releases(params)
            results = []
            @modules.each do |current_module|
                results += current_module.get_matching_releases(params)
            end
            results
        end

        def get_module_metadata(author, module_name)
            @modules.each do |current_module|
                if current_module.get_full_name == "#{author}-#{module_name}"
                    return current_module
                end
            end
            raise ModuleNotFound
        end

        def get_release_metadata(author, module_name, version)
            @modules.each do |current_module|
                if current_module.get_full_name == "#{author}-#{module_name}"
                    begin
                        return current_module.get_release(version)
                    rescue PuppetLibrary::PuppetModule::ReleaseNotFound
                        raise ModuleNotFound
                    end
                end
            end
            raise ModuleNotFound
        end

        def get_module_buffer(author, module_name, version)
            raise NotImplementedError
        end

        private
        def clear_modules!
            @modules.clear
        end

        def add_module(new_module)
            @modules.each do |current_module|
                if current_module.equals? new_module
                    current_module.merge_with new_module
                    return
                end
            end
            @modules.push new_module
        end

        def load_modules
        end
    end
end
