# frozen_string_literal: true

module Jobs
  class ProcessGhlWebhook < ::Jobs::Base
    def execute(args)
      payload = args[:payload]

      return if payload.blank?

      webhook_id = payload["webhookId"]

      if webhook_id.blank?
        Rails.logger.warn(
          "[#{DiscourseGhlIntegration::PLUGIN_NAME}] " \
            "Skipping GHL webhook with missing webhook ID",
        )

        return
      end

      if DiscourseGhlIntegration::WebhookStore.processed?(webhook_id)
        Rails.logger.info(
          "[#{DiscourseGhlIntegration::PLUGIN_NAME}] " \
            "Skipping already processed GHL webhook #{webhook_id}",
        )

        return
      end

      case payload["type"]
      when "ContactDelete"
        return unless valid_location?(payload)

        DiscourseGhlIntegration::ContactDeleteSync.sync(payload)
      when "ContactTagUpdate"
        return unless valid_location?(payload)

        DiscourseGhlIntegration::ContactTagSync.sync(payload)
      else
        Rails.logger.info(
          "[#{DiscourseGhlIntegration::PLUGIN_NAME}] " \
            "Ignoring unsupported GHL webhook type #{payload["type"]}",
        )

        return
      end

      DiscourseGhlIntegration::WebhookStore.mark_processed(webhook_id)
      Rails.logger.info(
        "[#{DiscourseGhlIntegration::PLUGIN_NAME}] " \
          "Processed GHL webhook #{webhook_id} (#{payload["type"]})",
      )
    end

    private

    def valid_location?(payload)
      location_id = payload["locationId"]

      if location_id.blank?
        Rails.logger.warn(
          "[#{DiscourseGhlIntegration::PLUGIN_NAME}] " \
            "Skipping GHL webhook with missing Location ID",
        )

        return false
      end

      unless location_id == DiscourseGhlIntegration::OauthStore.location_id
        Rails.logger.warn(
          "[#{DiscourseGhlIntegration::PLUGIN_NAME}] " \
            "Skipping GHL webhook for an unexpected Location ID",
        )

        return false
      end

      true
    end
  end
end
