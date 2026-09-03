# frozen_string_literal: true

DiscourseGhlIntegration::Engine.routes.draw do
  get "/oauth/callback" => "oauth#callback"

  post "/webhooks" => "webhooks#create"
end

Discourse::Application.routes.draw { mount ::DiscourseGhlIntegration::Engine, at: "/crm" }
