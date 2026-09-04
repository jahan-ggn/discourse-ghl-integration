# frozen_string_literal: true

module ::DiscourseGhlIntegration
  class ContactTagSync
    class Error < StandardError
    end

    class << self
      def sync(payload)
        raise Error, "Webhook payload is missing" if payload.blank?

        contact_id = payload["id"]
        email = payload["email"]
        tags = payload["tags"]

        raise Error, "GoHighLevel contact ID is missing" if contact_id.blank?

        user = UserLinker.find_or_link(contact_id: contact_id, email: email)

        if user.blank?
          InviteSync.sync(email: email, tags: tags)

          return nil
        end

        GroupSync.sync(user: user, tags: tags)

        user
      end
    end
  end
end
