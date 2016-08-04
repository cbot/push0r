require 'net-http2'
require 'openssl'
require 'json'
require 'securerandom'
require_relative 'apns_provider_utils'

module Push0r
  module APNS
    # A module that contains Apple Push Notification Service error codes
    module ErrorCodes
      PAYLOAD_EMPTY = 'ApnsPayloadEmpty'
      PAYLOAD_TOO_LARGE = 'ApnsPayloadTooLarge'
      BAD_TOPIC = 'ApnsBadTopic'
      TOPIC_DISALLOWED = 'ApnsTopicDisallowed'
      BAD_MESSAGE_ID = 'ApnsBadMessageId'
      BAD_EXPIRATION_DATE = 'ApnsBadExpirationDate'
      BAD_PRIORITY = 'ApnsBadPriority'
      MISSING_DEVICE_TOKEN = 'ApnsMissingDeviceToken'
      BAD_DEVICE_TOKEN = 'ApnsBadDeviceToken'
      DEVICE_TOKEN_NOT_FOR_TOPIC = 'ApnsDeviceTokenNotForTopic'
      UNREGISTERED = 'ApnsUnregistered'
      DUPLICATE_HEADERS = 'ApnsDuplicateHeaders'
      BAD_CERTIFICATE_ENVIRONMENT = 'ApnsBadCertificateEnvironment'
      BAD_CERTIFICATE = 'ApnsBadCertificate'
      FORBIDDEN = 'ApnsForbidden'
      BAD_PATH = 'ApnsBadPath'
      METHOD_NOT_ALLOWED = 'ApnsMethodNotAllowed'
      TOO_MANY_REQUESTS = 'ApnsTooManyRequests'
      IDLE_TIMEOUT = 'ApnsIdleTimeout'
      SHUTDOWN = 'ApnsShutdown'
      INTERNAL_SERVER_ERROR = 'ApnsInternalServerError'
      SERVICE_UNAVAILABLE = 'ApnsUnavailable'
      MISSING_TOPIC = 'ApnsMissingTopic'
      SOCKET_ERROR = 'ApnsSocketError'
      OTHER = 'ApnsOther'
    end

    module Environment
      PRODUCTION = 0
      SANDBOX = 1
    end

    # APNSProvider is a {Provider} implementation to push notifications to iOS and OSX users using the Apple Push Notification Service.
    class APNSProvider < Provider
      include Push0r::APNS::ProviderUtils

      # Returns a new APNSProvider instance
      # @param certificate_data [String] the Apple push certificate in PEM format
      # @param environment [Fixnum] the environment to use when sending messages. Either Environment::PRODUCTION or Environment::SANDBOX. Defaults to Environment::PRODUCTION.
      def initialize(certificate_data, environment = Environment::PRODUCTION, topic = nil)
        @certificate_data = certificate_data
        @environment = environment
        @messages = []
        @topic = topic
      end

      # @see Service#send
      def send(message)
        @messages << message
      end

      # @see Service#init_push
      def init_push
        if @topic.nil?
          @topic = extract_first_topic_from_certificate(@certificate_data)
        end
      end

      # @see Service#end_push
      def end_push
        if @messages.empty?
          return [[], []]
        end

        begin
          ctx = OpenSSL::SSL::SSLContext.new
          ctx.key = OpenSSL::PKey::RSA.new(@certificate_data, '')
          ctx.cert = OpenSSL::X509::Certificate.new(@certificate_data)
        rescue StandardError => e
          puts "OpenSSL error: #{e}"
          @messages = []
          return [[], []]
        end

        host = @environment == Environment::SANDBOX ? 'api.development.push.apple.com' : 'api.push.apple.com'
        client = NetHttp2::Client.new("https://#{host}", ssl_context: ctx)
        failed_messages = []

        @messages.dup.each do |message|
          payload = message.payload
          json = payload.to_json

          # determine priority
          priority = '10' # default high priority
          content_available_set = (payload.dig(:aps, :'content-available')&.to_i || 0) != 0
          aps_content_set = !Hash(payload[:aps]).select { |k,v| k != :'content-available' }.empty?
          if content_available_set && !aps_content_set
            priority = '5' ## lower priority for content-available pushes without alert/sound/badge
          end

          # headers
          headers = {
            'apns-expiration' => "#{Time.now.to_i + (message.time_to_live || 1209600)}",
            'apns-priority' => priority,
            'apns-id' => message.identifier || SecureRandom.uuid
          }
          headers['apns-topic'] = @topic unless @topic.nil?
          headers['apns-collapse-id'] = message.collapse_key unless message.collapse_key.nil?

          device_token = message.receiver_tokens.first

          begin
            response = client.call(:post, "/3/device/#{device_token}", headers: headers, body: json)
          rescue SocketError => e
            failed_messages << FailedMessage.new(ErrorCodes::SOCKET_ERROR, Array(device_token), message, self)
            puts e
            next
          end

          if response.status.to_i != 200 && !response.body.empty?
            begin
              resp = JSON.parse(response.body)
              error_code = error_code_for_reason(resp['reason'])
              failed_messages << FailedMessage.new(error_code, Array(device_token), message, self)
            rescue StandardError => e
              puts e
            end
          end

          @messages.delete(message)
        end

        # close the connection
        client.close

        return [failed_messages, []]
      end
    end
  end
end