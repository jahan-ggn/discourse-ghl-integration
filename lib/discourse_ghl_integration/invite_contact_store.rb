# frozen_string_literal: true

module DiscourseGhlIntegration
  class InviteContactStore
    PREFIX = "invite_contact"

    class << self
      def contact_id(invite_id)
        PluginStore.get(PLUGIN_NAME, key(invite_id))&.dig("contact_id")
      end

      def save(invite_id:, contact_id:)
        PluginStore.set(PLUGIN_NAME, key(invite_id), { "contact_id" => contact_id })
      end

      private

      def key(invite_id)
        "#{PREFIX}:#{invite_id}"
      end
    end
  end
end
