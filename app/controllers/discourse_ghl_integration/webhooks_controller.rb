# frozen_string_literal: true

module ::DiscourseGhlIntegration
  class WebhooksController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token

    def create
      payload = request.request_parameters

      handle_install(payload) if payload["type"] == "INSTALL"

      head :ok
    rescue Oauth::Error => e
      Rails.logger.warn(
        "[#{PLUGIN_NAME}] GoHighLevel webhook failed: #{e.message}",
      )

      head :unprocessable_entity
    end

    private

    def handle_install(payload)
      company_id = payload["companyId"]
      location_id = payload["locationId"]

      return if company_id.blank? || location_id.blank?

      OauthStore.save_pending_install(
        {
          "company_id" => company_id,
          "location_id" => location_id,
        },
      )

      Oauth.complete_pending_connection!
    end
  end
end