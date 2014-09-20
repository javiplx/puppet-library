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
require 'addressable/uri'

module PuppetLibrary::Forge

    # A forge that proxies a remote forge.
    #
    # <b>Usage:</b>
    #
    #    forge = PuppetLibrary::Forge::Proxy.configure do
    #        # The URL of the remote forge
    #        url "http://forge.example.com"
    #    end
    class Proxy < Abstract

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

        def search_modules(params)
            query_params = construct_url params
            url = "/v3/modules?#{query_params}"
            get_all_pages url
        end

        def search_releases(params)
            query_params = construct_url params
            url = "/v3/releases?#{query_params}"
            get_all_pages url
        end

        def get_module_metadata(author, name)
            url = "/v3/modules/#{author}-#{name}"
            JSON.parse(get url)
        end

        def get_release_metadata(author, name, version)
            url = "/v3/releases/#{author}-#{name}-#{version}"
            JSON.parse(get url)
        end

        def get_module_buffer(author, name, version)
            begin
                #version_info = get_module_version(author, name, version)
                #raise ModuleNotFound if version_info.nil?
                #download_module(author, name, version, version_info["file"])
                # TODO: Return cache
                download_module(author, name, version, module_path_for(author, name, version))
            rescue OpenURI::HTTPError
                raise ModuleNotFound
            end
        end

        def construct_url(params)
            uri = ::Addressable::URI.new
            uri.query_values = params
            uri.query
        end

        private
        def module_path_for(author, module_name, version)
            "/v3/files/#{author}-#{module_name}-#{version}.tar.gz"
        end

        def download_module(author, name, version)
            @download_cache.get("#{author}-#{name}-#{version}.tar.gz") do
                @http_client.download(url(module_path_for(author, name, version)))
            end
        end

        def get(relative_url)
            @query_cache.get(relative_url) do
                @http_client.get(url(relative_url))
            end
        end

        def get_all_pages(url)
            results = []
            loop do
              response = JSON.parse(get url)
              results += response["results"]
              url = response["pagination"]["next"]
              print "Got #{response["results"].length} results. Next: #{url}\n"
              break if url.nil?
            end
            results
        end

        def url(relative_url)
            @url + relative_url
        end
    end
end

