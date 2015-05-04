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

require 'sinatra/base'
require 'haml'
require 'docile'

require 'puppet_library/forge/multi'
require 'puppet_library/util/patches'

module PuppetLibrary
    # The Puppet Library server
    #
    # A Rack application that can be configured as follows:
    #
    #    server = PuppetLibrary::Server.configure
    #        # Look for my modules locally
    #        forge :directory do
    #            path "/var/lib/modules"
    #        end
    #
    #        # Get everything else from the Puppet Forge
    #        forge :proxy do
    #            url "https://forgeapi.puppetlabs.com"
    #        end
    #    end
    #
    #    run server
    class Server < Sinatra::Base
        class Config
            def initialize(forge)
                @forge = forge
            end

            def forge(forge, &block)
                if forge.is_a? Symbol
                    class_name = forge.to_s.snake_case_to_camel_case
                    forge_type = Forge.module_eval(class_name)
                    @forge.add_forge forge_type.configure(&block)
                else
                    @forge.add_forge forge
                end
            end
        end

        def self.configure(&block)
            forge = Forge::Multi.new
            Docile.dsl_eval(Config.new(forge), &block)
            Server.new(forge)
        end

        def initialize(forge)
            super(nil)
            @forge = forge
            @forge.prime
        end

        configure do
            enable :logging
            set :haml, :format => :html5
            set :root, File.expand_path("app", File.dirname(__FILE__))
        end

        get "/v3/modules" do
            search_term = params[:query]
            @forge.get_modules(search_term).to_json
        end

        get "/v3/releases" do
            unless params[:module]
                halt 400, {"error" => "Supply the module whose releases will be retrived"}.to_json
            end
            @forge.get_releases(params[:module]).to_json
        end

        get "/v3/files/:modname.tar.gz" do
            parts = params[:modname].split('-',3)
            module_name = "#{parts[0]}-#{parts[1]}"
            version = parts[2]

            content_type "application/octet-stream"

            begin
                buffer = @forge.get_module_v3(module_name, version).tap do
                    attachment "#{module_name}-#{version}.tar.gz"
                end
                download buffer
            rescue Forge::ModuleNotFound
                halt 404
            end
        end

        get "/" do
            query = params[:search]
            haml :index, { :locals => { "query" => query } }
        end

        get "/modules.json" do
            search_term = params[:q]
            @forge.search_modules(search_term).sort_by do |mod|
                mod["author"]
            end.to_json
        end

        get "/:author/:module.json" do
            author = params[:author]
            module_name = params[:module]

            begin
                @forge.get_module_metadata(author, module_name).to_json
            rescue Forge::ModuleNotFound
                halt 410, {"error" => "Could not find module \"#{module_name}\""}.to_json
            end
        end

        get "/api/v1/releases.json" do
            unless params[:module]
                halt 400, {"error" => "The number of version constraints in the query does not match the number of module names"}.to_json
            end

            author, module_name = params[:module].split "/"
            version = params[:version]
            begin
                @forge.get_module_metadata_with_dependencies(author, module_name, version).to_json
            rescue Forge::ModuleNotFound
                halt 410, {"error" => "Module #{author}-#{module_name} not found"}.to_json
            end
        end

        # This is an exact copy of /v3/files/
        get "/modules/:modname.tar.gz" do
            parts = params[:modname].split('-',3)
            module_name = "#{parts[0]}-#{parts[1]}"
            version = parts[2]

            content_type "application/octet-stream"

            begin
                buffer = @forge.get_module_v3(module_name, version).tap do
                    attachment "#{module_name}-#{version}.tar.gz"
                end
                download buffer
            rescue Forge::ModuleNotFound
                halt 404
            end
        end

        get "/:author-:module" do
            author = params[:author]
            module_name = params[:module]

            begin
                metadata = @forge.get_module_metadata(author, module_name)
                haml :module, { :locals => { "metadata" => metadata } }
            rescue Forge::ModuleNotFound
                halt 404, haml(:module_not_found, { :locals => { "author" => author, "name" => module_name } })
            end
        end

        get "/:author/:module/pack" do
            author = params[:author]
            module_name = params[:module]

            begin
                this = @forge.get_module_metadata(author, module_name)
                this.update( this["releases"].last )
                all_results = @forge.get_module_metadata_with_dependencies(author, module_name, this["version"])
                deplist = all_results[this["full_name"]].first["dependencies"].inject({}){ |h,i| h.update( i.first => i.last ) }
                deplist[this["full_name"]] = this["version"]
                all_results.reject!{ |k| k == this["full_name"] }
                metadata = all_results.inject({}) do |h,(k,v)|
                    s = v.sort{ |x,y| x["version"] <=> y["version"] }
                    item = s.find{ |i| i["version"] == deplist[k] }
                    h.update( k => item || s.last )
                end
                haml :pack, { :locals => { "this" => this, "metadata" => metadata } }
            rescue Forge::ModuleNotFound
                halt 404, haml(:module_not_found, { :locals => { "author" => author, "name" => module_name } })
            end
        end

        get "/:author/:module/download" do
            author = params[:author]
            module_name = params[:module]

            tempdir = Dir.mktmpdir
            begin
                this = @forge.get_module_metadata(author, module_name)
                this.update( this["releases"].last )
                all_results = @forge.get_module_metadata_with_dependencies(author, module_name, this["version"])
                deplist = all_results[this["full_name"]].first["dependencies"].inject({}){ |h,i| h.update( i.first => i.last ) }

                all_results.each do |k,v|
                    s = v.sort{ |x,y| x["version"] <=> y["version"] }
                    item = s.find{ |i| i["version"] == deplist[k] } || s.last
                    parts = item["file"].split('-',3)
                    parts[0].slice! "/modules/"
                    parts[2].slice! ".tar.gz"
                    FileUtils.cp @forge.get_module_buffer(*parts), tempdir
                end

                require 'puppet_library/archive/archiver'
                buffer = Archive::Archiver.archive_dir(tempdir, ".").tap do
                    attachment "pack-#{author}-#{module_name}-#{this["version"]}.tar.gz"
                end

                content_type "application/x-tar"
                download buffer

            rescue Forge::ModuleNotFound
                halt 404, haml(:module_not_found, { :locals => { "author" => author, "name" => module_name } })
            ensure
                FileUtils.rm_rf tempdir
            end
        end

        post "/api/forge/clear-cache" do
            @forge.clear_cache
        end

        put "/upload" do
            unless dest_forge = @forge.locals.first
                halt 501, {"error" => "No local forge to store uploaded module"}.to_json
            end
            file = Tempfile.new("puppetmodule")
            file.write(request.body.read)
            file.close

            tar = Gem::Package::TarReader.new(Zlib::GzipReader.open(file.path))
            entry = tar.find {|e| e.full_name =~ %r(.*/metadata.json$) }
            halt 400, {"error" => "Module metadata not present on upload"}.to_json if entry.nil?
            metadata = Forge::ModuleMetadata.new( JSON.parse(entry.read) )

            begin
                @forge.get_module_metadata(metadata.author, metadata.name).first{ |m| m.version == metadata.version }.nil?
                halt 409, {"error" => "Module already present on library"}.to_json
            rescue Forge::ModuleNotFound
                FileUtils.cp( file.path , dest_forge.path( metadata ) )
            end
        end

        private
        def download(buffer)
            if buffer.respond_to?(:size)
                headers = { "Content-Length" => buffer.size.to_s }
            else
                headers = {}
            end
            [ 200, headers, buffer ]
        end
    end
end
