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
    attr_reader :handle, :payload, :identifier, :receiver_tokens, :time_to_live, :collapse_key

    # Creates a new Message instance
    # @param receiver_tokens [String, Array] the receiver's push tokens
    # @param identifier [Integer] a unique identifier to identify this push message during error handling. If nil, a random identifier is automatically generated.
    # @param time_to_live [Integer] The time to live in seconds for this push messages. If nil, the time to live depends on the provider used to transmit the message.
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

      self
    end

    # Convenience method that adds the required fields for an alert push
    # @param [String] title the alert title to be displayed
    # @param [String] subtitle the alert subtitle to be displayed
    # @param [String] body the alert text to be displayed
    # @return [self] self
    def alert(title: nil, subtitle: nil, body: nil)
      if title || subtitle || body
        ensure_structure(:aps, :alert)

        payload[:aps][:alert][:title] = title if title
        payload[:aps][:alert][:subtitle] = subtitle if subtitle
        payload[:aps][:alert][:body] = body if body
      end

      self
    end

    # Convenience method that adds the required field for a sound push
    # @param [String] sound_name the sound to be played
    # @return [self] self
    def sound(sound_name = 'default')
      if sound_name
        ensure_structure(:aps)
        payload[:aps][:sound] = sound_name
      end

      self
    end

    # Convenience method that adds the required field for a badge change
    # @param [Integer] badge the badge value to be displayed
    # @return [self] self
    def badge(badge = 0)
      if badge
        ensure_structure(:aps)
        payload[:aps][:badge] = badge.to_i
      end

      self
    end

    # Convenience method that adds the category field to the aps dictionary
    # @param [String] category the category this message belongs to (see UIUserNotificationCategory in apple's documentation)
    # @return [self] self
    def category(category)
      if category
        ensure_structure(:aps)
        payload[:aps][:category] = category
      end

      self
    end

    # Sets the mutable-content flag
    # @return [self] self
    def mutable_content
      ensure_structure(:aps)
      payload[:aps][:'mutable-content'] = true

      self
    end

    # Sets the content-available flag
    # @return [self] self
    def content_available
      ensure_structure(:aps)
      payload[:aps][:'content-available'] = true

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

    private
    def ensure_structure(*args)
      current_hash = payload

      args.each do |arg|
        if current_hash[arg].nil?
          current_hash[arg] = {}
        end
        current_hash = current_hash[arg]
      end
    end
  end
end
