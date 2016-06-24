module Push0r
  # A Message encapsulates values like the notification's payload, its receiver, etc.
  # @abstract
  # @attr_reader [Hash] payload the payload for this push message
  # @attr_reader [Fixnum] identifier the unique identifier for this push message
  # @attr_reader [Array] receiver_tokens the receiver's push tokens
  # @attr_reader [Fixnum] time_to_live the time to live in seconds for this push message
  # @attr_reader [String] collapse_key a collapse key for the message
  # @attr_reader [Object] handle the provider handle which indentifies the Provider that shall send this message
  class Message
    attr_reader :handle, :payload, :identifier, :receiver_tokens, :time_to_live, :collapse_key

    # Creates a new Message instance
    # @param receiver_tokens [String, Array] the receiver's push tokens
    # @param identifier [Fixnum] a unique identifier to identify this push message during error handling. If nil, a random identifier is automatically generated.
    # @param time_to_live [Fixnum] The time to live in seconds for this push messages. If nil, the time to live depends on the provider used to transmit the message.
    # @param [Object] handle the provider handle which indentifies the Provider that shall send this message
    # @param [String] collapse_key a collapse key for the message
    def initialize(handle, receiver_tokens, collapse_key: nil, identifier: nil, time_to_live: nil)
      @handle = handle
      @receiver_tokens = Array(receiver_tokens).uniq
      @identifier = identifier
      @time_to_live = time_to_live
      @collapse_key = collapse_key
      @payload = {}
    end

    # Attaches the given payload to the message.
    # @note attaching is done using the merge! method of the Hash class, i.e. be careful not to overwrite previously set Hash keys.
    # @param payload [Hash] the payload to attach to the message.
    # @return [self] self
    def attach(payload = {})
      @payload.merge!(payload)
      return self
    end

    # Convenience method to attach common data to this message's payload.
    # @param [String] title the alert title to be displayed
    # @param [String] subtitle the alert subtitle to be displayed
    # @param [String] body the alert text to be displayed
    # @param [String] sound the sound to be played
    # @param [Fixnum] badge the badge value to be displayed
    # @param [String] category the category this message belongs to (see UIUserNotificationCategory in apple's documentation)
    # @return [Message] returns self
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
