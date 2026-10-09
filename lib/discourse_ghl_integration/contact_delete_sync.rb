# frozen_string_literal: true

module DiscourseGhlIntegration
  class ContactDeleteSync
    class Error < StandardError
    end

    class << self
      def sync(payload)
        contact_id = payload&.dig("id")
        location_id = payload&.dig("locationId")

        raise Error, "GoHighLevel contact ID is missing" if contact_id.blank?
        raise Error, "GoHighLevel Location ID is missing" if location_id.blank?

        DistributedMutex.synchronize(
          "ghl_contact_sync_#{location_id}_#{contact_id}",
          validity: 2.minutes,
        ) do
          field =
            UserCustomField
              .where(name: ContactSync::GHL_CONTACT_ID_FIELD, value: contact_id)
              .includes(:user)
              .first

          if (user = field&.user)
            GroupSync.sync(user: user, tags: [])
            field.destroy!
          end

          email = payload["email"]

          if email.present?
            managed_group_ids =
              TagGroupMapping.all.values.flatten.uniq.filter_map do |name|
                Group.find_by(name: name)&.id
              end

            Invite
              .where(email: email)
              .find_each do |invite|
                next unless invite.redeemable?
                next unless InviteContactStore.contact_id(invite.id) == contact_id

                invite.invited_groups.where(group_id: managed_group_ids).destroy_all
              end
          end

          user
        end
      end
    end
  end
end
