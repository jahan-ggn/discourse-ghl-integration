# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module ::DiscourseGhlIntegration
  class Oauth
    TOKEN_URL = "https://services.leadconnectorhq.com/oauth/token"
    LOCATION_TOKEN_URL =
      "https://services.leadconnectorhq.com/oauth/location-token"

    API_VERSION = "v3"
    EXPIRY_BUFFER = 5.minutes.to_i

    class Error < StandardError
    end

    class << self
      def exchange_code(code:, redirect_uri:)
        response =
          post_form(
            TOKEN_URL,
            {
              client_id: SiteSetting.ghl_client_id,
              client_secret: SiteSetting.ghl_client_secret,
              grant_type: "authorization_code",
              code: code,
              user_type: "Location",
              redirect_uri: redirect_uri,
            },
          )

        parse_token_response(response)
      end

      def save_pending_company_token(token)
        unless token["userType"] == "Company" && token["companyId"].present?
          raise Error, "Cannot store an invalid GoHighLevel Company token"
        end

        OauthStore.save_pending_company(
          {
            "access_token" => token.fetch("access_token"),
            "refresh_token" => token.fetch("refresh_token"),
            "expires_at" => Time.now.to_i + token.fetch("expires_in").to_i,
            "company_id" => token.fetch("companyId"),
            "scope" => token["scope"],
          },
        )
      end

      def save_location_token(token)
        unless token["userType"] == "Location" && token["locationId"].present?
          raise Error, "Cannot store an invalid GoHighLevel Location token"
        end

        OauthStore.save(
          {
            "access_token" => token.fetch("access_token"),
            "refresh_token" => token.fetch("refresh_token"),
            "expires_at" => Time.now.to_i + token.fetch("expires_in").to_i,
            "location_id" => token.fetch("locationId"),
            "company_id" => token["companyId"],
            "scope" => token["scope"],
          },
        )
      end

      def exchange_location_token(company_token:, company_id:, location_id:)
        response =
          post_form(
            LOCATION_TOKEN_URL,
            {
              companyId: company_id,
              locationId: location_id,
            },
            bearer_token: company_token,
          )

        token = parse_token_response(response)

        unless token["userType"] == "Location" && token["locationId"].present?
          raise Error, "GoHighLevel did not return a valid Location token"
        end

        token
      end

      def complete_pending_connection!
        company = OauthStore.pending_company
        install = OauthStore.pending_install

        return nil if company.blank? || install.blank?

        unless company["company_id"] == install["company_id"]
          raise Error, "GoHighLevel company does not match the installation"
        end

        if company["expires_at"].to_i <= Time.now.to_i
          OauthStore.clear_pending_company

          raise Error,
                "GoHighLevel Company token expired before Location authorization completed"
        end

        token =
          exchange_location_token(
            company_token: company.fetch("access_token"),
            company_id: company.fetch("company_id"),
            location_id: install.fetch("location_id"),
          )

        save_location_token(token)

        OauthStore.clear_pending_company
        OauthStore.clear_pending_install

        token
      end

      def access_token
        credentials = OauthStore.credentials

        raise Error, "GoHighLevel is not connected" if credentials.blank?

        return credentials["access_token"] unless expiring?(credentials)

        refresh!

        refreshed_credentials = OauthStore.credentials

        raise Error, "GoHighLevel token refresh failed" if refreshed_credentials.blank?

        refreshed_credentials.fetch("access_token")
      end

      def refresh!
        credentials = OauthStore.credentials

        raise Error, "GoHighLevel is not connected" if credentials.blank?

        refresh_token = credentials["refresh_token"]

        if refresh_token.blank?
          raise Error, "No GoHighLevel refresh token is available"
        end

        response =
          post_form(
            TOKEN_URL,
            {
              client_id: SiteSetting.ghl_client_id,
              client_secret: SiteSetting.ghl_client_secret,
              grant_type: "refresh_token",
              refresh_token: refresh_token,
              user_type: "Location",
            },
          )

        token = parse_token_response(response)

        unless token["userType"] == "Location"
          raise Error,
                "Expected a Location token while refreshing GoHighLevel OAuth"
        end

        save_location_token(token)

        token
      end

      private

      def expiring?(credentials)
        credentials["expires_at"].to_i <= Time.now.to_i + EXPIRY_BUFFER
      end

      def post_form(url, body, bearer_token: nil)
        uri = URI(url)

        request = Net::HTTP::Post.new(uri)
        request["Accept"] = "application/json"
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request["Version"] = API_VERSION

        if bearer_token.present?
          request["Authorization"] = "Bearer #{bearer_token}"
        end

        request.body = URI.encode_www_form(body)

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
            "[#{PLUGIN_NAME}] GoHighLevel OAuth request failed with status #{response.code}",
          )

          raise Error,
                "GoHighLevel OAuth request failed with status #{response.code}"
        end

        response
      rescue SocketError, Timeout::Error, Errno::ECONNREFUSED => e
        Rails.logger.warn(
          "[#{PLUGIN_NAME}] GoHighLevel OAuth network error: #{e.class}",
        )

        raise Error, "Unable to connect to GoHighLevel"
      end

      def parse_token_response(response)
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Error, "GoHighLevel returned an invalid OAuth response"
      end
    end
  end
end