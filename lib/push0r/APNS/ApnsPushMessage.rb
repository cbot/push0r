require 'SecureRandom'

module Push0r
  # ApnsPushMessage is a {PushMessage} implementation that encapsulates a single push notification to be sent to a single user.
  class ApnsPushMessage < PushMessage
    attr_reader :environment
    attr_reader :collapse_key

    # Returns a new ApnsPushMessage instance that encapsulates a single push notification to be sent to a single user.
    # @param [String] receiver_token the apns push token (aka device token) to push the notification to
    # @param [Fixnum] environment the environment to use when sending this push message. Defaults to ApnsEnvironment::PRODUCTION.
    # @param [Fixnum] identifier a unique identifier to identify this push message during error handling. If nil, a random identifier is automatically generated.
    # @param [Fixnum] time_to_live The time to live in seconds for this push messages. If nil, the time to live is set to two weeks.
    # @param [String] collapse_key a collapse key to transmit to APNS
    def initialize(receiver_token, environment = ApnsEnvironment::PRODUCTION, identifier: nil, time_to_live: nil, collapse_key: nil)
      if identifier.nil? ## make sure the message has an identifier
        identifier = SecureRandom.uuid
      end
      super(receiver_token, identifier, time_to_live)
      @environment = environment
      @collapse_key = collapse_key
    end

    # Convenience method to attach common data (that is an alert, a sound or a badge value) to this message's payload.
    # @param [String] title the alert title to be displayed
    # @param [String] subtitle the alert subtitle to be displayed
    # @param [String] body the alert text to be displayed
    # @param [String] sound the sound to be played
    # @param [Fixnum] badge the badge value to be displayed
    # @param [String] category the category this message belongs to (see UIUserNotificationCategory in apple's documentation)
    # @return [ApnsPushMessage] returns self
    # @param [Boolean] mutable_content whether to set the mutable-content flag
    # @param [Boolean] content_available whether to set the content-available flag
    def simple(title: nil, subtitle: nil, body: nil, sound: nil, badge: nil, category: nil, mutable_content: nil, content_available: nil)
      new_payload = {aps: {}}
      if title || subtitle || body
        alert = {}
        alert[:title] = title if title
        alert[:subtitle] = subtitle if subtitle
        alert[:body] = body if body
        new_payload[:aps][:alert] = alert
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
      if mutable_content
        new_payload[:aps][:'mutable-content'] = 1
      end
      if content_available
        new_payload[:aps][:'content-available'] = 1
      end

      payload.merge!(new_payload)

      self
    end
  end
end