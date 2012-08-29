require 'dispatcher'

module LdapRegistration
  module AccountControllerPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Mark as unloadable so it is reloaded in development
        
        alias_method_chain :register, :ldap
        alias_method_chain :activate, :ldap

      end
    end

    def activate_with_ldap
      redirect_to(home_url) && return unless Setting.self_registration? && params[:token]
      token = Token.find_by_action_and_value('register', params[:token])
      redirect_to(home_url) && return unless token and !token.expired?
      user = token.user
      redirect_to(home_url) && return unless user.registered?
      user.activate
      user.create_in_ldap
      if user.save
        token.destroy
        flash[:notice] = l(:notice_account_activated)
      end
      redirect_to :action => 'login'
    end

    def register_with_ldap
      redirect_to(home_url) && return unless Setting.self_registration? || session[:auth_source_registration]
      if request.get?
        session[:auth_source_registration] = nil
        @user = User.new(:language => Setting.default_language)
      else
        @user = User.new(params[:user])
        @user.admin = false
        @user.register
        if session[:auth_source_registration]
          @user.activate
          @user.login = session[:auth_source_registration][:login]
          @user.auth_source_id = session[:auth_source_registration][:auth_source_id]
          if @user.save
            session[:auth_source_registration] = nil
            self.logged_user = @user
            flash[:notice] = l(:notice_account_activated)
            redirect_to :controller => 'my', :action => 'account'
          end
        else
          @user.login = params[:user][:login]
          @user.password, @user.password_confirmation = params[:password], params[:password_confirmation]

          case Setting.self_registration
          # NOTICE we add registration via LDAP (4) as a standard registration with email activation after email verification user will added to ldap
          when '1', '4' 
            register_by_email_activation(@user)
          when '3'
            register_automatically(@user)
          else
            register_manually_by_administrator(@user)
          end
        end
      end
    end

    module InstanceMethods
      private
    end
  end
end

Dispatcher.to_prepare do
  require_dependency 'account_controller'
  AccountController.send(:include, LdapRegistration::AccountControllerPatch)
end
