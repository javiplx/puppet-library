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
require 'puppet_library/util/patches'
require 'ostruct'

module PuppetLibrary::Forge

    # A forge that delegates to multiple other forges.
    #
    # For queries, all subforges are queried. The results are merged, giving
    # preference to earlier ones. That is, if the same version of a module is
    # found in two different subforges, the one contained in the earlier
    # subforge is kept in the query results.
    #
    # For downloads, subforges are queried sequentially. The first module found
    # is returned.
    #
    # <b>Usage:</b>
    #
    #     # A forge that serves modules from disk, and proxies a remote forge
    #     multi_forge = Multi.new
    #     multi_forge.add_forge(Directory.new("/var/modules"))
    #     multi_forge.add_forge(Proxy.new("http://forge.puppetlabs.com"))
    class Multi < Forge
        def initialize
            @forges = []
        end

        def prime
            @forges.each_in_parallel &:prime
        end

        def clear_cache
            @forges.each_in_parallel &:clear_cache
        end

        # Add another forge to delegate to.
        def add_forge(forge)
            @forges << forge
        end

        def search_modules(params)
            all_results = @forges.inject([]) do |results, forge|
                results += forge.search_modules(params)
            end

            #paginate SearchResult.merge_by_full_name(all_results)
            # TODO: Remove duplicates
            paginate all_results
        end

        def search_releases(params)
            all_results = @forges.inject([]) do |all, forge|
                begin
                    all += forge.search_releases(params)
                rescue ModuleNotFound
                    # Try the next one
                rescue NotImplementedError
                    # TODO: Remove this when method is implemented in all forge types
                end
            end

            # TODO: Remove duplicates
            paginate all_results
        end

        def get_module_metadata(author, name)
            metadata_list = @forges.inject([]) do |metadata_list, forge|
                begin
                    metadata_list << forge.get_module_metadata(author, name)
                rescue ModuleNotFound
                    metadata_list
                end
            end
            raise ModuleNotFound if metadata_list.empty?
            metadata_list.deep_merge.tap do |metadata|
                metadata["releases"] = metadata["releases"].unique_by { |release| release["version"] }
            end
        end

        def get_release_metadata(author, name, version)
            @forges.each do |forge|
                begin
                    return forge.get_release_metadata(author, name, version)
                rescue ModuleNotFound
                    # Try the next one
                rescue NotImplementedError
                    # TODO: Remove this when method is implemented in all forge types
                end
            end
            raise ModuleNotFound
        end

        def get_module_buffer(author, name, version)
            @forges.each do |forge|
                begin
                    return forge.get_module_buffer(author, name, version)
                rescue ModuleNotFound
                    # Try the next one
                rescue NotImplementedError
                    # TODO: Remove this when method is implemented in all forge types
                end
            end
            raise ModuleNotFound
        end

        def paginate(results)
            {
                "pagination" => {
                    "limit" => results.length,
                    "offset" => 0,
                    "first" => nil,
                    "previous" => nil,
                    "current" => nil,
                    "next" => nil,
                    "total" => results.length
                },
                "results" => results
            }
        end
    end
end
