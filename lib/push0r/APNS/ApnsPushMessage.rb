module Push0r
  # ApnsPushMessage is a {PushMessage} implementation that encapsulates a single push notification to be sent to a single user.
  class ApnsPushMessage < PushMessage
    attr_reader :environment

    # Returns a new ApnsPushMessage instance that encapsulates a single push notification to be sent to a single user.
    # @param receiver_token [String] the apns push token (aka device token) to push the notification to
    # @param environment [Fixnum] the environment to use when sending this push message. Defaults to ApnsEnvironment::PRODUCTION.
    # @param identifier [Fixnum] a unique identifier to identify this push message during error handling. If nil, a random identifier is automatically generated.
    # @param time_to_live [Fixnum] The time to live in seconds for this push messages. If nil, the time to live is set to zero seconds.
    def initialize(receiver_token, environment = ApnsEnvironment::PRODUCTION, identifier = nil, time_to_live = nil)
      if identifier.nil? ## make sure the message has an identifier (required for apns error handling)
        identifier = Random.rand(2**32)
      end
      super(receiver_token, identifier, time_to_live)
      @environment = environment
    end

    # Convenience method to attach common data (that is an alert, a sound or a badge value) to this message's payload.
    # @param alert_text [String] the alert text to be displayed
    # @param sound [String] the sound to be played
    # @param badge [Fixnum] the badge value to be displayed
    # @param category [String] the category this message belongs to (see UIUserNotificationCategory in apple's documentation)
    def simple(alert_text = nil, sound = nil, badge = nil, category = nil)
      new_payload = {aps: {}}
      if alert_text
        new_payload[:aps][:alert] = alert_text
      end
      if sound
        new_payload[:aps][:sound] = sound
      end
      if badge
        new_payload[:aps][:badge] = badge
      end
      if category
        new_payload[:aps][:category] = category
      end

      @payload.merge!(new_payload)

      return self
    end
  end
end