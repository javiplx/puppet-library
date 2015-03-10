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
require 'puppet_library/http/http_client'
require 'puppet_library/http/cache/in_memory'
require 'puppet_library/http/cache/noop'
require 'puppet_library/util/config_api'

module PuppetLibrary::Forge

    # A forge that proxies a remote forge.
    #
    # <b>Usage:</b>
    #
    #    forge = PuppetLibrary::Forge::Proxy.configure do
    #        # The URL of the remote forge
    #        url "http://forge.example.com"
    #    end
    class Proxy < Forge

        def self.configure(&block)
            config_api = PuppetLibrary::Util::ConfigApi.for(Proxy) do
                required :url, "URL"
            end
            config = config_api.configure(&block)
            Proxy.new(config.get_url)
        end

        # * <tt>:url</tt> - The URL of the remote forge.
        def initialize(url, query_cache = PuppetLibrary::Http::Cache::InMemory.new, download_cache = PuppetLibrary::Http::Cache::NoOp.new, http_client = PuppetLibrary::Http::HttpClient.new)
            @url = PuppetLibrary::Http::Url.normalize(url)
            @http_client = http_client
            @query_cache = query_cache
            @download_cache = download_cache
        end

        def clear_cache
            @query_cache.clear
            @download_cache.clear
        end

        def search_modules(query)
            query_parameter = query.nil? ? "" : "?q=#{query}" # .sub("-","/")}"
            results = get("/modules.json#{query_parameter}")
            JSON.parse results
        end

        def get_module_buffer(author, name, version)
            begin
                version_info = get_module_version(author, name, version)
                raise ModuleNotFound if version_info.nil?
                download_module(author, name, version, version_info["file"])
            rescue OpenURI::HTTPError
                raise ModuleNotFound
            end
        end

        def get_module_metadata(author, name)
            begin
                # librarian-puppet does some special handling for forgeapi.puppetlabs.com,
                # so naive passthrough will fail
                response = get_modules("#{author}-#{name}")
                raise ModuleNotFound if response.empty?
                to_info(response[0])
            rescue OpenURI::HTTPError
                raise ModuleNotFound
            end
        end

        def get_modules(query)
            query_parameter = query.nil? ? "" : "?query=#{query}"
            results = get("/v3/modules#{query_parameter}")
            JSON.parse(results)['results']
        end

        def get_releases(module_name)
            response = get("/v3/releases?module=#{module_name}")
            JSON.parse(response)['results']
        end

        def get_module_v3(module_name, version)
            begin
                author , name = module_name.split '-'
                response = JSON.parse get("/v3/releases/#{author}-#{name}-#{version}")
                download_module(author, name, version, response['file_uri'])
            rescue OpenURI::HTTPError
                raise ModuleNotFound
            end
        end

        def get_module_metadata_with_dependencies(author, name, version)
            begin
                look_up_releases(author, name, version) do |full_name, release_info|
                    release_info["file"] = module_path_for(full_name, release_info["version"])
                end
            rescue OpenURI::HTTPError
                raise ModuleNotFound
            end
        end

        private
        def to_info(metadata_v3)
            {
                "author" => metadata_v3["owner"]["username"],
                "full_name" => metadata_v3["current_release"]["metadata"]["name"].sub("-", "/"),
                "name" => metadata_v3["name"],
                "summary" => metadata_v3["current_release"]["metadata"]["summary"],
                "releases" => metadata_v3["releases"].collect{ |r| { "version" => r["version"] } }
            }
        end

        def to_version(metadata_v3)
            {
                "file" => "/modules/#{metadata_v3['metadata']['name']}-#{metadata_v3['version']}.tar.gz",
                "version" =>  metadata_v3["version"],
                "dependencies" =>  metadata_v3["metadata"]["dependencies"].map do |dependency|
                    [ dependency["name"], dependency["version_requirement"] ]
                end
            }
        end

        def get_module_version(author, name, version)
            module_versions = get_module_versions(author, name)
            module_versions.find do |version_info|
                version_info["version"] == version
            end
        end

        def get_module_versions(author, name)
            versions = look_up_releases(author, name)
            versions["#{author}/#{name}"]
        end

        def look_up_releases(author, name, version = nil, &optional_processor)
            version_query = version ? "&version=#{version}" : ""
            url = "/api/v1/releases.json?module=#{author}/#{name}#{version_query}"
            response_text = get(url)
            response = JSON.parse(response_text)
            process_releases_response(response, &optional_processor)
        end

        def process_releases_response(response)
            if block_given?
                response.each do |full_name, release_infos|
                    release_infos.each do |release_info|
                        yield(full_name, release_info)
                    end
                end
            end
            return response
        end

        def module_path_for(full_name, version)
            "/modules/#{full_name.sub("/", "-")}-#{version}.tar.gz"
        end

        def download_module(author, name, version, file)
            @download_cache.get("#{author}-#{name}-#{version}.tar.gz") do
                @http_client.download(url(file))
            end
        end

        def get(relative_url)
            @query_cache.get(relative_url) do
                @http_client.get(url(relative_url))
            end
        end

        def url(relative_url)
            @url + relative_url
        end
    end
end

