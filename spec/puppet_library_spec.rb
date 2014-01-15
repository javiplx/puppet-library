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

require 'spec_helper'

module PuppetLibrary
    describe PuppetLibrary do
        let(:module_repo) do
            module_repo = double(ModuleRepo::Multi)
            allow(ModuleRepo::Multi).to receive(:new).and_return(module_repo)
            return module_repo
        end
        let(:forge) do
            forge = double(Forge)
            allow(Forge).to receive(:new).and_return(forge)
            return forge
        end
        let(:server) do
            server = double(Server)
            allow(Server).to receive(:new).with(forge).and_return(server)
            return server
        end
        let(:log) { double('log').as_null_object }
        let(:library) { PuppetLibrary.new(log) }
        let(:default_options) {{ :app => server, :Host => "0.0.0.0", :Port => "9292", :server => nil }}
        before do
            allow(Rack::Server).to receive(:start)
        end

        def default_options_with(substitutions)
            default_options.clone.tap do |options|
                substitutions.each do |k, v|
                    options[k] = v
                end
            end
        end

        describe "#go" do
            context "when using a bad option" do
                it "prints the usage" do
                    expect(log).to receive(:puts).with(/invalid option: --die\nUsage:/)

                    library.go(["--die"])
                end
            end

            context "when using no options" do
                it "runs the server with the default options" do
                    expect(Rack::Server).to receive(:start).with(default_options)

                    library.go([])
                end
            end

            context "when using --port option" do
                it "runs the server with the specified port" do
                    expect(Rack::Server).to receive(:start).with(default_options_with(:Port => "8080"))

                    library.go(["--port", "8080"])
                end
            end

            context "when using --server option" do
                it "runs the app on the specified server" do
                    expect(Rack::Server).to receive(:start).with(default_options_with(:server => "thin"))

                    library.go(["--server", "thin"])
                end
            end

            context "when using --bind-host option" do
                it "runs the server with the specified bind host" do
                    expect(Rack::Server).to receive(:start).with(default_options_with(:Host => "localhost"))

                    library.go(["--bind-host", "localhost"])
                end
            end

            context "when using --proxy option" do
                it "adds a proxy module repository for each option specified" do
                    proxy1 = double('proxy1')
                    proxy2 = double('proxy2')
                    expect(ModuleRepo::Proxy).to receive(:new).with("http://forge1.example.com").and_return(proxy1)
                    expect(ModuleRepo::Proxy).to receive(:new).with("http://forge2.example.com").and_return(proxy2)
                    expect(Forge).to receive(:new).with(module_repo).and_return(forge)
                    expect(module_repo).to receive(:add_repo).twice
                    expect(Rack::Server).to receive(:start).with(default_options)

                    library.go(["--proxy", "http://forge1.example.com", "--proxy", "http://forge2.example.com"])
                end
            end

            it "adds a module repository to the server for each module directory" do
                expect(Forge).to receive(:new).with(module_repo).and_return(forge)
                expect(module_repo).to receive(:add_repo).twice
                expect(Rack::Server).to receive(:start).with(default_options)

                library.go(["--module-dir", "dir1", "--module-dir", "dir2"])
            end

            it "logs the server options" do
                expect(log).to receive(:puts).with(/Port: 9292/)
                expect(log).to receive(:puts).with(/Host: 0\.0\.0\.0/)
                expect(log).to receive(:puts).with(/Server: default/)
                expect(log).to receive(:puts).with(/Repositories:/)
                expect(log).to receive(:puts).with(/- PuppetLibrary::ModuleRepo::Directory: \.\/modules/)
                library.go([])
            end
        end
    end
end
