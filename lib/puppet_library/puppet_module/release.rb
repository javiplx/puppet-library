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
    class Release
        def self.new_from_release_metadata(release_metadata)
            new.initialize_from_release_metadata(release_metadata)
        end

        def self.new_from_source(release_metadata, source_metadata)
            new.initialize_from_source(release_metadata, source_metadata)
        end

        def initialize_from_release_metadata(release_metadata)
            @uri = release_metadata["uri"]
            @version = release_metadata["version"]
            @metadata = release_metadata["metadata"]
            @tags = release_metadata["tags"]
            @supported = release_metadata["supported"]
            @file_uri = release_metadata["file_uri"]
            @file_size = release_metadata["file_size"]
            @file_md5 = release_metadata["file_md5"]
            @downloads = release_metadata["downloads"]
            @readme = release_metadata["readme"]
            @changelog = release_metadata["changelog"]
            @licence = release_metadata["licence"]
            @created_at = release_metadata["created_at"]
            @deleted_at = release_metadata["deleted_at"]

            if release_metadata["module"] then
                @module = Module.new_from_module_metadata(release_metadata["module"])
            end

            self
        end

        def initialize_from_source(release_metadata, source_metadata)
            full_name = release_metadata["name"]
            version = release_metadata["version"]

            @uri = "/v3/releases/#{full_name}-#{version}"
            @version = version
            @metadata = release_metadata
            @tags = []
            @supported = false
            @file_uri = "/v3/files/#{full_name}-#{version}.tar.gz"
            @file_size = source_metadata["file-size"]
            @file_md5 = source_metadata["file-md5"]
            @downloads = 0
            @readme = source_metadata["readme"]
            @changelog = source_metadata["changelog"]
            @licence = release_metadata["licence"]
            @created_at = nil
            @updated_at = nil
            @deleted_at = nil

            self
        end

        def set_parent_module(parent_module)
            @module = parent_module
        end

        def get_short
            {
                "uri" => @uri,
                "version" => @version,
                "supported" => @supported
            }
        end

        def get_long
            {
                "uri" => @uri,
                "module" => @module.get_short,
                "version" => @version,
                "metadata" => @metadata,
                "tags" => @tags,
                "supported" => @supported,
                "file_uri" => @file_uri,
                "file_size" => @file_size,
                "file_md5" => @file_md5,
                "downloads" => @downloads,
                "readme" => @readme,
                "changelog" => @changelog,
                "licence" => @licence,
                "created_at" => @created_at,
                "updated_at" => @updated_at,
                "deleted_at" => @deleted_at
            }
        end

        def get_version
            @version
        end

        def get_module
            @module
        end

        def get_full_name
            "#{@module.get_full_name}-#{get_version}"
        end

        def newer_than?(another_release)
            raise "Unable to compare releases of different modules" unless has_same_parent_as? another_release
            greater_version = [Gem::Version.new(another_relase.get_version), Gem::Version.new(get_version)].max.version
            get_version == greater_version
        end

        def equals?(another_release)
            has_same_parent_as? another_release and get_version == another_relase.get_version
        end

        def match?(filter_params)
            # TODO: Handle all possible arguments
            return true unless filter_params["module"]
            return true if filter_params["module"] == "#{@module.get_full_name}-#{@version}"
            return true if filter_params["module"] == @module.get_full_name
            return false
        end

        private
        def has_same_parent_as?(another_release)
            another_release.get_module.equals? get_module
        end
    end
end
