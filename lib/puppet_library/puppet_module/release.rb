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
        def initialize(parent_module, release_metadata, source_metadata)
            full_name = release_metadata["name"]
            version = release_metadata["version"]
 
            @uri = "/v3/releases/#{full_name}-#{version}"
            @module = parent_module
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
        end

        def get_short()
            {
                "uri" => @uri,
                "version" => @version,
                "supported" => @supported
            }
        end

        def get_long()
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

        def get_version()
            @version
        end

        def match?(filter_params)
            # TODO: Handle all possible arguments
            return true unless filter_params["module"]
            return true if filter_params["module"] == "#{@module.get_full_name}-#{@version}"
            return true if filter_params["module"] == @module.get_full_name
            return false
        end
    end
end
