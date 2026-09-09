# frozen_string_literal: true

module DiscourseGhlIntegration
  class WebhookStore
    PREFIX = "processed_webhook"
    RETENTION_PERIOD = 30.days

    class << self
      def processed?(webhook_id)
        return false if webhook_id.blank?

        PluginStore.get(PLUGIN_NAME, key(webhook_id)).present?
      end

      def mark_processed(webhook_id)
        return if webhook_id.blank?

        PluginStore.set(PLUGIN_NAME, key(webhook_id), { "processed_at" => Time.zone.now.iso8601 })
      end

      def cleanup_expired!
        cutoff = RETENTION_PERIOD.ago

        PluginStoreRow
          .where(plugin_name: PLUGIN_NAME)
          .where("key LIKE ?", "#{PREFIX}:%")
          .find_each do |row|
            value = JSON.parse(row.value)
            processed_at = Time.zone.parse(value["processed_at"].to_s)

            row.delete if processed_at.present? && processed_at < cutoff
          rescue JSON::ParserError, ArgumentError
            Rails.logger.warn(
              "[#{PLUGIN_NAME}] Unable to parse processed GHL webhook record #{row.key}",
            )
          end
      end

      private

      def key(webhook_id)
        "#{PREFIX}:#{webhook_id}"
      end
    end
  end
end
