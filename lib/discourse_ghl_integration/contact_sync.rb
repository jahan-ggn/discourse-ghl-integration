# frozen_string_literal: true

module ::DiscourseGhlIntegration
  class ContactSync
    GHL_CONTACT_ID_FIELD = "ghl_contact_id"

    class Error < StandardError
    end

    class << self
      def sync_user(user)
        raise Error, "Discourse user is missing" if user.blank?

        email = user.email

        raise Error, "Discourse user email is missing" if email.blank?

        tag = SiteSetting.ghl_community_member_tag

        if tag.blank?
          raise Error, "GoHighLevel community member tag is not configured"
        end

        contact = find_or_create_contact(user)

        save_contact_id(user, contact.fetch("id"))

        Client.add_tags(
          contact_id: contact.fetch("id"),
          tags: [tag],
        )

        contact
      rescue Client::Error => e
        raise Error, e.message
      end

      private

      def find_or_create_contact(user)
        contact_id = user.custom_fields[GHL_CONTACT_ID_FIELD]

        if contact_id.present?
          begin
            return Client.get_contact(contact_id)
          rescue Client::Error => e
            raise unless e.contact_not_found?

            clear_contact_id(user)
          end
        end

        contacts = Client.lookup_contact_by_email(user.email)

        return contacts.first if contacts.present?

        first_name, last_name = split_name(user.name)

        Client.create_contact(
          email: user.email,
          first_name: first_name,
          last_name: last_name,
        )
      end

      def save_contact_id(user, contact_id)
        return if user.custom_fields[GHL_CONTACT_ID_FIELD] == contact_id

        user.custom_fields[GHL_CONTACT_ID_FIELD] = contact_id
        user.save_custom_fields
      end

      def clear_contact_id(user)
        user.custom_fields.delete(GHL_CONTACT_ID_FIELD)
        user.save_custom_fields
      end

      def split_name(name)
        return [nil, nil] if name.blank?

        parts = name.strip.split(/\s+/, 2)

        [parts.first, parts.second]
      end
    end
  end
end