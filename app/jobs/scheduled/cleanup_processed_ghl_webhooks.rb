# frozen_string_literal: true

module Jobs
  class CleanupProcessedGhlWebhooks < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      return unless SiteSetting.discourse_ghl_integration_enabled

      DiscourseGhlIntegration::WebhookStore.cleanup_expired!
    end
  end
end
