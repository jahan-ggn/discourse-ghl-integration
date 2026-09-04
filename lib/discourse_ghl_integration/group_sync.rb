# frozen_string_literal: true

module ::DiscourseGhlIntegration
  class GroupSync
    class Error < StandardError
    end

    class << self
      def sync(user:, tags:)
        raise Error, "Discourse user is missing" if user.blank?

        tags = Array(tags)
        mappings = TagGroupMapping.all

        mappings.each do |tag, group_name|
          group = Group.find_by(name: group_name)

          unless group
            Rails.logger.warn(
              "[#{PLUGIN_NAME}] Discourse group '#{group_name}' configured for GHL tag '#{tag}' does not exist",
            )
            next
          end

          if tags.include?(tag)
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