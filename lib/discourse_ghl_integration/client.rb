# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module ::DiscourseGhlIntegration
  class Client
    BASE_URL = "https://services.leadconnectorhq.com"
    API_VERSION = "v3"

    class Error < StandardError
      attr_reader :status, :response_body

      def initialize(message, status: nil, response_body: nil)
        super(message)
        @status = status
        @response_body = response_body
      end

      def contact_not_found?
        return false unless status == 400
        return false if response_body.blank?

        body = JSON.parse(response_body)

        message = body["message"] || body["error"]

        message.to_s.downcase.include?("contact") &&
          message.to_s.downcase.include?("not found")
      rescue JSON::ParserError
        false
      end
    end

    class << self
      def lookup_contact_by_email(email)
        location_id = OauthStore.location_id

        raise Error, "GoHighLevel Location ID is missing" if location_id.blank?

        response =
          get(
            "/contacts/lookup",
            {
              locationId: location_id,
              email: email,
              limit: 20,
            },
          )

        response.fetch("contacts", [])
      end

      def create_contact(email:, first_name: nil, last_name: nil)
        location_id = OauthStore.location_id

        raise Error, "GoHighLevel Location ID is missing" if location_id.blank?

        body = {
          email: email,
          locationId: location_id,
          source: "Discourse",
        }

        body[:firstName] = first_name if first_name.present?
        body[:lastName] = last_name if last_name.present?

        response = post("/contacts/", body)

        contact = response["contact"]

        raise Error, "GoHighLevel did not return the created contact" if contact.blank?

        contact
      end

      def get_contact(contact_id)
        raise Error, "GoHighLevel contact ID is missing" if contact_id.blank?

        response = get("/contacts/#{contact_id}")

        contact = response["contact"]

        raise Error, "GoHighLevel did not return the contact" if contact.blank?

        contact
      end

      def delete_contact(contact_id)
        raise Error, "GoHighLevel contact ID is missing" if contact_id.blank?

        response = delete("/contacts/#{contact_id}")

        response["succeeded"] == true
      end

      def add_tags(contact_id:, tags:)
        raise Error, "GoHighLevel contact ID is missing" if contact_id.blank?
        raise Error, "GoHighLevel tags are missing" if tags.blank?

        response =
          post(
            "/contacts/#{contact_id}/tags",
            {
              tags: Array(tags),
            },
          )

        response.fetch("tags", [])
      end

      def remove_tags(contact_id:, tags:)
        raise Error, "GoHighLevel contact ID is missing" if contact_id.blank?
        raise Error, "GoHighLevel tags are missing" if tags.blank?

        response =
          delete(
            "/contacts/#{contact_id}/tags",
            {
              tags: Array(tags),
            },
          )

        response.fetch("tags", [])
      end

      private

      def get(path, params = {})
        uri = URI("#{BASE_URL}#{path}")
        uri.query = URI.encode_www_form(params) if params.present?

        request = Net::HTTP::Get.new(uri)
        add_headers(request)

        perform_request(uri, request)
      end

      def post(path, body)
        uri = URI("#{BASE_URL}#{path}")

        request = Net::HTTP::Post.new(uri)
        add_headers(request)
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)

        perform_request(uri, request)
      end

      def delete(path, body = nil)
        uri = URI("#{BASE_URL}#{path}")

        request = Net::HTTP::Delete.new(uri)
        add_headers(request)

        if body.present?
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(body)
        end

        perform_request(uri, request)
      end

      def add_headers(request)
        request["Accept"] = "application/json"
        request["Version"] = API_VERSION
        request["Authorization"] = "Bearer #{Oauth.access_token}"
      end

      def perform_request(uri, request)
        response =
          Net::HTTP.start(
            uri.hostname,
            uri.port,
            use_ssl: uri.scheme == "https",
          ) do |http|
            http.request(request)
          end

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error(
            "[#{PLUGIN_NAME}] GoHighLevel API request failed " \
              "#{request.method} #{uri.path} with status #{response.code}",
          )

          raise Error.new(
            "GoHighLevel API request failed with status #{response.code}",
            status: response.code.to_i,
            response_body: response.body,
          )
        end

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Error, "GoHighLevel returned an invalid API response"
      rescue SocketError, Timeout::Error, Errno::ECONNREFUSED => e
        Rails.logger.warn(
          "[#{PLUGIN_NAME}] GoHighLevel API network error: #{e.class}",
        )

        raise Error, "Unable to connect to GoHighLevel"
      end
    end
  end
end