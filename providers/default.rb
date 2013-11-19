#
# Cookbook Name:: homeshick
# Provider:: default
#
# Copyright 2013, Thomas Boerger
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef/dsl/include_recipe"
include Chef::DSL::IncludeRecipe

action :create do
  new_resource.keys.each do |name, key|
    repo = key.split("/").last

    execute "homeshick_clone_#{new_resource.username}_homeshick" do
      command "git clone git://github.com/andsens/homeshick.git #{homesick_directory_for("homeshick")}"
      action :nothing

      user new_resource.username
      group new_resource.group || new_resource.username

      environment(
        "HOME" => home_directory
      )

      not_if do
        homesick_directory_for("homeshick").directory?
      end
    end.run_action(:run)

    execute "homeshick_clone_#{new_resource.username}_#{repo}" do
      command "source #{homesick_directory_for("homeshick").join("homeshick.sh")} && homeshick -f clone #{key}"
      action :run

      user new_resource.username
      group new_resource.group || new_resource.username

      environment(
        "HOME" => home_directory
      )

      not_if do
        homesick_directory_for(key).directory?
      end

      notifies :run, "execute[homesick_link_#{new_resource.username}_#{repo}]", :immediately
    end

    execute "homeshick_refresh_#{new_resource.username}_#{repo}" do
      command "source #{homesick_directory_for("homeshick").join("homeshick.sh")} && homeshick -f refresh 7 #{repo}"
      action :run

      user new_resource.username
      group new_resource.group || new_resource.username

      environment(
        "HOME" => home_directory
      )

      only_if do
        homesick_directory_for(key).directory?
      end

      notifies :run, "execute[homesick_link_#{new_resource.username}_#{repo}]", :immediately
    end

    execute "homeshick_link_#{new_resource.username}_#{repo}" do
      command "source #{homesick_directory_for("homeshick").join("homeshick.sh")} && homeshick -f link #{repo}"
      action :nothing

      user new_resource.username
      group new_resource.group || new_resource.username

      environment(
        "HOME" => home_directory
      )

      only_if do
        homesick_directory_for(key).directory?
      end
    end
  end

  new_resource.updated_by_last_action(true)
end

action :delete do
  new_resource.keys.each do |name, key|
    repo = key.split("/").last

    # TODO: unlink outdated files
    
    directory homesick_directory_for(key) do
      action :delete
    end

    # TODO: check if repos is empty

  end

  new_resource.updated_by_last_action(true)
end

def homesick_directory_for(key)
  home_directory.join(".homesick", "repos", key.split("/").last)
end

protected

def home_directory
  @homedirectory ||= begin
    value = if new_resource.home
      new_resource.home
    else
      if new_resource.username == "root"
        "/root"
      else
        "/home/#{new_resource.username}"
      end
    end

    ::Pathname.new value
  end
end
