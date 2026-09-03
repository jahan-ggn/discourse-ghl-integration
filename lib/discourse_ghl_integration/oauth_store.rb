# frozen_string_literal: true

module ::DiscourseGhlIntegration
  class OauthStore
    CREDENTIALS_KEY = "oauth_credentials"
    PENDING_COMPANY_KEY = "pending_company_oauth"
    PENDING_INSTALL_KEY = "pending_install"

    class << self
      def credentials
        PluginStore.get(PLUGIN_NAME, CREDENTIALS_KEY)
      end

      def save(credentials)
        PluginStore.set(PLUGIN_NAME, CREDENTIALS_KEY, credentials)
      end

      def clear
        PluginStore.remove(PLUGIN_NAME, CREDENTIALS_KEY)
      end

      def pending_company
        PluginStore.get(PLUGIN_NAME, PENDING_COMPANY_KEY)
      end

      def save_pending_company(credentials)
        PluginStore.set(PLUGIN_NAME, PENDING_COMPANY_KEY, credentials)
      end

      def clear_pending_company
        PluginStore.remove(PLUGIN_NAME, PENDING_COMPANY_KEY)
      end

      def pending_install
        PluginStore.get(PLUGIN_NAME, PENDING_INSTALL_KEY)
      end

      def save_pending_install(installation)
        PluginStore.set(PLUGIN_NAME, PENDING_INSTALL_KEY, installation)
      end

      def clear_pending_install
        PluginStore.remove(PLUGIN_NAME, PENDING_INSTALL_KEY)
      end
    end
  end
end
