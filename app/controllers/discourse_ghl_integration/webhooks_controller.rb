# frozen_string_literal: true

module DiscourseGhlIntegration
  class WebhooksController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token

    def create
      raw_payload = request.raw_post
      signature = request.headers["X-GHL-Signature"]

      WebhookVerifier.verify!(payload: raw_payload, signature: signature)

      payload = JSON.parse(raw_payload)

      case payload["type"]
      when "INSTALL"
        handle_install(payload)
      when "ContactTagUpdate", "ContactDelete"
        Jobs.enqueue(:process_ghl_webhook, payload: payload)
      end

      head :ok
    rescue WebhookVerifier::Error => e
      Rails.logger.warn("[#{PLUGIN_NAME}] GoHighLevel webhook rejected: #{e.message}")

      head :unauthorized
    rescue JSON::ParserError
      Rails.logger.warn("[#{PLUGIN_NAME}] GoHighLevel webhook contained invalid JSON")

      head :bad_request
    rescue Oauth::Error, ContactTagSync::Error => e
      Rails.logger.warn("[#{PLUGIN_NAME}] GoHighLevel webhook failed: #{e.message}")

      head :unprocessable_entity
    end

    private

    def handle_install(payload)
      company_id = payload["companyId"]
      location_id = payload["locationId"]

      return if company_id.blank? || location_id.blank?

      OauthStore.save_pending_install({ "company_id" => company_id, "location_id" => location_id })

      Oauth.complete_pending_connection!
    end
  end
end
