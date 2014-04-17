include Push0r

class Push0r::ApnsPushMessage < PushMessage		
	def send(receiver_token, payload = {}, identifier = nil)
		if receiver_token.nil? then raise(ArgumentError, "receiver_token is nil!") end
		if payload.nil? then raise(ArgumentError, "payload is nil!") end	
			
		receiver_token = receiver_token.gsub(/\s+/, "")
		if receiver_token.length != 64 then raise(ArgumentError, "invalid receiver_token length!") end			
		
		devicetoken = [receiver_token].pack('H*')
		devicetoken_length = [32].pack("n")
		devicetoken_item = "\1#{devicetoken_length}#{devicetoken}"
		
		if identifier.nil? || identifier.to_i == 0
			identifier = Random.rand(2**32)
		end
		identifier = [identifier.to_i].pack("N")
		identifier_length = [4].pack("n")
		identifier_item = "\3#{identifier_length}#{identifier}"
		
		expiration_date = [Time.now.to_i + 7 * 24 * 3600].pack("N")
		expiration_date_length = [4].pack("n")
		expiration_item = "\4#{expiration_date_length}#{expiration_date}"
		
		priority = "\xA" ## default: high priority
		if payload[:aps] && payload[:aps]["content-available"] && payload[:aps]["content-available"].to_i != 0 && (payload[:aps][:alert].nil? && payload[:aps][:sound].nil? && payload[:aps][:badge].nil?)
			priority = "\5" ## lower priority for content-available pushes without
		end
		
		priority_length = [1].pack("n")
		priority_item = "\5#{priority_length}#{priority}"
		
		payload = payload.to_json.force_encoding("BINARY")
		payload_length = [payload.bytesize].pack("n")
		payload_item = "\2#{payload_length}#{payload}"
		
		frame_length = [devicetoken_item.bytesize + payload_item.bytesize + identifier_item.bytesize + expiration_item.bytesize + priority_item.bytesize].pack("N")
		frame = "\2#{frame_length}#{devicetoken_item}#{payload_item}#{identifier_item}#{expiration_item}#{priority_item}"
		
		@pushdata << frame
	end	
	
	def send_simple(receiver_token, alert_text = nil, sound = nil, badge = nil, identifier = nil)
		payload = {aps: {}}
		if alert_text
			payload[:aps][:alert] = alert_text
		end
		if sound
			payload[:aps][:sound] = sound
		end
		if badge
			payload[:aps][:badge] = bade
		end
		self.send(receiver_token, payload, identifier)
	end
end