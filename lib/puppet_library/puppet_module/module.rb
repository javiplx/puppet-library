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

module PuppetLibrary::PuppetModule
    class Module
        def initialize(release_metadata, source_metadata)
            full_name = release_metadata["name"]
            author, module_name = full_name.split "-"

            @uri = "/v3/modues/#{full_name}"
            @name = module_name
            @supported = false
            @endorsement = nil
            @owner = {
                "uri" => "/v3/users/#{author}",
                "username" => author,
                "gravatar_id" => nil
            }
            @releases = [Release.new(self, release_metadata, source_metadata)]
            @current_release = @releases.first
            @homepage_url = release_metadata["project_home"]
            @issues_url = release_metadata["issues_url"]
            # TODO: Handle dates
            @created_at = nil
            @updated_at = nil
        end

        def add_release(release_metadata, source_metadata)
            new_release = Release.new(self, release_metadata, source_metadata)
            @releases.push new_release
            current_version = @current_release.get_version
            new_version = new_release.get_version
            greater_version = max_version(current_version, new_version)
            @current_release = new_release if greater_version == new_version
        end

        def get_short()
            {
                "uri" => @uri,
                "name" => @name,
                "owner" => @owner
            }
        end

        def get_long()
            short_releases = []
            @releases.each do |release|
                short_releases.push release.get_short
            end
            {
                "uri" => @uri,
                "name" => @name,
                "downloads" => @downloads,
                "created_at" => @created_at,
                "updated_at" => @updated_at,
                "supported" => @supported,
                "endorsement" => @endorsement,
                "owner" => @owner,
                "current_release" => @current_release.get_long,
                "releases" => short_releases,
                "homepage_url" => @homepage_url,
                "issues_url" => @issues_url
            }
        end

        def get_all_releases()
            results = []
            @releases.each do |release|
                results.push release.get_long
            end
            results
        end

        def get_release(version)
            @releases.each do |release|
                return release.get_long if release.get_version == version
            end
            raise ReleaseNotFound
        end

        def get_full_name()
            return "#{@owner["username"]}-#{@name}"
        end

        def match?(filter_params)
            # TODO: Handle all possible arguments
            return true unless filter_params["query"]
            get_full_name.include? filter_params["query"]
        end

        def get_matching_releases(filter_params)
            results = []
            @releases.each do |release|
                results.push release.get_long if release.match? filter_params
            end
            results
        end

        private
        def max_version(left, right)
            [Gem::Version.new(left), Gem::Version.new(right)].max.version
        end
    end
end
