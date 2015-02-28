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

require 'open-uri'

module PuppetLibrary::Http

    USER_AGENT = "PuppetLibrary/#{PuppetLibrary::VERSION} (OpenURI)".freeze

    class HttpClient
        def get(url)
            open_uri(url).read
        end

        def download(url)
            open_uri(url)
        end

        private
        def user_agent
            [
	        USER_AGENT,
	        "Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})"
            ].join(' ').freeze
        end

        def open_uri(url)
            open(url, "User-Agent" => user_agent)
        end
    end
end
