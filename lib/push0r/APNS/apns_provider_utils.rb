require 'json_web_token'
require 'openssl'

module JsonWebToken
  module Jwt
    module_function
    def config_header(options)
      HEADER_DEFAULT.merge(options).select {|k,v| k == :alg || k == :kid}
    end
  end
end

module Push0r
  module APNS
    module ProviderUtils
      def generate_jwt(team_id, key_id, key_data)
        key = OpenSSL::PKey::EC.new key_data
      
        payload = {:iss => team_id, :iat => Time.now.to_i}
        opts = {alg: 'ES256', key: key, kid: key_id}
        jwt = JsonWebToken.sign(payload, opts)
  
        return jwt
      end
      
      # @return [String, nil] the first topic from the certificate's 1.2.840.113635.100.6.3.6 extension
      # @param [Object] certificate_data the push certificate data
      def extract_first_topic_from_certificate(certificate_data)
        if certificate_data.nil?
          puts 'Unable to extract topic from certificate - certificate missing'
          return nil
        end

        begin
          cert = OpenSSL::X509::Certificate.new(certificate_data)
        rescue StandardError => e
          puts "OpenSSL error: #{e}"
          return nil
        end

        extension = cert.extensions.select { |e| e.oid == '1.2.840.113635.100.6.3.6' }.first
        if extension.nil?
          return nil # this cert does not contain multiple topics. This is not a problem.
        end

        topic = nil
        begin
          extension_node = OpenSSL::ASN1.decode(extension)
          if extension_node.is_a?(OpenSSL::ASN1::Sequence)
            extension_node.each do |subnode|
              if subnode.is_a?(OpenSSL::ASN1::OctetString)
                sequence_node = OpenSSL::ASN1.decode(subnode.value)
                if sequence_node.is_a?(OpenSSL::ASN1::Sequence)
                  sequence_node.each do |data_node|
                    if data_node.value.is_a?(String)
                      topic = data_node.value
                      break
                    end
                  end
                end
              end
            end
          end
        rescue StandardError => e
          puts "OpenSSL Error: #{e}"
        end

        if topic.nil?
          puts 'Unable to extract topic from certificate - could not parse data'
        end

        topic
      end

      # @param [String] reason the reason string that is returned from APNS
      # @return [Fixnum] the error code (from Push0r::ApnsErrorCodes) for the reason
      def error_code_for_reason(reason)
        codes = Push0r::APNS::ErrorCodes
        
        case reason
          when 'BadCertificate'
            return codes::
          when 'BadCertificateEnvironment'
            return codes::BAD_CERTIFICATE_ENVIRONMENT
          when 'BadCollapseId'
            return codes::BAD_COLLAPSE_ID
          when 'BadDeviceToken'
            return codes::BAD_DEVICE_TOKEN
          when 'BadExpirationDate'
            return codes::BAD_EXPIRATION_DATE
          when 'BadMessageId'
            return codes::BAD_MESSAGE_ID
          when 'BadPath'
            return codes::BAD_PATH
          when 'BadPriority'
            return codes::BAD_PRIORITY
          when 'BadTopic'
            return codes::BAD_TOPIC
          when 'DeviceTokenNotForTopic'
            return codes::DEVICE_TOKEN_NOT_FOR_TOPIC
          when 'DuplicateHeaders'
            return codes::DUPLICATE_HEADERS
          when 'ExpiredProviderToken'
            return codes::EXPIRED_PROVIDER_TOKEN
          when 'Forbidden'
            return codes::FORBIDDEN
          when 'IdleTimeout'
            return codes::IDLE_TIMEOUT
          when 'InternalServerError'
            return codes::INTERNAL_SERVER_ERROR
          when 'InvalidProviderToken'
            return codes::INVALID_PROVIDER_TOKEN
          when 'MethodNotAllowed'
            return codes::METHOD_NOT_ALLOWED
          when 'MissingDeviceToken'
            return codes::MISSING_DEVICE_TOKEN
          when 'MissingProviderToken'
            return codes::MISSING_PROVIDER_TOKEN
          when 'MissingTopic'
            return codes::MISSING_TOPIC
          when 'PayloadEmpty'
            return codes::PAYLOAD_EMPTY
          when 'PayloadTooLarge'
            return codes::PAYLOAD_TOO_LARGE
          when 'Unavailable'
            return codes::UNAVAILABLE
          when 'Shutdown'
            return codes::SHUTDOWN
          when 'SocketError'
            return codes::SOCKET_ERROR
          when 'TooManyRequests'
            return codes::TOO_MANY_REQUESTS
          when 'TooManyProviderTokenUpdates'
            return codes::TOO_MANY_PROVIDER_TOKEN_UPDATES
          when 'TopicDisallowed'
            return codes::TOPIC_DISALLOWED
          when 'Unregistered'
            return codes::UNREGISTERED
          else
            return codes::OTHER
        end
      end
    end
  end
end

















