# frozen_string_literal: true

module DiscourseGhlIntegration
  class InviteSync
    class Error < StandardError
    end

    class << self
      def sync(email:, tags:, contact_id:)
        raise Error, "GoHighLevel contact email is missing" if email.blank?
        raise Error, "GoHighLevel contact ID is missing" if contact_id.blank?

        desired_group_ids = mapped_group_ids(tags)
        invited_by =
          if SiteSetting.ghl_inviter_username.present?
            User.find_by_username(SiteSetting.ghl_inviter_username)
          else
            User.find(Discourse::SYSTEM_USER_ID)
          end
        raise Error, "Configured GHL inviter no longer exists" unless invited_by

        invite =
          Invite
            .where(email: email)
            .order(created_at: :desc)
            .detect do |candidate|
              candidate.redeemable? && InviteContactStore.contact_id(candidate.id) == contact_id
            end

        invite ||= Invite.generate(invited_by, email: email, group_ids: desired_group_ids)

        sync_groups(invite: invite, desired_group_ids: desired_group_ids)

        invite.reload
        InviteContactStore.save(invite_id: invite.id, contact_id: contact_id)

        invite
      rescue Invite::UserExists
        nil
      rescue ActiveRecord::RecordInvalid, RateLimiter::LimitExceeded => e
        raise Error, e.message
      end

      private

      def mapped_group_ids(tags)
        tags = Array(tags)

        TagGroupMapping
          .all
          .flat_map do |tag, group_names|
            next [] if tags.exclude?(tag)

            group_names.filter_map do |group_name|
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
          .uniq
      end

      def configured_group_ids
        TagGroupMapping
          .all
          .values
          .flatten
          .filter_map { |group_name| Group.find_by(name: group_name)&.id }
          .uniq
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
