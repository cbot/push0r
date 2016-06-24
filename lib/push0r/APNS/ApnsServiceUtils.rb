module Push0r
  module ApnsServiceUtils
    # @return [String, nil] the first topic from the certificate's 1.2.840.113635.100.6.3.6 extension
    # @param [Object] certificate_data the push certificate data
    def extract_first_topic_from_certificate(certificate_data)
      if certificate_data.nil?
        puts 'Unable to extract topic from certificate - certificate missing'
        return
      end

      begin
        cert = OpenSSL::X509::Certificate.new(certificate_data)
      rescue StandardError => e
        puts "OpenSSL error: #{e}"
        return
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
      codes = Push0r::ApnsErrorCodes

      case reason
        when 'PayloadEmpty'
          return codes::PAYLOAD_EMPTY
        when 'PayloadTooLarge'
          return codes::PAYLOAD_TOO_LARGE
        when 'BadTopic'
          return codes::BAD_TOPIC
        when 'TopicDisallowed'
          return codes::TOPIC_DISALLOWED
        when 'BadMessageId'
          return codes::BAD_MESSAGE_ID
        when 'BadExpirationDate'
          return codes::BAD_EXPIRATION_DATE
        when 'BadPriority'
          return codes::BAD_PRIORITY
        when 'MissingDeviceToken'
          return codes::MISSING_DEVICE_TOKEN
        when 'BadDeviceToken'
          return codes::BAD_DEVICE_TOKEN
        when 'DeviceTokenNotForTopic'
          return codes::DEVICE_TOKEN_NOT_FOR_TOPIC
        when 'Unregistered'
          return codes::UNREGISTERED
        when 'DuplicateHeaders'
          return codes::DUPLICATE_HEADERS
        when 'BadCertificateEnvironment'
          return codes::BAD_CERTIFICATE_ENVIRONMENT
        when 'BadCertificate'
          return codes::BAD_CERTIFICATE
        when 'Forbidden'
          return codes::FORBIDDEN
        when 'BadPath'
          return codes::BAD_PATH
        when 'MethodNotAllowed'
          return codes::METHOD_NOT_ALLOWED
        when 'TooManyRequests'
          return codes::TOO_MANY_REQUESTS
        when 'IdleTimeout'
          return codes::IDLE_TIMEOUT
        when 'Shutdown'
          return codes::SHUTDOWN
        when 'InternalServerError'
          return codes::INTERNAL_SERVER_ERROR
        when 'ServiceUnavailable'
          return codes::SERVICE_UNAVAILABLE
        when 'MissingTopic'
          return codes::MISSING_TOPIC
        else
          return codes::OTHER
      end
    end
  end
end

















