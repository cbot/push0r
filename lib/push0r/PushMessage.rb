module Push0r
	# PushMessage is the base class for all implemented push message types. A PushMessage encapsulates values like the notification's payload, its receiver, etc.
	# @abstract
	# @attr_reader [Hash] payload the payload for this push message
	# @attr_reader [Fixnum] identifier the unique identifier for this push message
	# @attr_reader [String, Array] receiver_token the receiver's push token
	# @attr_reader [Fixnum] :time_to_live the time to live in seconds for this push message
	class PushMessage
		attr_reader :payload, :identifier, :receiver_token, :time_to_live
	
		# Creates a new PushMessage instance
		# @param receiver_token [String, Array] the receiver's push token. Some subclasses might also accept an Array of tokens.
		# @param identifier [Fixnum] a unique identifier to identify this push message during error handling. If nil, a random identifier is automatically generated.
		# @param time_to_live [Fixnum] The time to live in seconds for this push messages. If nil, the time to live depends on the service used to transmit the message.
		def initialize(receiver_token, identifier = nil, time_to_live = nil)
			@receiver_token = receiver_token
			@identifier = identifier
			@time_to_live = time_to_live
			@payload = {}
		end
	
		# Attaches the given payload to the push message.
		# @note attaching is done using the merge! method of the Hash class, i.e. be careful not to overwrite previously set Hash keys.
		# @param payload [Hash] the payload to attach to the message.
		# @return [PushMessage] self
		def attach(payload = {})
			@payload.merge!(payload)
			return self
		end
	end
end

require_relative 'APNS/ApnsPushMessage'
require_relative 'GCM/GcmPushMessage'