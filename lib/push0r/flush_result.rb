module Push0r
  # FlushResult models the result of a single flushing process.
  class FlushResult
    attr_reader :failed_messages
    attr_reader :new_token_messages

    def initialize(failed_message, new_token_messages)
      @failed_messages = failed_message
      @new_token_messages = new_token_messages
    end

    def to_s
      "FlushResult - Failed: #{@failed_messages.count} NewToken: #{@new_token_messages.count}"
    end
  end

  class FailedMessage
    attr_reader :error_code
    attr_reader :receivers
    attr_reader :message
    attr_reader :provider

    def initialize(error_code, receivers, message, provider)
      @error_code = error_code
      @receivers = receivers
      @message = message
      @provider = provider
    end

    def to_s
      "FailedMessage: errorCode: #{@error_code} receivers: #{@receivers.inspect}"
    end
  end

  class NewTokenMessage
    attr_reader :message
    attr_reader :token
    attr_reader :new_token
    attr_reader :provider

    def initialize(token, new_token, message, provider)
      @token = token
      @new_token = new_token
      @message = message
      @provider = provider
    end

    def to_s
      "NewTokenMessage: oldToken: #{@token} newToken: #{@new_token}"
    end
  end
end
