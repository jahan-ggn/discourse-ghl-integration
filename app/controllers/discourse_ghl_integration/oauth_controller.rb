# frozen_string_literal: true

module ::DiscourseGhlIntegration
  class OauthController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr

    def callback
      if params[:error].present?
        raise Oauth::Error, "GoHighLevel authorization failed: #{params[:error]}"
      end

      code = params[:code]

      raise Oauth::Error, "Missing GoHighLevel authorization code" if code.blank?

      redirect_uri = "#{request.base_url}/crm/oauth/callback"

      token = Oauth.exchange_code(code: code, redirect_uri: redirect_uri)

      case token["userType"]
      when "Location"
        Oauth.save_location_token(token)
        OauthStore.clear_pending_company
        OauthStore.clear_pending_install
      when "Company"
        Oauth.save_pending_company_token(token)
        Oauth.complete_pending_connection!
      else
        raise Oauth::Error,
              "Unexpected GoHighLevel token type: #{token["userType"].presence || "unknown"}"
      end

      redirect_to "https://app.gohighlevel.com/", allow_other_host: true
    rescue Oauth::Error => e
      Rails.logger.warn("[#{PLUGIN_NAME}] OAuth callback failed: #{e.message}")

      render(json: { success: false, error: e.message }, status: :unprocessable_entity)
    end
  end
end
