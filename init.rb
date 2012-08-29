require 'redmine'

Dir["#{File.dirname(__FILE__)}/lib/ldap_registration/**/*.rb"].sort.each do |lib|
 require lib
end

Redmine::Plugin.register :ldap_registration do
  name 'ChiliProject Ldap Registration plugin'
  author 'Robert Mitwicki'
  description 'Allow to register user direct in ldap'
  version '0.0.1'
  url 'http://github.com/mitfik/ldap_registration'
  author_url 'http://github.com/mitfik'

  

  settings :default => { :ldap_bind_dn => nil,
                         :ldap_host => nil,
                         :ldap_pass => nil,
                         :ldap_port => nil,
                         :ldap_treebase => nil,
                         :ldap_filter => nil
                       }, 
           :partial => "shared/ldap_registration_settings"

end
