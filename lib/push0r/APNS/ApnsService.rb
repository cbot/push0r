require 'net-http2'
require 'openssl'
require 'json'
require_relative 'ApnsServiceUtils'

module Push0r
  # A module that contains Apple Push Notification Service error codes
  module ApnsErrorCodes
    PAYLOAD_EMPTY = 0
    PAYLOAD_TOO_LARGE = 1
    BAD_TOPIC = 2
    TOPIC_DISALLOWED = 3
    BAD_MESSAGE_ID = 4
    BAD_EXPIRATION_DATE = 5
    BAD_PRIORITY = 6
    MISSING_DEVICE_TOKEN = 7
    BAD_DEVICE_TOKEN = 8
    DEVICE_TOKEN_NOT_FOR_TOPIC = 9
    UNREGISTERED = 10
    DUPLICATE_HEADERS = 11
    BAD_CERTIFICATE_ENVIRONMENT = 12
    BAD_CERTIFICATE = 13
    FORBIDDEN = 14
    BAD_PATH = 15
    METHOD_NOT_ALLOWED = 16
    TOO_MANY_REQUESTS = 17
    IDLE_TIMEOUT = 18
    SHUTDOWN = 19
    INTERNAL_SERVER_ERROR = 20
    SERVICE_UNAVAILABLE = 21
    MISSING_TOPIC = 22
    SOCKET_ERROR = 99
    OTHER = 100
  end

  module ApnsEnvironment
    PRODUCTION = 0
    SANDBOX = 1
  end

  # ApnsService is a {Service} implementation to push notifications to iOS and OSX users using the Apple Push Notification Service.
  # @example
  #   queue = Push0r::Queue.new
  #
  #   apns_service = Push0r::ApnsService.new(File.read("aps.pem"), Push0r::ApnsEnvironment::SANDBOX)
  #   queue.register_service(apns_service)
  class ApnsService < Service
    include Push0r::ApnsServiceUtils

    # Returns a new ApnsService instance
    # @param certificate_data [String] the Apple push certificate in PEM format
    # @param environment [Fixnum] the environment to use when sending messages. Either ApnsEnvironment::PRODUCTION or ApnsEnvironment::SANDBOX. Defaults to ApnsEnvironment::PRODUCTION.
    def initialize(certificate_data, environment = ApnsEnvironment::PRODUCTION, topic = nil)
      @certificate_data = certificate_data
      @environment = environment
      @ssl = nil
      @sock = nil
      @messages = []
      @topic = topic
    end

    # @see Service#can_send?
    def can_send?(message)
      return message.is_a?(ApnsPushMessage) && message.environment == @environment
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

      host = @environment == ApnsEnvironment::SANDBOX ? 'api.development.push.apple.com' : 'api.push.apple.com'
      client = NetHttp2::Client.new("https://#{host}", ssl_context: ctx)
      failed_messages = []

      @messages.dup.each do |message|
        payload = message.payload
        json = payload.to_json
        priority = '10' # default high priority
        if payload[:aps] && payload[:aps]['content-available'] && payload[:aps]['content-available'].to_i != 0 && (payload[:aps][:alert].nil? && payload[:aps][:sound].nil? && payload[:aps][:badge].nil?)
          priority = '5' ## lower priority for content-available pushes without alert/sound/badge
        end

        headers = {
          'apns-expiration' => "#{Time.now.to_i + (message.time_to_live || 1209600)}",
          'apns-priority' => priority,
          'apns-id' => message.identifier
        }
        headers['apns-topic'] = @topic unless @topic.nil?
        headers['apns-collapse-id'] = message.collapse_key unless message.collapse_key.nil?

        begin
          response = client.call(:post, "/3/device/#{message.receiver_token}", headers: headers, body: json)
        rescue SocketError => e
          failed_messages << FailedMessage.new(Push0r::ApnsErrorCodes::SOCKET_ERROR, Array(message.receiver_token), message)
          puts e
          next
        end

        if response.status.to_i != 200 && !response.body.empty?
          begin
            resp = JSON.parse(response.body)
            error_code = error_code_for_reason(resp['reason'])
            failed_messages << FailedMessage.new(error_code, Array(message.receiver_token), message)
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
