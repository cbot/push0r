module Push0r
	class GcmService < Service
		def can_send?(message)
			return message.is_a?(GcmPushMessage)
		end
		
		def send(message)
		end
		
		private
		def init_push
		end
		
		def end_push
		end
	end
end