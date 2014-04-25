module Push0r
	class PushMessage
		attr_reader :payload, :identifier, :receiver_token
	
		def initialize(receiver_token, identifier = nil)
			@receiver_token = receiver_token
			@identifier = identifier
			@payload = {}
		end
	
		def attach(payload = {})
			@payload.merge!(payload)
			return self
		end
	
		def simple(alert_text = nil, sound = nil, badge = nil, identifier = nil)
			## empty
			return self
		end
	end
end

require_relative 'APNS/ApnsPushMessage'
require_relative 'GCM/GcmPushMessage'