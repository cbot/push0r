require 'net-http2'
require 'openssl'
require 'json'
require 'securerandom'
require_relative 'apns_provider_utils'
require_relative 'apns_jwt_jar'

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
      attr_reader :environment, :topic, :certificate_data, :team_id, :key_id, :key_data

      # Returns a new APNSProvider instance using either a client certificate in PEM format or a signing key an JWT tokens
      # @param certificate_data [String] the Apple push certificate in PEM format
      # @param environment [Integer] the environment to use when sending messages. Either Environment::PRODUCTION or Environment::SANDBOX. Defaults to Environment::PRODUCTION.
      # @param @team_id [String] the apple developer team id
      # @param @key_id [String] the signing key's id from the apple developer center
      # @param @key_data [String] the signing key as downloaded from the apple developer center
      # @param @topic [String] the topic (bundle id) to target
      # @param @jwt_jar [Push0r::APNS::JWTJar] an optional custom object that handles JWT storage
      def initialize(environment: Environment::PRODUCTION, topic: nil, certificate_data: nil, team_id: nil, key_id: nil, key_data: nil, jwt_jar: nil)
        unless [Environment::PRODUCTION, Environment::SANDBOX].include?(environment)
          raise Push0r::Exceptions::PushException.new("invalid apns push environment: #{environment}")
        end
        @environment = environment
                
        if team_id && key_id && key_data
            raise Push0r::Exceptions::PushInitException.new('supply either a certificate or a team_id, a key_id and a key - not both') if !certificate_data.nil?
            @team_id = team_id
            @key_id = key_id
            @key_data = key_data
            @jwt_jar = jwt_jar || Push0r::APNS::JWTJar.new
            @jwt_jar.load_data(key_id)
            @mode = Mode::JWT
            @topic = topic
        elsif certificate_data
            raise Push0r::Exceptions::PushInitException.new('supply either a certificate or a team_id, a key_id and a key - not both') if team_id || key_id || key_data
            @certificate_data = certificate_data
            @mode = Mode::CERTIFICATE
            if topic
              @topic = topic
            else
              @topic = extract_first_topic_from_certificate(@certificate_data)
            end
        else
          raise Push0r::Exceptions::PushInitException.new('neither JWT nor certificate mode parameters given')
        end

        raise Push0r::Exceptions::PushInitException.new('topic not set') if @topic.nil?
        
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
            ctx.key = OpenSSL::PKey::RSA.new(@certificate_data)
            ctx.cert = OpenSSL::X509::Certificate.new(@certificate_data)
          rescue StandardError => e
            raise Push0r::Exceptions::PushInitException.new("OpenSSL error: #{e}")
          end
        end

        host = @environment == Environment::SANDBOX ? 'api.development.push.apple.com' : 'api.push.apple.com'
        client = NetHttp2::Client.new("https://#{host}", ssl_context: ctx)
        failed_messages = []

        @messages.dup.each do |message|
          payload = build_payload(message)
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
            if @jwt_jar.jwt.nil? || @jwt_jar.jwt_created_at.nil? || Time.now - @jwt_jar.jwt_created_at > 2700
              @jwt_jar.jwt = generate_jwt(@team_id, @key_id, @key_data)
              @jwt_jar.jwt_created_at = Time.now
            end
          
            headers['authorization'] = "bearer #{@jwt_jar.jwt}"
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
              error_code = error_code_for_reason(resp['reason'])

              # wrong token, reset
              if error_code == ErrorCodes::INVALID_PROVIDER_TOKEN
                @jwt_jar.jwt = nil
                @jwt_jar.jwt_created_at = nil
              end

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

      private
      # @param [Push0r::Message] message
      def build_payload(message)
        hash = message.payload
        if message.alert_title || message.alert_body || message.alert_subtitle
          ensure_structure(hash, :aps, :alert)
          hash[:aps][:alert][:body] = message.alert_body if message.alert_body
          hash[:aps][:alert][:title] = message.alert_title if message.alert_title
          hash[:aps][:alert][:subtitle] = message.alert_subtitle if message.alert_subtitle
        end

        if message.sound_name || message.badge_value || message.content_available_set || message.mutable_content_set || message.category_name
          ensure_structure(hash, :aps)

          hash[:aps][:sound] = message.sound_name if message.sound_name
          hash[:aps][:badge] = message.badge_value if message.badge_value
          hash[:aps][:'content-available'] = 1 if message.content_available_set
          hash[:aps][:'mutable-content'] = 1 if message.mutable_content_set
          hash[:aps][:category] = message.category_name if message.category_name
        end

        hash
      end
    end
  end
end