# frozen_string_literal: true

module ::DiscourseGhlIntegration
  class TagGroupMapping
    class << self
      def all
        SiteSetting
          .ghl_tag_group_mappings
          .to_s
          .split("|")
          .filter_map do |mapping|
            tag, group_name = mapping.split(":", 2)

            next if tag.blank? || group_name.blank?

            [tag.strip, group_name.strip]
          end
          .to_h
      end
    end
  end
end
