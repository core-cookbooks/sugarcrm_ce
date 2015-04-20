#
# Cookbook Name:: sugarcrm_ce
# Author::nagalakshmi.n@cloudenablers.com
# Recipe:: default
#
# Copyright 2015, Cloudenablers
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

include_recipe "apache2"
include_recipe "apache2::mod_php5"
include_recipe %w{php::default php::module_mysql}
node.set['sugarcrm_ce']['username'] = 'admin'
node.set['sugarcrm_ce']['password'] = 'admin'
db = node['sugarcrm_ce']['db']
full_access_folders = [ "cache", "custom", "modules", "data"]

if node['sugarcrm_ce']['db']['host_ip'] == 'localhost' || node['sugarcrm_ce']['db']['host_ip'] == "127.0.0.1"
  include_recipe "mysql::server"
else
  include_recipe "mysql::client"
end

mysql_bin = (platform_family? 'windows') ? 'mysql.exe' : 'mysql'
user = "'#{db['user']}'"
host = db['host_ip']
create_user = %<CREATE USER #{user}@'localhost' IDENTIFIED BY '#{db['password']}';>
user_exists = %<SELECT 1 FROM mysql.user WHERE user = '#{db['user']}';>
create_db = %<CREATE DATABASE #{db['name']};>
db_exists = %<SHOW DATABASES LIKE '#{db['name']}';>
grant_privileges = %<GRANT ALL PRIVILEGES ON #{db['name']}.* TO #{user}@'%' identified by '#{db['password']}';>
privileges_exist = %<SHOW GRANTS FOR #{user}@'%';>
flush_privileges = %<FLUSH PRIVILEGES;>

execute "Create SugarCRM MySQL User" do
  action :run
  command "#{mysql_bin} #{::Sugarcrm::Helpers.make_db_query("root", node['mysql']['server_root_password'], host, create_user)}"
  only_if { `#{mysql_bin} #{::Sugarcrm::Helpers.make_db_query("root", node['mysql']['server_root_password'], host, user_exists)}`.empty? }
end

execute "Grant SugarCRM MySQL Privileges" do
  action :run
  command "#{mysql_bin} #{::Sugarcrm::Helpers.make_db_query("root", node['mysql']['server_root_password'], host, grant_privileges)}"
  only_if { `#{mysql_bin} #{::Sugarcrm::Helpers.make_db_query("root", node['mysql']['server_root_password'], host, privileges_exist)}`.empty? }
  notifies :run, "execute[Flush MySQL Privileges]"
end

execute "Flush MySQL Privileges" do
  action :nothing
  command "#{mysql_bin} #{::Sugarcrm::Helpers.make_db_query("root", node['mysql']['server_root_password'], host, flush_privileges)}"
end

execute "Create SugarCRM Database" do
  action :run
  command "#{mysql_bin} #{::Sugarcrm::Helpers.make_db_query("root", node['mysql']['server_root_password'], host, create_db)}"
  only_if { `#{mysql_bin} #{::Sugarcrm::Helpers.make_db_query("root", node['mysql']['server_root_password'], host, db_exists)}`.empty? }
end

directory node['sugarcrm_ce']['webroot'] do
  user node['apache2']['user']
  group node['apache2']['group']
  recursive true
  action :create
end


remote_file "#{Chef::Config[:file_cache_path]}/sugarcrm_ce.tar.gz" do
  source node['sugarcrm_ce']['download']['url']
  user node['apache2']['user']
  group node['apache2']['group']
end

bash 'extract_module' do
  cwd ::File.dirname(Chef::Config[:file_cache_path])
  code <<-EOH
    tar xzf #{Chef::Config[:file_cache_path]}/sugarcrm_ce.tar.gz -C #{node['sugarcrm_ce']['webroot']}
    EOH
end

cookbook_file "#{node['sugarcrm_ce']['webroot']}/sugarcrm.sql" do
  source "sugarcrm.sql"
  owner "root"
  group "root"
  mode 00600
  action :create_if_missing
end

execute "Create SugarCRM DB Schema" do
  action :run
  command "#{mysql_bin} -u root -p#{node['mysql']['server_root_password']} -h #{node['sugarcrm_ce']['db']['host_ip']} #{node['sugarcrm_ce']['db']['name']} < #{node['sugarcrm_ce']['webroot']}/sugarcrm.sql"
end

if node['sugarcrm_ce']['db']['host_ip'] != 'localhost' || node['sugarcrm_ce']['db']['host_ip'] != "127.0.0.1"
  hostsfile_entry db['host_ip'] do
    hostname db['hostname']
    comment 'Updated by Chef'
    action :create_if_missing
  end
end

template "config_si.php" do
  source "config_si.php.erb"
  path "#{node['sugarcrm_ce']['webroot']}/config_si.php"
  owner node['apache2']['user']
  group node['apache2']['group']
  mode 0755
end

template "#{node['sugarcrm_ce']['webroot']}/config.php" do
  source "config.php.erb"
  owner "root"
  group "root"
  mode 0755
end

execute "Sugarcrm Folder Access update" do
  command "chmod -R 755 #{node['sugarcrm_ce']['webroot']}"
end

full_access_folders.each do |folder|
  execute "Folder Access update" do
    user "root"
    command "chmod -R 777 #{node['sugarcrm_ce']['webroot']}/#{folder}"
  end
end

cron "sugarcron" do
  minute "*/2"
  command "/usr/bin/php -f #{node['sugarcrm_ce']['webroot']}/cron.php >> /dev/null"
  user "root"
end
