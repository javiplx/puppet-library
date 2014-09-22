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

            results_by_module.values.map do |module_results|
                combine_search_results(module_results)
            end.flatten
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

        def self.remove_duplicates(results)
            # TODO: Improve this method
            return [] unless results

            results_by_module = results.group_by do |result|
                result.get_full_name
            end

            unique_results = []
            results_by_module.each do |full_name, result_group|
                unique_results << result_group.first
            end

            unique_results
        end

        def self.merge_duplicate_modules(results)
            return [] unless results

            groups_by_name = results.group_by do |result|
                result.get_full_name
            end

            merged_results = []
            groups_by_name.each do |name, result_group|
                if result_group.length == 1
                    merged_results << result_group.first
                else
                    base = result_group.first
                    duplicates = result_group.last(result_group.length - 1)
                    duplicates.each do |duplicate|
                        base.merge_with duplicate
                    end
                    merged_results << base
                end
            end

            merged_results
        end
    end
end
