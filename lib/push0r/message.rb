module Push0r
  # A Message encapsulates values like the notification's payload, its receiver, etc.
  # @abstract
  # @attr_reader [Hash] payload the payload for this push message
  # @attr_reader [Integer] identifier the unique identifier for this push message
  # @attr_reader [Array] receiver_tokens the receiver's push tokens
  # @attr_reader [Integer] time_to_live the time to live in seconds for this push message
  # @attr_reader [String] collapse_key a collapse key for the message
  # @attr_reader [Object] handle the provider handle which indentifies the Provider that shall send this message

  class Message
    attr_reader :handle, :payload, :identifier, :receiver_tokens, :time_to_live, :collapse_key, :priority
    attr_reader :alert_title, :alert_body, :alert_subtitle, :sound_name, :badge_value, :content_available_set, :mutable_content_set, :category_name, :color_name, :icon_name, :tag_name, :click_action_name

    # Creates a new Message instance
    # @param receiver_tokens [String, Array] the receiver's push tokens
    # @param identifier [Integer] a unique identifier to identify this push message during error handling. If nil, a random identifier is automatically generated.
    # @param time_to_live [Integer] The time to live in seconds for this push messages. If nil, the time to live depends on the provider used to transmit the message.
    # @param [Object] handle the provider handle which indentifies the Provider that shall send this message
    # @param [String] collapse_key a collapse key for the message
    def initialize(handle, receiver_tokens, collapse_key: nil, identifier: nil, time_to_live: nil, priority: nil)
      @handle = handle
      @receiver_tokens = Array(receiver_tokens).uniq
      @identifier = identifier
      @time_to_live = time_to_live
      @collapse_key = collapse_key
      @priority = priority
      @payload = {}
    end

    # Attaches the given payload to the message.
    # @note attaching is done using the merge! method of the Hash class, i.e. be careful not to overwrite previously set Hash keys.
    # @param payload [Hash] the payload to attach to the message.
    # @return [self] self
    def attach(payload = {})
      @payload.merge!(payload)

      self
    end

    # Convenience method that adds the required fields for an alert push
    # subtitle is only available on APNS
    # @param [String] title the alert title to be displayed
    # @param [String] subtitle the alert subtitle to be displayed
    # @param [String] body the alert text to be displayed
    # @return [self] self
    def alert(title: nil, subtitle: nil, body: nil)
      @alert_title = title
      @alert_subtitle = subtitle
      @alert_body = body

      self
    end

    # Convenience method that adds the required field for a sound push
    # @param [String] sound_name the sound to be played
    # @return [self] self
    def sound(sound_name = 'default')
      @sound_name = sound_name

      self
    end

    # Convenience method that adds the required field for a badge change
    # Only for APNS
    # @param [Integer] badge the badge value to be displayed
    # @return [self] self
    def badge(badge = 0)
      @badge_value = badge

      self
    end

    # Convenience method that adds the category field to the aps dictionary
    # Only for APNS
    # @param [String] category the category this message belongs to (see UIUserNotificationCategory in apple's documentation)
    # @return [self] self
    def category(category)
      @category_name = category

      self
    end

    # Sets the mutable-content flag
    # Only for APNS
    # @return [self] self
    def mutable_content
      @mutable_content_set = true

      self
    end

    # Sets the content-available flag
    # Only for APNS
    # @return [self] self
    def content_available
      @content_available_set = true

      self
    end

    # Only for FCM
    # @return [self] self
    def icon(icon)
      @icon_name = icon

      self
    end

    # Only for FCM
    # @return [self] self
    def color(color)
      @color_name = color

      self
    end

    # Only for FCM
    # @return [self] self
    def tag(tag)
      @tag_name = tag

      self
    end

    # Only for FCM
    # @return [self] self
    def click_action(click_action)
      @click_action_name = click_action

      self
    end

    # Converts a message that is directed to multiple recipients into an array of messages to a single recipient
    # This is used for providers that do not support the transmission of messages to multiple recipients at once
    # @return [Array<Message>]
    def split
      return receiver_tokens.map do |token|
        Message.new(@handle, token, @collapse_key, @identifier, @time_to_live).attach(@payload)
      end
    end
  end
end
