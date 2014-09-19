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

require 'puppet_library/util/patches'

module PuppetLibrary::Forge
    module SearchResult
        def self.merge_by_full_name(results)
            results_by_module = results.group_by do |result|
                result["full_name"]
            end

            final_results = results_by_module.values.map do |module_results|
                combine_search_results(module_results)
            end.flatten

            paginate final_results
        end

        def self.combine_search_results(search_results)
            latest_release, releases = search_results.inject([nil, []]) do |(latest_release, releases), result|
                releases += result["releases"] || []
                max = latest_release && latest_release["version"] || 0
                current = result["current_release"]["version"]
                new_max = max_version(max, current)
                if new_max == max
                    [latest_release, releases]
                else
                    [result["current_release"], releases]
                end
            end

            combined_result = search_results.first.tap do |result|
                result["releases"] = releases.uniq.version_sort_by {|r| r["version"]}.reverse
                result["current_release"] = latest_release
            end
        end

        def self.max_version(left, right)
            [Gem::Version.new(left), Gem::Version.new(right)].max.version
        end

        def self.paginate(results)
            {
                "pagination" => {
                    "limit" => results.length,
                    "offset" => 0,
                    "first" => nil,
                    "previous" => nil,
                    "current" => nil,
                    "next" => nil,
                    "total" => 1
                },
                "results" => results
            }
        end
    end
end
