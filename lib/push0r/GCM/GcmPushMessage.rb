module Push0r
	class GcmPushMessage < PushMessage
		def initialize(receiver_token, identifier = nil)
			if identifier.nil? ## make sure the message has an identifier
				identifier = Random.rand(2**32)
			end
			
			# for GCM the receiver_token is an array, so make sure we convert a single string to an array containing that string :-)
			if receiver_token.is_a?(String)
				receiver_token = [receiver_token]
			end
			
			super(receiver_token, identifier)
		end
	end
end

