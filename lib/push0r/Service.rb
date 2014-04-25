module Push0r
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