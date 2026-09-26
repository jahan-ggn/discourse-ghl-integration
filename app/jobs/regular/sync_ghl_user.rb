# frozen_string_literal: true

module Jobs
  class SyncGhlUser < ::Jobs::Base
    sidekiq_options retry: 5

    def execute(args)
      return unless SiteSetting.discourse_ghl_integration_enabled

      user = User.find_by(id: args[:user_id])
      return if user.blank?

      DiscourseGhlIntegration::ContactSync.sync_user(user)
    end
  end
end
