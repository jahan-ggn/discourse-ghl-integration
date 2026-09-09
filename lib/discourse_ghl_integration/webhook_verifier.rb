# frozen_string_literal: true

require "openssl"
require "base64"

module ::DiscourseGhlIntegration
  class WebhookVerifier
    PUBLIC_KEY = <<~PEM
      -----BEGIN PUBLIC KEY-----
      MCowBQYDK2VwAyEAi2HR1srL4o18O8BRa7gVJY7G7bupbN3H9AwJrHCDiOg=
      -----END PUBLIC KEY-----
    PEM

    class Error < StandardError
    end

    class << self
      def verify!(payload:, signature:)
        raise Error, "GoHighLevel webhook signature is missing" if signature.blank?

        signature_bytes = Base64.strict_decode64(signature)
        public_key = OpenSSL::PKey.read(PUBLIC_KEY)

        valid =
          public_key.verify(
            nil,
            signature_bytes,
            payload,
          )

        raise Error, "GoHighLevel webhook signature is invalid" unless valid

        true
      rescue ArgumentError, OpenSSL::PKey::PKeyError => e
        raise Error, "GoHighLevel webhook signature verification failed: #{e.message}"
      end
    end
  end
end