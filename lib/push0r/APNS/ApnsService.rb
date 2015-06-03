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
      failed_messages = []
      result = false
      begin
        begin
          setup_ssl(true)
        rescue SocketError => e
          puts "Error: #{e}"
          break
        end
        (result, error_message, error_code) = transmit_messages
        unless result
          failed_messages << FailedMessage.new(error_code, [error_message.receiver_token], error_message)
          reset_message(error_message.identifier)
          result = true if @messages.empty?
        end
      end until result

      close_ssl

      @messages = [] ## reset
      return [failed_messages, []]
    end

    # Calls the APNS feedback service and returns an array of expired push tokens
    # @return [Array<String>] an array of expired push tokens
    def get_feedback
      tokens = []

      begin
        setup_ssl(true)
      rescue SocketError => e
        puts "Error: #{e}"
        return tokens
      end

      if IO.select([@ssl], nil, nil, 1)
        while (line = @ssl.read(38))
          f = line.unpack('N1n1H64')
          time = Time.at(f[0])
          token = f[2].scan(/.{8}/).join(' ')
          tokens << token
        end
      end

      close_ssl

      return tokens
    end

    private
    def setup_ssl(for_feedback = false)
      close_ssl
      ctx = OpenSSL::SSL::SSLContext.new

      ctx.key = OpenSSL::PKey::RSA.new(@certificate_data, '')
      ctx.cert = OpenSSL::X509::Certificate.new(@certificate_data)

      @sock = nil
      unless for_feedback
        @sock = TCPSocket.new(@environment == ApnsEnvironment::SANDBOX ? 'gateway.sandbox.push.apple.com' : 'gateway.push.apple.com', 2195)
      else
        @sock = TCPSocket.new(@environment == ApnsEnvironment::SANDBOX ? 'feedback.sandbox.push.apple.com' : 'feedback.push.apple.com', 2195)
      end
      @ssl = OpenSSL::SSL::SSLSocket.new(@sock, ctx)
      @ssl.connect
    end

    def close_ssl
      if !@ssl.nil? && !@ssl.closed?
        begin
          @ssl.close
        rescue IOError
        end
      end
      @ssl = nil

      if !@sock.nil? && !@sock.closed?
        begin
          @sock.close
        rescue IOError
        end
      end
      @sock = nil
    end

    def reset_message(error_identifier)
      index = @messages.find_index { |o| o.identifier == error_identifier }

      if index.nil? ## this should never happen actually
        @messages = []
      elsif index < @messages.length - 1 # reset @messages to contain all messages after the one that has failed
        @messages = @messages[index+1, @messages.length]
      else ## the very last message failed, so there's nothing left to be sent
        @messages = []
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

      return frame
    end

    def transmit_messages
      if @messages.empty? || @ssl.nil?
        return [true, nil, nil]
      end

      pushdata = ''
      @messages.each do |message|
        pushdata << create_push_frame(message)
      end

      @ssl.write(pushdata)

      if IO.select([@ssl], nil, nil, 1)
        begin
          read_buffer = @ssl.read(6)
        rescue Exception
          return [true, nil, nil]
        end
        if !read_buffer.nil?
          #cmd = read_buffer[0].unpack("C").first
          error_code = read_buffer[1].unpack('C').first
          identifier = read_buffer[2, 4].unpack('N').first
          puts "ERROR: APNS returned error code #{error_code} #{identifier}"
          return [false, message_for_identifier(identifier), error_code]
        else
          return [true, nil, nil]
        end
      end
      return [true, nil, nil]
    end

    def message_for_identifier(identifier)
      index = @messages.find_index { |o| o.identifier == identifier }
      index.nil? ? nil : @messages[index]
    end
  end
end
