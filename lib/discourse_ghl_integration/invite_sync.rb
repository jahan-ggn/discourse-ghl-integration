# frozen_string_literal: true

module ::DiscourseGhlIntegration
  class InviteSync
    class Error < StandardError
    end

    class << self
      def sync(email:, tags:)
        raise Error, "GoHighLevel contact email is missing" if email.blank?

        desired_group_ids = mapped_group_ids(tags)
        invited_by = User.find(Discourse::SYSTEM_USER_ID)

        invite =
          Invite
            .where(email: email, invited_by_id: invited_by.id)
            .order(created_at: :desc)
            .detect(&:redeemable?)

        invite ||= Invite.generate(invited_by, email: email, group_ids: desired_group_ids)

        sync_groups(invite: invite, desired_group_ids: desired_group_ids)

        invite
      rescue Invite::UserExists
        nil
      rescue ActiveRecord::RecordInvalid, RateLimiter::LimitExceeded => e
        raise Error, e.message
      end

      private

      def mapped_group_ids(tags)
        tags = Array(tags)

        TagGroupMapping.all.filter_map do |tag, group_name|
          next if tags.exclude?(tag)

          group = Group.find_by(name: group_name)

          unless group
            Rails.logger.warn(
              "[#{PLUGIN_NAME}] Discourse group '#{group_name}' configured for GHL tag '#{tag}' does not exist",
            )
            next
          end

          group.id
        end
      end

      def configured_group_ids
        TagGroupMapping.all.values.filter_map { |group_name| Group.find_by(name: group_name)&.id }
      end

      def sync_groups(invite:, desired_group_ids:)
        managed_group_ids = configured_group_ids

        current_group_ids = invite.group_ids & managed_group_ids

        group_ids_to_add = desired_group_ids - current_group_ids

        group_ids_to_remove = current_group_ids - desired_group_ids

        group_ids_to_add.each do |group_id|
          invite.invited_groups.find_or_create_by!(group_id: group_id)
        end

        invite.invited_groups.where(group_id: group_ids_to_remove).destroy_all
      end
    end
  end
end
