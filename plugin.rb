# frozen_string_literal: true

# name: discourse-ghl-integration
# about: TODO
# meta_topic_id: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :discourse_ghl_integration_enabled

module ::DiscourseGhlIntegration
  PLUGIN_NAME = "discourse-ghl-integration"
end

require_relative "lib/discourse_ghl_integration/engine"

after_initialize do
  # Code which should run after Rails has finished booting
end
