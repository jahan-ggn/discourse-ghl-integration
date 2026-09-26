# frozen_string_literal: true

module DiscourseGhlIntegration
  class MappingMigration
    class Error < StandardError
    end

    def self.run(old_mapping:, new_mapping:, apply: false, &confirm)
      new(old_mapping:, new_mapping:, apply:).run(&confirm)
    end

    def initialize(old_mapping:, new_mapping:, apply:)
      @old_text = old_mapping.to_s
      @new_text = new_mapping.to_s
      @old_mapping = parse(@old_text)
      @new_mapping = parse(@new_text)
      @apply = apply
    end

    def run(&confirm)
      live = parse(SiteSetting.ghl_tag_group_mappings.to_s)

      if [@old_mapping, @new_mapping].exclude?(live)
        raise Error, "Live mapping matches neither OLD_MAPPING nor NEW_MAPPING"
      end

      old_names = @old_mapping.values.flatten.uniq
      new_names = @new_mapping.values.flatten.uniq

      new_names.each do |name|
        unless Group.exists?(name: name)
          raise Error, "New mapping group #{name.inspect} does not exist"
        end
      end

      groups =
        (old_names | new_names)
          .filter_map do |name|
            group = Group.find_by(name: name)
            [name, group] if group
          end
          .to_h

      missing_old = old_names - groups.keys
      puts "Old groups already absent: #{missing_old.inspect}" if missing_old.present?

      managed_ids = groups.values.map(&:id)
      contact_cache = {}
      changes = []

      contact_for =
        lambda do |contact_id|
          contact_cache[contact_id] ||= begin
            contact =
              begin
                Client.get_contact(contact_id)
              rescue Client::Error => e
                raise unless e.contact_not_found?

                puts "GHL contact #{contact_id} was deleted; treating its tags as empty"
                { "id" => contact_id, "tags" => [], "deleted" => true }
              end

            unless contact["id"] == contact_id && contact["tags"].is_a?(Array)
              raise Error, "Invalid GHL contact or tags for #{contact_id}"
            end

            location = contact["locationId"]
            if location.present? && location != OauthStore.location_id
              raise Error, "Contact #{contact_id} belongs to another GHL location"
            end

            contact
          end
        end

      desired_ids_for =
        lambda do |tags|
          @new_mapping
            .flat_map do |tag, names|
              tags.include?(tag) ? names.map { |name| groups.fetch(name).id } : []
            end
            .uniq
        end

      UserCustomField
        .where(name: ContactSync::GHL_CONTACT_ID_FIELD)
        .includes(:user)
        .find_each do |field|
          user = field.user
          next unless user

          contact = contact_for.call(field.value)
          current = user.group_ids & managed_ids
          desired = desired_ids_for.call(contact.fetch("tags"))

          changes << [:user, user.id, desired - current, current - desired]
        end

      Invite
        .where(invited_by_id: Discourse::SYSTEM_USER_ID)
        .find_each do |invite|
          next unless invite.redeemable?

          contact_id = InviteContactStore.contact_id(invite.id)
          next if contact_id.blank?

          contact = contact_for.call(contact_id)

          unless contact["deleted"] || contact["email"].to_s.casecmp?(invite.email.to_s)
            raise Error, "Invite #{invite.id} email does not match its linked GHL contact"
          end

          current = invite.group_ids & managed_ids
          desired = desired_ids_for.call(contact.fetch("tags"))

          changes << [:invite, invite.id, desired - current, current - desired]
        end

      changes.select! { |_, _, add, remove| add.present? || remove.present? }

      puts "Mode: #{@apply ? "AWAITING CONFIRMATION" : "DRY RUN"}"
      puts "Linked GHL contacts checked: #{contact_cache.length}"
      puts "Records requiring changes: #{changes.length}"

      names_by_id = groups.values.index_by(&:id)
      changes.each do |type, id, add, remove|
        puts "#{type} #{id}: " \
               "add=#{add.map { |group_id| names_by_id.fetch(group_id).name }.inspect} " \
               "remove=#{remove.map { |group_id| names_by_id.fetch(group_id).name }.inspect}"
      end

      return changes unless @apply
      unless confirm&.call(@new_text) == true
        puts "Cancelled. No changes made."
        return changes
      end

      unless parse(SiteSetting.ghl_tag_group_mappings.to_s) == live
        raise Error, "Live mapping changed while reviewing the plan; start again"
      end
      SiteSetting.ghl_tag_group_mappings = @new_text unless live == @new_mapping

      changes.each do |type, id, add, remove|
        if type == :user
          user = User.find(id)

          remove.each { |group_id| names_by_id.fetch(group_id).remove(user) }
          add.each { |group_id| names_by_id.fetch(group_id).add(user) }
        else
          invite = Invite.find(id)

          invite.invited_groups.where(group_id: remove).destroy_all
          add.each { |group_id| invite.invited_groups.find_or_create_by!(group_id: group_id) }
        end
      end

      puts "Applied #{changes.length} record changes."
      changes
    end

    private

    def parse(text)
      mapping = Hash.new { |hash, tag| hash[tag] = [] }

      text
        .split("|")
        .each do |entry|
          tag, group = entry.split(":", 2)
          tag = tag&.strip
          group = group&.strip

          raise Error, "Invalid mapping entry #{entry.inspect}" if tag.blank? || group.blank?

          mapping[tag] << group if mapping[tag].exclude?(group)
        end

      mapping
    end
  end
end
