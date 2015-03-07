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

require 'puppet_library/archive/archiver'
require 'puppet_library/forge/abstract'
require 'puppet_library/puppet_module/modulefile'
require 'json'

module PuppetLibrary::Forge

    # A forge that serves a module from its source on disk.
    # Metadata (+metadata.json+) is generated on the fly.
    #
    # <b>Note:</b>
    # The module directory must have either a +metadata.json+ or a +Modulefile+.
    # If it contains both, +metadata.json+ will be used.
    #
    # <b>Usage:</b>
    #
    #    forge = PuppetLibrary::Forge::Source.configure do
    #        # The path of the module's source
    #        path "/var/modules/mymodulesource"
    #    end
    class Source < Abstract
        def self.configure(&block)
            config_api = PuppetLibrary::Util::ConfigApi.for(Source) do
                required :path, "path to the module's source" do |path|
                    Dir.new(File.expand_path(path))
                end
            end
            config = config_api.configure(&block)
            Source.new(config.get_path)
        end

        CACHE_TTL_MILLIS = 500

        # * <tt>:module_dir</tt> - The directory containing the module's source.
        def initialize(module_dir)
            raise "Module directory '#{module_dir.path}' doesn't exist" unless File.directory? module_dir.path
            raise "Module directory '#{module_dir.path}' isn't readable" unless File.executable? module_dir.path
            @module_dir = module_dir
            @metadata_cache = PuppetLibrary::Http::Cache::InMemory.new(CACHE_TTL_MILLIS)
            super()
        end

        def get_module_buffer(author, name, version)
            raise ModuleNotFound unless this_module?(author, name, version)
            PuppetLibrary::Archive::Archiver.archive_dir(@module_dir.path, "#{author}-#{name}-#{version}") do |archive|
                archive.add_file("metadata.json", 0644) do |entry|
                    entry.write load_metadata.to_json
                end
            end
        end

        private
        def this_module?(author, module_name, version = nil)
            metadata = load_metadata
            same_module = metadata["name"] == "#{author}-#{module_name}"
            if version.nil?
                return same_module
            else
                return same_module && metadata["version"] == version
            end
        end

        def load_metadata
            @metadata_cache.get "metadata" do
                metadata_file_path = File.join(@module_dir.path, "metadata.json")
                modulefile_path = File.join(@module_dir.path, "Modulefile")
                if File.exist?(metadata_file_path) && ! File.exist?(modulefile_path)
                    JSON.parse(File.read(metadata_file_path))
                else
                    modulefile = PuppetLibrary::PuppetModule::Modulefile.read(modulefile_path)
                    modulefile.to_metadata
                end
            end
        end

        def load_modules
            clear_modules!
            add_module PuppetLibrary::PuppetModule::Module.new_from_source(load_metadata, {})
        end
    end
end

