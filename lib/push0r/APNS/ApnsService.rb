require 'http/2'
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

    # Returns a new ApnsService instance
    # @param certificate_data [String] the Apple push certificate in PEM format
    # @param environment [Fixnum] the environment to use when sending messages. Either ApnsEnvironment::PRODUCTION or ApnsEnvironment::SANDBOX. Defaults to ApnsEnvironment::PRODUCTION.
    def initialize(certificate_data, environment = ApnsEnvironment::PRODUCTION)
      @certificate_data = certificate_data
      @environment = environment
      @ssl = nil
      @sock = nil
      @messages = []
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
      # not used for apns
    end

    # @see Service#end_push
    def end_push
      begin
        failed_messages = transmit_messages(topic: 'net.wissenswerft.vwpushtest')
        return [[], []]
      rescue SocketError => e
        puts "Error: #{e}"
        return [[], []]
      end
    end

    private
    def setup_ssl
      close_ssl
      ctx = OpenSSL::SSL::SSLContext.new

      ctx.key = OpenSSL::PKey::RSA.new(@certificate_data, '')
      ctx.cert = OpenSSL::X509::Certificate.new(@certificate_data)

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

    def create_push_frame(message)
      receiver_token = message.receiver_token
      payload = message.payload
      identifier = message.identifier
      time_to_live = (message.time_to_live.nil? || message.time_to_live.to_i < 0) ? 0 : message.time_to_live.to_i

      raise(ArgumentError, 'receiver_token is nil!') if receiver_token.nil?

      raise(ArgumentError, 'payload is nil!') if payload.nil?

      receiver_token = receiver_token.gsub(/\s+/, '')
      raise(ArgumentError, 'invalid receiver_token length!') if receiver_token.length != 64

      devicetoken = [receiver_token].pack('H*')
      devicetoken_length = [32].pack('n')
      devicetoken_item = "\1#{devicetoken_length}#{devicetoken}"

      identifier = [identifier.to_i].pack('N')
      identifier_length = [4].pack('n')
      identifier_item = "\3#{identifier_length}#{identifier}"

      expiration_date = [(time_to_live > 0 ? Time.now.to_i + time_to_live : 0)].pack('N')
      expiration_date_length = [4].pack('n')
      expiration_item = "\4#{expiration_date_length}#{expiration_date}"

      priority = "\xA" ## default: high priority
      if payload[:aps] && payload[:aps]['content-available'] && payload[:aps]['content-available'].to_i != 0 && (payload[:aps][:alert].nil? && payload[:aps][:sound].nil? && payload[:aps][:badge].nil?)
        priority = "\5" ## lower priority for content-available pushes without alert/sound/badge
      end

      priority_length = [1].pack('n')
      priority_item = "\5#{priority_length}#{priority}"

      payload = payload.to_json.force_encoding('BINARY')
      payload_length = [payload.bytesize].pack('n')
      payload_item = "\2#{payload_length}#{payload}"

      frame_length = [devicetoken_item.bytesize + payload_item.bytesize + identifier_item.bytesize + expiration_item.bytesize + priority_item.bytesize].pack('N')
      frame = "\2#{frame_length}#{devicetoken_item}#{payload_item}#{identifier_item}#{expiration_item}#{priority_item}"

      frame
    end

    def transmit_messages(topic:)
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

        json = message.payload.to_json

        headers = {
            ':method' => 'POST',
            ':path' => "/3/device/#{message.receiver_token}",
            'content-length' => "#{json.length}",
            'apns-topic' => topic
        }
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
