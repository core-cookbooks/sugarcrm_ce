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


default['sugarcrm_ce']['db']['hostname'] = 'localhost'
default['sugarcrm_ce']['db']['host_ip'] = 'localhost'
default['sugarcrm_ce']['db']['name'] = 'sugarcrm'
default['sugarcrm_ce']['db']['user'] = 'sugarcrm'
default['sugarcrm_ce']['dir'] = 'sugarcrm'
default['sugarcrm_ce']['admin_pass'] = 'admin'
default['sugarcrm_ce']['site_url'] = "http://sugarcrm_ip/sugarcm"
default['sugarcrm_ce']['download']['url'] = "https://s3.amazonaws.com/core-setup-files/sugarcrm.tar.gz"

default['sugarcrm_ce']['webroot'] = "#{node['apache2']['docroot_dir']}/#{node['sugarcrm_ce']['dir']}"

::Chef::Node.send(:include, Opscode::OpenSSL::Password)

default['sugarcrm_ce']['db']['password'] = secure_password
