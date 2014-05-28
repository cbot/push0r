module Push0r
	
	# A Queue is used to register services to be used to transmit PushMessages. Single PushMessages are then put into the queue and a call to the {#flush} method transmits all enqueued messages using the registered services.  In a sense, Queue is the class that ties all the other Push0r components together.
	# @example
	#   queue = Push0r::Queue.new
	#
	#   gcm_service = Push0r::GcmService.new("__gcm_api_token__")
	#   queue.register_service(gcm_service)
	#
	#   apns_service = Push0r::ApnsService.new(File.read("aps.pem"), true)
	#   queue.register_service(apns_service)
	#
	#   gcm_message = Push0r::GcmPushMessage.new("__registration_id__")
	#   gcm_message.attach({"data" => {"d" => "1"}})
	#
	#   apns_message = Push0r::ApnsPushMessage.new("__device_token__")
	#   apns_message.attach({"data" => {"v" => "1"}}
	#
	#   queue.add(gcm_message)
	#   queue.add(apns_message)
	#
	#   queue.flush
	class Queue
		def initialize
			@services = []
			@queued_messages = {}
		end
	
		# Registers a Service with the Queue
		# @note Every service can only be registered once with the same queue
		# @param service [Service] the service to be registered with the queue
		# @return [void]
		# @see Service
		def register_service(service)
			unless @services.include?(service)
				@services << service
			end
		end
	
		# Adds a PushMessage to the queue
		# @param message [PushMessage] the message to be added to the queue
		# @return [Boolean] true if message was added to the queue (that is: if any of the registered services can handle the message), otherwise false
		# @see PushMessage
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
	
		# Flushes the queue by transmitting the enqueued messages using the registered services
		# @return [Array(Array<String>, Array<String>)] Failed new RegId Messages
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
			@queued_messages = {}
			return [failed_messages, new_registration_messages]
		end
	end
end