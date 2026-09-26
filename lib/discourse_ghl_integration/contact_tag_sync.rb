# frozen_string_literal: true

module DiscourseGhlIntegration
  class ContactTagSync
    class Error < StandardError
    end

    class << self
      def sync(payload)
        raise Error, "Webhook payload is missing" if payload.blank?

        contact_id = payload["id"]
        location_id = payload["locationId"]

        raise Error, "GoHighLevel contact ID is missing" if contact_id.blank?
        raise Error, "GoHighLevel Location ID is missing" if location_id.blank?

        DistributedMutex.synchronize(
          "ghl_contact_sync_#{location_id}_#{contact_id}",
          validity: 2.minutes,
        ) do
          contact = Client.get_contact(contact_id)
          tags = contact["tags"]

          raise Error, "GoHighLevel contact tags are missing" unless tags.is_a?(Array)

          email = contact["email"].presence || payload["email"]
          user = UserLinker.find_or_link(contact_id: contact_id, email: email)

          if user.blank?
            InviteSync.sync(email: email, tags: tags)
            nil
          else
            GroupSync.sync(user: user, tags: tags)
            user
          end
        end
      rescue Client::Error, InviteSync::Error => e
        raise Error, e.message
      end
    end
  end
end
