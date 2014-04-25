module Push0r
	class ApnsPushMessage < PushMessage		
		def simple(alert_text = nil, sound = nil, badge = nil, identifier = nil)
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