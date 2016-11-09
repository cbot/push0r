require 'net-http2'
require 'openssl'
require 'json'
require 'securerandom'
require_relative 'apns_provider_utils'

module Push0r
  module APNS
    # A module that contains Apple Push Notification Service error codes
    module ErrorCodes
      BAD_CERTIFICATE = 'ApnsBadCertificate'
      BAD_CERTIFICATE_ENVIRONMENT = 'ApnsBadCertificateEnvironment'
      BAD_COLLAPSE_ID = 'ApnsBadCollapseId'
      BAD_DEVICE_TOKEN = 'ApnsBadDeviceToken'
      BAD_EXPIRATION_DATE = 'ApnsBadExpirationDate'
      BAD_MESSAGE_ID = 'ApnsBadMessageId'
      BAD_PATH = 'ApnsBadPath'
      BAD_PRIORITY = 'ApnsBadPriority'
      BAD_TOPIC = 'ApnsBadTopic'
      DEVICE_TOKEN_NOT_FOR_TOPIC = 'ApnsDeviceTokenNotForTopic'
      DUPLICATE_HEADERS = 'ApnsDuplicateHeaders'
      EXPIRED_PROVIDER_TOKEN = 'ApnsExpiredProviderToken'
      FORBIDDEN = 'ApnsForbidden'
      IDLE_TIMEOUT = 'ApnsIdleTimeout'
      INTERNAL_SERVER_ERROR = 'ApnsInternalServerError'
      INVALID_PROVIDER_TOKEN = 'ApnsInvalidProviderToken'
      METHOD_NOT_ALLOWED = 'ApnsMethodNotAllowed'
      MISSING_DEVICE_TOKEN = 'ApnsMissingDeviceToken'
      MISSING_PROVIDER_TOKEN = 'ApnsMissingProviderToken'
      MISSING_TOPIC = 'ApnsMissingTopic'
      PAYLOAD_EMPTY = 'ApnsPayloadEmpty'
      PAYLOAD_TOO_LARGE = 'ApnsPayloadTooLarge'
      SERVICE_UNAVAILABLE = 'ApnsUnavailable'
      SHUTDOWN = 'ApnsShutdown'
      SOCKET_ERROR = 'ApnsSocketError'
      TOO_MANY_REQUESTS = 'ApnsTooManyRequests'
      TOO_MANY_PROVIDER_TOKEN_UPDATES = 'ApnsTooManyProviderTokenUpdates'
      TOPIC_DISALLOWED = 'ApnsTopicDisallowed'
      UNREGISTERED = 'ApnsUnregistered'
      OTHER = 'ApnsOther'
    end

    module Environment
      PRODUCTION = 0
      SANDBOX = 1
    end
    
    module Mode
      JWT = 0
      CERTIFICATE = 1
    end

    # APNSProvider is a {Provider} implementation to push notifications to iOS and OSX users using the Apple Push Notification Service.
    class APNSProvider < Provider
      include Push0r::APNS::ProviderUtils

      # Returns a new APNSProvider instance using either a client certificate in PEM format or a signing key an JWT tokens
      # @param certificate_data [String] the Apple push certificate in PEM format
      # @param environment [Fixnum] the environment to use when sending messages. Either Environment::PRODUCTION or Environment::SANDBOX. Defaults to Environment::PRODUCTION.
      # @param @team_id [String] the apple developer team id
      # @param @key_id [String] the signing key's id from the apple developer center
      # @param @key_data [String] the signing key as downloaded from the apple developer center
      # @param @topic [String] the topic (bundle id) to target
      def initialize(environment:, topic: nil, certificate_data: nil, team_id: nil, key_id: nil, key_data: nil)
        if ![Environment::PRODUCTION, Environment::SANDBOX].include?(environment)
          raise Push0r::Exceptions::PushException.new("invalid apns push environment: #{environment}")
        end
        @environment = environment
                
        if team_id && key_id && key_data
            raise Push0r::Exceptions::PushInitException.new("supply either a certificate or a team_id, a key_id and a key - not both") if !certificate_data.nil?
            @team_id = team_id
            @key_id = key_id
            @key_data = key_data
            @jwt = nil
            @jwt_created_at = nil
            @mode = Mode::JWT
            @topic = topic
        elsif certificate_data
            raise Push0r::Exceptions::PushInitException.new("supply either a certificate or a team_id, a key_id and a key - not both") if team_id || key_id || key_data
            @certificate_data = certificate_data
            @mode = Mode::CERTIFICATE
            if topic
              @topic = topic
            else
              @topic = extract_first_topic_from_certificate(@certificate_data)
            end
        else
          raise Push0r::Exceptions::PushInitException.new("Neither JWT nor certificate mode parameters given")
        end

        raise Push0r::Exceptions::PushInitException.new("Topic not set") if @topic.nil?
        
        @messages = []
      end

      # @see Service#send
      def send(message)
        @messages << message
      end

      # @see Service#init_push
      def init_push
        # empty
      end

      # @see Service#end_push
      def end_push
        if @messages.empty?
          return [[], []]
        end
        
        ctx = nil
        if @certificate_data
          begin
            ctx = OpenSSL::SSL::SSLContext.new
            ctx.key = OpenSSL::PKey::RSA.new(@certificate_data, '')
            ctx.cert = OpenSSL::X509::Certificate.new(@certificate_data)
          rescue StandardError => e
            raise Push0r::Exceptions::PushInitException.new("OpenSSL error: #{e}")
          end
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
          
          if @mode == Mode::JWT
            if @jwt.nil? || @jwt_created_at.nil? || Time.now - @jwt_created_at > 2700
              @jwt = generate_jwt(@team_id, @key_id, @key_data)
              @jwt_created_at = Time.now
            end
          
            headers['authorization'] = "bearer #{@jwt}"
          end
          
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

          if response && response.status.to_i != 200 && !response.body.empty?
            begin
              resp = JSON.parse(response.body)
              puts resp ####
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