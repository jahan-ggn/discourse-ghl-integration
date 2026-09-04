# frozen_string_literal: true

module ::DiscourseGhlIntegration
  class UserLinker
    GHL_CONTACT_ID_FIELD = "ghl_contact_id"

    class << self
      def find_or_link(contact_id:, email:)
        return if contact_id.blank?

        user = find_by_contact_id(contact_id)

        return user if user.present?
        return if email.blank?

        user = User.find_by_email(email)
        return if user.blank?

        save_contact_id(user, contact_id)

        user
      end

      private

      def find_by_contact_id(contact_id)
        UserCustomField
          .where(name: GHL_CONTACT_ID_FIELD, value: contact_id)
          .includes(:user)
          .first
          &.user
      end

      def save_contact_id(user, contact_id)
        return if user.custom_fields[GHL_CONTACT_ID_FIELD] == contact_id

        user.custom_fields[GHL_CONTACT_ID_FIELD] = contact_id
        user.save_custom_fields
      end
    end
  end
end
