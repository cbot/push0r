module Push0r
	module ErrorCodes
		NO_ERROR = -1
	end

	# Service is the base class for all implemented push services. A Service encapsulates everything that is necessary to take a batch of push notifications and transmit it to the receivers.
	# @abstract
	class Service

		# Called on the service every time a PushMessage is added to a Queue in order to determine whether it can send the given message.
		# @param message [PushMessage] the message
		# @return [Boolean] true if this service can send the given message, otherwise false
		# @abstract
		# @see PushMessage
		# @see Queue
		def can_send?(message)
			return false
		end

		# Sends a single push message. This is called during the flushing of a Queue for every enqueued PushMessage. The service may create its own internal queue in order to efficiently batch the messages.
		# @param message [PushMessage] the message to be sent
		# @return [void]
		# @abstract
		# @see PushMessage
		# @see Queue
		def send(message)
			## empty
		end

		# Called on the service during the flushing of a Queue before the first PushMessage is sent.
		# @return [void]
		# @abstract
		# @see PushMessage
		# @see Queue
		def init_push
			## empty
		end

		# Called on the service during the flushing of a Queue after the last PushMessage has been sent. If the service manages its own internal queue, this is the place to actually transmit all messages.
		# @return [Array(Array<String>, Array<String>)] Failed new RegId Messages
		# @abstract
		# @see PushMessage
		# @see Queue
		def end_push
			## empty
			return [[], []]
		end
	end
end

require_relative 'APNS/ApnsService'
require_relative 'GCM/GcmService'
