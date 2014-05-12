module Push0r
	module ApnsErrorCodes
		NO_ERROR 				= 0
		PROCESSING_ERROR 		= 1
		MISSING_DEVICE_TOKEN 	= 2
		MISSING_TOPIC 			= 3
		MISSING_PAYLOAD 		= 4
		INVALID_TOKEN_SIZE 		= 5
		INVALID_TOPIC_SIZE 		= 6
		INVALID_PAYLOAD_SIZE 	= 7
		INVALID_TOKEN 			= 8
		SHUTDOWN 				= 10
		NONE 					= 255
	end
	
	class ApnsService < Service
		def initialize(certificate_data, sandbox_environment = false)
			@certificate_data = certificate_data
			@sandbox_environment = sandbox_environment
			@ssl = nil
			@sock = nil
			@messages = []
		end
	
		def can_send?(message)
			return message.is_a?(ApnsPushMessage)
		end
	
		def send(message)
			@messages << message
		end
		
		def init_push
			# not used for apns
		end
		
		def end_push
			failed_messages = []
			begin
				setup_ssl
				(result, error_message, error_code) = transmit_messages
				if result == false 
					failed_messages << {:error_code => error_code, :message => error_message}
					reset_message(error_identifier)
					if @messages.empty? then result = true end
				end
			end while result != true
		
			unless @ssl.nil?
				@ssl.close
			end
			unless @sock.nil?
				@sock.close
			end
			return [failed_messages, []]
		end
	
		private
		def setup_ssl
			ctx = OpenSSL::SSL::SSLContext.new
		
			ctx.key = OpenSSL::PKey::RSA.new(@certificate_data, '')
			ctx.cert = OpenSSL::X509::Certificate.new(@certificate_data)
				
			@sock = TCPSocket.new(@sandbox_environment ? "gateway.sandbox.push.apple.com" : "gateway.push.apple.com", 2195)
			@ssl = OpenSSL::SSL::SSLSocket.new(@sock, ctx)
			@ssl.connect
		end
		
		def reset_message(error_identifier)
			index = @messages.find_index {|o| o.identifier == error_identifier}
			
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
		
			if receiver_token.nil? then raise(ArgumentError, "receiver_token is nil!") end
			if payload.nil? then raise(ArgumentError, "payload is nil!") end	
			
			receiver_token = receiver_token.gsub(/\s+/, "")
			if receiver_token.length != 64 then raise(ArgumentError, "invalid receiver_token length!") end			
		
			devicetoken = [receiver_token].pack('H*')
			devicetoken_length = [32].pack("n")
			devicetoken_item = "\1#{devicetoken_length}#{devicetoken}"
		
			identifier = [identifier.to_i].pack("N")
			identifier_length = [4].pack("n")
			identifier_item = "\3#{identifier_length}#{identifier}"
		
			expiration_date = [Time.now.to_i + 7 * 24 * 3600].pack("N")
			expiration_date_length = [4].pack("n")
			expiration_item = "\4#{expiration_date_length}#{expiration_date}"
		
			priority = "\xA" ## default: high priority
			if payload[:aps] && payload[:aps]["content-available"] && payload[:aps]["content-available"].to_i != 0 && (payload[:aps][:alert].nil? && payload[:aps][:sound].nil? && payload[:aps][:badge].nil?)
				priority = "\5" ## lower priority for content-available pushes without alert/sound/badge
			end
		
			priority_length = [1].pack("n")
			priority_item = "\5#{priority_length}#{priority}"
		
			payload = payload.to_json.force_encoding("BINARY")
			payload_length = [payload.bytesize].pack("n")
			payload_item = "\2#{payload_length}#{payload}"
		
			frame_length = [devicetoken_item.bytesize + payload_item.bytesize + identifier_item.bytesize + expiration_item.bytesize + priority_item.bytesize].pack("N")
			frame = "\2#{frame_length}#{devicetoken_item}#{payload_item}#{identifier_item}#{expiration_item}#{priority_item}"
		
			return frame
		end
		
		def transmit_messages
			if @messages.empty? || @ssl.nil?
				return [true, nil, nil]
			end
			
			pushdata = ""
			@messages.each do |message|
				pushdata << create_push_frame(message)
			end
			
			@ssl.write(pushdata)
		
			if IO.select([@ssl], nil, nil, 2)
				read_buffer = @ssl.read(6)
				if !read_buffer.nil?
					#cmd = read_buffer[0].unpack("C").first
					error_code = read_buffer[1].unpack("C").first
					identifier = read_buffer[2,4].unpack("N").first
					puts "ERROR: APNS returned error code #{error_code} #{identifier}"
					return [false, message_for_identifier(identifier), error_code]
				else
					return [true, nil, nil]
				end
			end
			return [true, nil, nil]
		end
		
		def message_for_identifier(identifier)
			index = @messages.find_index {|o| o.identifier == identifier}
			if index.nil?
				return nil
			else
				return @messages[index]
			end
		end
	end
end