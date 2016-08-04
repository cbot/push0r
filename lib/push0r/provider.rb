module Push0r
  class Provider
    # Sends a push message. This is called for every enqueued Message. The provider may create its own internal queue in order to efficiently batch the messages.
    # @param message [Message] the message to be sent
    # @return [void]
    # @abstract
    # @see Message
    def send(message)
      ## empty
    end

    # Called on the provider before the first Message is sent.
    # @return [void]
    # @abstract
    # @see Message
    def init_push
      ## empty
    end

    # Called on the provider after the last Message has been sent. If the provider manages its own internal queue, this is the place to actually transmit all messages.
    # @return [Array(Array<FailedMessage>, Array<NewTokenMessage>)] Failed new RegId Messages
    # @abstract
    # @see Message
    def end_push
      ## empty
      return [[], []]
    end

    # Returns whether this provider supports the delivery to multiple recipients at once
    def supports_multiple_recipients?
      return false
    end
  end
end
