# frozen_string_literal: true

DiscourseGhlIntegration::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::DiscourseGhlIntegration::Engine, at: "discourse-ghl-integration" }
