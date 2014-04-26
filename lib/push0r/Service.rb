module Push0r
	module ErrorCodes
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
	
	class Service
		def can_send?(message)
			return false
		end
	
		def send(message)
			## empty
		end
	
		private
		def init_push
			## empty
		end
	
		def end_push
			## empty
		end
	end
end

require_relative 'APNS/ApnsService'
require_relative 'GCM/GcmService'