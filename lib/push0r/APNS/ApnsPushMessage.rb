module Push0r
	class ApnsPushMessage < PushMessage		
		def initialize(receiver_token, identifier = nil, time_to_live = nil)
			if identifier.nil? ## make sure the message has an identifier (required for apns error handling)
				identifier = Random.rand(2**32)
			end
			super(receiver_token, identifier, time_to_live)
		end
		
		def simple(alert_text = nil, sound = nil, badge = nil)
			new_payload = {aps: {}}
			if alert_text
				new_payload[:aps][:alert] = alert_text
			end
			if sound
				new_payload[:aps][:sound] = sound
			end
			if badge
				new_payload[:aps][:badge] = bade
			end		
			@payload.merge!(new_payload)
			
			return self
		end
	end
end