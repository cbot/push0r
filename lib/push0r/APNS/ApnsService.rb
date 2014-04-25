include Push0r

class Push0r::ApnsService < Service
	def initialize(certificate_data, sandbox_environment = false)
		@certificate_data = certificate_data
		@sandbox_environment = sandbox_environment
		@ssl = nil
		@sock = nil
		@pushdata = ""
	end
	
	def init_push
		ctx = OpenSSL::SSL::SSLContext.new
		
		ctx.key = OpenSSL::PKey::RSA.new(@certificate_data, '')
		ctx.cert = OpenSSL::X509::Certificate.new(@certificate_data)
				
		@sock = TCPSocket.new(@sandbox_environment ? "gateway.sandbox.push.apple.com" : "gateway.push.apple.com", 2195)
		@ssl = OpenSSL::SSL::SSLSocket.new(@sock, ctx)
		@ssl.connect
	end
	
	def push_message_object
		return ApnsPushMessage.new(@pushdata)
	end
	
	def end_push
		if @pushdata.length > 0 && @ssl
			@ssl.write(@pushdata)
			
			if IO.select([@ssl], nil, nil, 2)
				read_buffer = @ssl.read(6)
				if !read_buffer.nil?
					message = "ERROR: APNS returned #{read_buffer.unpack("H*")}"
					puts message
				end
			end
		end
		
		unless @ssl.nil?
			@ssl.close
		end
		unless @sock.nil?
			@sock.close
		end
		
	end
end