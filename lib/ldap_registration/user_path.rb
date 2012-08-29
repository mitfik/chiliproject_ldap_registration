require_dependency 'principal'

module LdapRegistration
  module UserPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Mark as unloadable so it is reloaded in development
        validate :validate_user_in_ldap, :on => :create

      end
    end

    module InstanceMethods
      def create_in_ldap
        begin
          ldap = Net::LDAP.new :host => Setting.plugin_ldap_registration["ldap_host"],
                               :port => Setting.plugin_ldap_registration["ldap_port"],
                               :auth => {
                                  :method => :simple,
                                  :username => Setting.plugin_ldap_registration["ldap_bind_dn"],
                                  :password => Setting.plugin_ldap_registration["ldap_pass"]
                                }
          user = { :cn => self.firstname, :sn => self.lastname, :userPassword => Net::LDAP::Password.generate(:sha, self.password),
                   :objectClass => ["inetOrgPerson", "simpleSecurityObject"] }
          treebase = "uid=#{self.login},".concat(Setting.plugin_ldap_registration["ldap_treebase"])
          ldap.open do |ldap|
            ldap.add(:dn => treebase, :attributes => user)
          end
        rescue
          errors.add_to_base("Internal server error, please inform administration")
        end
      end
      private 

        def validate_user_in_ldap
          debugger
          ldap = Net::LDAP.new :host => Setting.plugin_ldap_registration["ldap_host"],
                               :port => Setting.plugin_ldap_registration["ldap_port"],
                               :auth => {
                                  :method => :simple,
                                  :username => Setting.plugin_ldap_registration["ldap_bind_dn"],
                                  :password => Setting.plugin_ldap_registration["ldap_pass"]
                                }
          filter = Net::LDAP::Filter.eq(Setting.plugin_ldap_registration["ldap_filter"],self.login)
          treebase = Setting.plugin_ldap_registration["ldap_treebase"]
          result = ldap.search(:base => treebase, :filter => filter)
          unless result.empty?
            errors.add(:login, "has already been taken") unless errors.on(:login)
          end
        end
  

    end
  end
end

User.send(:include, LdapRegistration::UserPatch)
