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
        def self.new_from_module_metadata(module_metadata)
            new.initialize_from_module_metadata(module_metadata)
        end

        def self.new_from_source(release_metadata, source_metadata)
            new.initialize_from_source(release_metadata, source_metadata)
        end

        def initialize
            @versions = []
            @releases = []
        end

        def initialize_from_module_metadata(module_metadata)
            @uri = module_metadata["uri"]
            @name = module_metadata["name"]
            @downloads = module_metadata["downloads"]
            @created_at = module_metadata["created_at"]
            @updated_at = module_metadata["updated_at"]
            @supported = module_metadata["supported"]
            @endorsement = module_metadata["endorsement"]
            # TODO: Move owner to separate object
            @owner = module_metadata["owner"]
            @homepage_url = module_metadata["homepage_url"]
            @issues_url = module_metadata["issues_url"]

            if module_metadata["current_release"] and module_metadata["releases"] then
                add_release Release.new_from_release_metadata(module_metadata["current_release"]) 
                module_metadata["releases"].each do |short_metadata|
                    add_release Release.new_from_release_metadata(short_metadata)
                end
            end

            self
        end

        def initialize_from_source(release_metadata, source_metadata)
            full_name = release_metadata["name"]
            author, module_name = full_name.split "-"

            @uri = "/v3/modues/#{full_name}"
            @name = module_name
            @supported = false
            @endorsement = nil
            # TODO: Move owner to separate object
            @owner = {
                "uri" => "/v3/users/#{author}",
                "username" => author,
                "gravatar_id" => nil
            }
            add_release Release.new_from_source(release_metadata, source_metadata)
            @homepage_url = release_metadata["project_home"]
            @issues_url = release_metadata["issues_url"]
            # TODO: Handle dates
            @created_at = nil
            @updated_at = nil

            self
        end

        def merge_with(another_module)
            raise "Invalid module" unless another_module
            raise "Unable to merge #{get_full_name} with #{another_module.get_full_name}" unless equals? another_module
            another_module.get_all_releases.each do |release|
                add_release(release) unless @versions.include? release.get_version 
            end
        end

        def add_release(new_release)
            raise "Invalid release" unless new_release and new_release.get_version
            return if @versions.include? new_release.get_version

            new_release.set_parent_module self
            @releases << new_release
            @versions << new_release.get_version
            if @current_release then
                current_version = @current_release.get_version
                new_version = new_release.get_version
                greater_version = greater_version(current_version, new_version)
                @current_release = new_release if greater_version == new_version
            else
                @current_release = new_release
            end
        end

        def get_short
            {
                "uri" => @uri,
                "name" => @name,
                "owner" => @owner
            }
        end

        def get_long
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

        def get_all_releases
            @releases
        end

        def get_current_release
            @current_release
        end

        def get_release(version)
            @releases.each do |release|
                return release.get_long if release.get_version == version
            end
            raise ReleaseNotFound
        end

        def get_full_name
            "#{@owner["username"]}-#{@name}"
        end

        def newer_than?(another_module)
            get_current_release.is_newer_than? another_module.get_current_release
        end

        def equals?(another_module)
            another_module.get_full_name == get_full_name
        end

        def match?(filter_params)
            # TODO: Handle all possible arguments
            return true unless filter_params["query"]
            get_full_name.include? filter_params["query"]
        end

        def get_matching_releases(filter_params)
            results = []
            @releases.each do |release|
                results.push release if release.match? filter_params
            end
            results
        end

        private
        def greater_version(left, right)
            [Gem::Version.new(left), Gem::Version.new(right)].max.version
        end
    end
end
