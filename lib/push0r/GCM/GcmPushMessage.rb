module Push0r
  # GcmPushMessage is a {PushMessage} implementation that encapsulates a single push notification to be sent to a single or multiple users.
  class GcmPushMessage < PushMessage

    # Returns a new GcmPushMessage instance that encapsulates a single push notification to be sent to a single or multiple users.
    # @param receiver_token [Array<String>] the apns push tokens (aka registration ids) to push the notification to
    # @param identifier [Fixnum] a unique identifier to identify this push message during error handling. If nil, a random identifier is automatically generated.
    # @param time_to_live [Fixnum] The time to live in seconds for this push messages. If nil, the time to live is set to four weeks.
    def initialize(receiver_token, identifier = nil, time_to_live = nil)
      if identifier.nil? ## make sure the message has an identifier
        identifier = Random.rand(2**32)
      end

      # for GCM the receiver_token is an array, so make sure we convert a single string to an array containing that string :-)
      if receiver_token.is_a?(String)
        receiver_token = [receiver_token]
      end

      super(receiver_token, identifier, time_to_live)

      if time_to_live && time_to_live.to_i >= 0
        self.attach({'time_to_live' => time_to_live.to_i})
      end
    end
  end
end

