module Push0r
	class PushMessage
		attr_reader :payload, :identifier, :receiver_token, :time_to_live
	
		def initialize(receiver_token, identifier = nil, time_to_live = nil)
			@receiver_token = receiver_token
			@identifier = identifier
			@time_to_live = time_to_live
			@payload = {}
		end
	
		def attach(payload = {})
			@payload.merge!(payload)
			return self
		end
	end
end

require_relative 'APNS/ApnsPushMessage'
require_relative 'GCM/GcmPushMessage'