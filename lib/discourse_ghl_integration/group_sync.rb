# frozen_string_literal: true

module DiscourseGhlIntegration
  class GroupSync
    class Error < StandardError
    end

    class << self
      def sync(user:, tags:)
        raise Error, "Discourse user is missing" if user.blank?

        tags = Array(tags)
        mappings = TagGroupMapping.all

        managed_group_names = mappings.values.flatten.uniq

        desired_group_names =
          mappings.flat_map { |tag, group_names| tags.include?(tag) ? group_names : [] }.uniq

        managed_group_names.each do |group_name|
          group = Group.find_by(name: group_name)

          unless group
            Rails.logger.warn(
              "[#{PLUGIN_NAME}] Discourse group '#{group_name}' configured for GHL tags does not exist",
            )
            next
          end

          if desired_group_names.include?(group_name)
            add_to_group(user, group)
          else
            remove_from_group(user, group)
          end
        end
      end

      private

      def add_to_group(user, group)
        return if group.users.exists?(id: user.id)

        group.add(user)
      end

      def remove_from_group(user, group)
        return unless group.users.exists?(id: user.id)

        group.remove(user)
      end
    end
  end
end
