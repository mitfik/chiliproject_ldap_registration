require_dependency 'principal'

module LdapRegistration
  module UserPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Mark as unloadable so it is reloaded in development
        validate_on_create :validate_user_in_ldap

        alias_method_chain :activate, :ldap
        after_create :create_in_ldap

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
                   :objectClass => ["inetOrgPerson", "simpleSecurityObject"], :st => "disabled" }
          treebase = "uid=#{self.login},".concat(Setting.plugin_ldap_registration["ldap_treebase"])
          ldap.open do |ldap|
            ldap.add(:dn => treebase, :attributes => user)
          end
        rescue
          #TODO log it >?
          errors.add_to_base("Internal server error, please inform administration")
        end
      end

      def activate_with_ldap
        ldap = Net::LDAP.new :host => Setting.plugin_ldap_registration["ldap_host"],
                             :port => Setting.plugin_ldap_registration["ldap_port"],
                             :auth => {
                                :method => :simple,
                                :username => Setting.plugin_ldap_registration["ldap_bind_dn"],
                                :password => Setting.plugin_ldap_registration["ldap_pass"]
                              }
        result = ldap.replace_attribute "uid=#{login},".concat( Setting.plugin_ldap_registration["ldap_treebase"]), :st, "active"
        unless result
          errors.add(:status, "change fail")
        else
          activate_without_ldap
        end
      end

      private 

        def validate_user_in_ldap
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
