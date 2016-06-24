require 'http/2'
require 'openssl'
require_relative 'ApnsServiceUtils'

module Push0r
  # A module that contains Apple Push Notification Service error codes
  module ApnsErrorCodes
    PROCESSING_ERROR = 1
    MISSING_DEVICE_TOKEN = 2
    MISSING_TOPIC = 3
    MISSING_PAYLOAD = 4
    INVALID_TOKEN_SIZE = 5
    INVALID_TOPIC_SIZE = 6
    INVALID_PAYLOAD_SIZE = 7
    INVALID_TOKEN = 8
    SHUTDOWN = 10
    NONE = 255
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
      begin
        failed_messages = transmit_messages
        return [[], []]
      rescue SocketError => e
        puts "Error: #{e}"
        return [[], []]
      end
    end

    private
    def setup_ssl
      close_ssl

      begin
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.key = OpenSSL::PKey::RSA.new(@certificate_data, '')
        ctx.cert = OpenSSL::X509::Certificate.new(@certificate_data)
      rescue StandardError => e
        puts "OpenSSL error: #{e}"
        return
      end

      @sock = nil
      @sock = TCPSocket.new(@environment == ApnsEnvironment::SANDBOX ? 'api.development.push.apple.com' : 'api.push.apple.com', 443)
      @ssl = OpenSSL::SSL::SSLSocket.new(@sock, ctx)
      @ssl.sync_close = true
      @ssl.connect
    end

    def close_ssl
      if !@ssl.nil? && !@ssl.closed?
        begin
          @ssl.close
        rescue IOError
        end
      end

      if !@sock.nil? && !@sock.closed?
        begin
          @sock.close
        rescue IOError
        end
      end
    end

    def transmit_messages
      if @messages.empty?
        return []
      end

      setup_ssl

      conn = HTTP2::Client.new

      conn.on(:frame) do |bytes|
        @ssl.print bytes
        @ssl.flush
      end

      @messages.each do |message|
        raise(ArgumentError, 'receiver_token is nil!') if message.receiver_token.nil?
        raise(ArgumentError, 'payload is nil!') if message.payload.nil?

        stream = conn.new_stream

        stream.on(:close) do
          @ssl.close if conn.active_stream_count == 0
        end

        stream.on(:headers) do |h|
          puts "response headers: #{h}"
        end

        stream.on(:data) do |d|
          puts "response data chunk: <<#{d}>>"
        end

        payload = message.payload
        json = payload.to_json
        priority = '10' # default high priority
        if payload[:aps] && payload[:aps]['content-available'] && payload[:aps]['content-available'].to_i != 0 && (payload[:aps][:alert].nil? && payload[:aps][:sound].nil? && payload[:aps][:badge].nil?)
          priority = '5' ## lower priority for content-available pushes without alert/sound/badge
        end

        headers = {
            ':method' => 'POST',
            ':path' => "/3/device/#{message.receiver_token}",
            'content-length' => "#{json.length}",
            'apns-expiration' => "#{Time.now.to_i + (message.time_to_live || 1209600)}",
            'apns-priority' => priority,
            'apns-id' => message.identifier
        }
        headers['apns-topic'] = @topic unless @topic.nil?

        stream.headers(headers, end_stream: false)
        stream.data(json)
      end

      while !@ssl.closed? && !@ssl.eof?
        data = @ssl.read_nonblock(1024)
        begin
          conn << data
        rescue => e
          puts "#{e.class} exception: #{e.message} - closing socket."
        end
      end

      @messages = []

      return []
    end
  end
end
