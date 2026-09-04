# frozen_string_literal: true
module ::DiscourseGhlIntegration
  class WebhooksController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token

    def create
      payload = request.request_parameters

      case payload["type"]
      when "INSTALL"
        handle_install(payload)
      when "ContactTagUpdate"
        handle_contact_tag_update(payload)
      end

      head :ok
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

    def handle_contact_tag_update(payload)
      location_id = payload["locationId"]

      raise ContactTagSync::Error, "GoHighLevel Location ID is missing" if location_id.blank?

      unless location_id == OauthStore.location_id
        raise ContactTagSync::Error, "GoHighLevel Location ID does not match installed location"
      end

      ContactTagSync.sync(payload)
    end
  end
end
