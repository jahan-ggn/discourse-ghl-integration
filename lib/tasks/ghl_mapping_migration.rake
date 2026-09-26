# frozen_string_literal: true

require_relative "../discourse_ghl_integration/mapping_migration"

unless Rake::Task.task_defined?("ghl:reconcile_mappings")
  namespace :ghl do
    desc "Preview and apply a change to one GHL tag-to-group mapping"
    task reconcile_mappings: :environment do
      require "highline/import"

      old_mapping = SiteSetting.ghl_tag_group_mappings.to_s
      entries = old_mapping.split("|").map(&:strip)

      abort "No mappings are configured" if entries.empty?

      say("Current mappings:")
      entries.each_with_index { |entry, index| say("#{index + 1}. #{entry}") }

      selection = ask("\nEnter the mapping number you want to change: ").strip
      abort "Invalid mapping number" unless selection.match?(/\A\d+\z/)

      index = selection.to_i - 1
      abort "Invalid mapping number" unless index.between?(0, entries.length - 1)

      say("\nCreate the new Discourse group before running this migration.")
      replacement = ask("Enter new mapping (ghl_tag:discourse_group): ").strip
      tag, group_name = replacement.split(":", 2)

      if replacement.include?("|") || tag.blank? || group_name.blank? || group_name.include?(":")
        abort "Use exactly one ghl_tag:discourse_group mapping"
      end

      unless Group.exists?(name: group_name.strip)
        abort "Discourse group #{group_name.strip.inspect} does not exist. Create it first."
      end

      replacement = "#{tag.strip}:#{group_name.strip}"
      original = entries[index]
      entries[index] = replacement
      new_mapping = entries.join("|")

      abort "Mapping unchanged" if new_mapping == old_mapping

      say("\nReplacing #{original.inspect} with #{replacement.inspect}")
      say("Proposed mappings:")
      entries.each_with_index { |entry, entry_index| say("#{entry_index + 1}. #{entry}") }

      DiscourseGhlIntegration::MappingMigration.run(
        old_mapping: old_mapping,
        new_mapping: new_mapping,
        apply: true,
      ) do
        say("\nReview the proposed user and invitation changes above.")
        ask("Type APPLY to update the mapping and access: ").strip == "APPLY"
      end
    end
  end
end
