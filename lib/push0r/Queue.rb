module Push0r
	class Queue
		def initialize
			@services = []
			@queued_messages = {}
		end
	
		def register_service(service)
			unless @services.include?(service)
				@services << service
			end
		end
	
		def add(message)
			@services.each do |service|
				if service.can_send?(message)
					if @queued_messages[service].nil?
						@queued_messages[service] = []
					end
					@queued_messages[service] << message
					return true
				end
			end
			return false
		end
	
		def flush
			@queued_messages.each do |service, messages|
				service.init_push
				messages.each do |message|
					service.send(message)
				end
				service.end_push
			end
		end
	end
end