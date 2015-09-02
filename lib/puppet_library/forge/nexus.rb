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

require 'json'
require 'puppet_library/forge/abstract'
require 'puppet_library/archive/archive_reader'
require 'puppet_library/util/config_api'

module PuppetLibrary::Forge

    # A forge that serves modules from a Nexus storage directory.
    #
    # <b>Note:</b>
    # * The modules must be packaged in +.tar.gz+ format
    # * The module metadata.json file must be uploaded to nexus as well in +.json" format
    # * The modules must be named in the format <tt>author-modulename-version.tar.gz</tt>
    # * The modules must contain a +metadata.json+ file
    # That is, the format must be the same as what is produced by <tt>puppet module build</tt>
    #
    # <b>Usage:</b>
    #
    #    forge = PuppetLibrary::Forge::Nexus.configure do
    #        # The path to serve the modules from
    #        path "/var/nexus/storage/snapshots/puppet-module"
    #    end
    class Nexus < PuppetLibrary::Forge::Abstract

        def self.configure(&block)
            config_api = PuppetLibrary::Util::ConfigApi.for(Nexus) do
                required :path, "path to a Nexus storage directory to serve modules from" do |dir|
                    Dir.new(File.expand_path(dir)).tap do |dir|
                        raise "Module directory '#{dir}' isn't readable" unless File.executable? dir
                    end
                end
            end
            config = config_api.configure(&block)
            Nexus.new(config.get_path)
        end

        # * <tt>:nexus_dir</tt> - The directory containing the packaged modules.
        def initialize(nexus_dir)
            super(self)
            @nexus_dir = nexus_dir
        end

        def get_module(author, name, version)
            file_name = "#{author}-#{name}-*.tar.gz"
            modules = Dir["#{@nexus_dir.path}/#{author}-#{name}/#{version}/#{file_name}"].sort_by{ |f| File.ctime(f) }.last(1)
            path = modules[0]
            if File.exist? path
                File.open(path, 'r')
            else
                nil
            end
        end

        def get_all_metadata
            get_metadata("*", "*")
        end

        def get_metadata(author, module_name)
            archives = Dir["#{@nexus_dir.path}/**/#{author}-#{module_name}-*.json"]
            result = archives.map {|path| read_metadata(path) }
            result.compact
        end

        private
        def read_metadata(metadata_file)
            #archive = PuppetLibrary::Archive::ArchiveReader.new(archive_path)
            #metadata_file = archive.read_entry %r[[^/]+/metadata\.json$]
            JSON.parse(open(metadata_file).read)
        rescue => error
            warn "Error reading from module archive #{metadata_file}: #{error}"
            return nil
        end
    end
end
