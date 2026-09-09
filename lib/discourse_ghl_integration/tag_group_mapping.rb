# frozen_string_literal: true

module DiscourseGhlIntegration
  class TagGroupMapping
    class << self
      def all
        mappings = Hash.new { |hash, tag| hash[tag] = [] }

        SiteSetting
          .ghl_tag_group_mappings
          .to_s
          .split("|")
          .each do |mapping|
            tag, group_name = mapping.split(":", 2)

            tag = tag&.strip
            group_name = group_name&.strip

            next if tag.blank? || group_name.blank?

            mappings[tag] << group_name if mappings[tag].exclude?(group_name)
          end

        mappings
      end
    end
  end
end
