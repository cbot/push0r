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
			failed_messages = []
			new_registration_messages = []
			
			@queued_messages.each do |service, messages|
				service.init_push
				messages.each do |message|
					service.send(message)
				end
				(failed, new_registration) = service.end_push
				failed_messages += failed
				new_registration_messages += new_registration
			end
			@queued_messages = []
			return [failed_messages, new_registration_messages]
		end
	end
end