# frozen_string_literal: true

# name: discourse-ghl-integration
# about: Integrates GoHighLevel contacts and tags with Discourse users and groups
# version: 0.0.1
# authors: Jahan Gagan
# url: https://github.com/jahan-ggn/discourse-ghl-integration

enabled_site_setting :discourse_ghl_integration_enabled

module ::DiscourseGhlIntegration
  PLUGIN_NAME = "discourse-ghl-integration"
end

require_relative "lib/discourse_ghl_integration/engine"

after_initialize do
  # Code which should run after Rails has finished booting
end
