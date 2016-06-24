require 'socket'
require 'openssl'
require 'json'

require_relative 'message'
require_relative 'provider'
require_relative 'flush_result'
require_relative 'GCM/gcm_provider'
require_relative 'APNS/apns_provider'

module Push0r
  class Base
    def initialize
      @providers = {}
      @queued_messages = {}
    end

    # @param [Provider] provider the provider that should be added
    # @param [Symbol] as the handle for the provider
    def add_provider(provider, as: nil)
      unless @providers.has_key?(as)
        @providers[as] = provider
      end
    end

    # Adds a Message to the queue
    # @param message [Message] the message to be added to the queue
    # @return [Boolean] true if message was added to the queue (that is: if any of the registered providers can handle the message), otherwise false
    # @see Message
    def queue(message)
      if @providers.has_key?(message.handle) && !message.receiver_tokens.empty?
        if @queued_messages[message.handle].nil?
          @queued_messages[message.handle] = []
        end

        provider = @providers[message.handle]
        if message.receiver_tokens.count > 1 && !provider.supports_multiple_recipients?
          message.split.each do |m|
            @queued_messages[message.handle] << m
          end
        else
          @queued_messages[message.handle] << message
        end

        return true
      else
        return false
      end
    end

    # Flushes the queue by transmitting the enqueued messages using the registered providers
    # @return [FlushResult] the result of the operation
    def flush
      failed_messages = []
      new_token_messages = []

      @queued_messages.each do |provider_handle, messages|
        provider = @providers[provider_handle]
        provider.init_push

        messages.each do |message|
          provider.send(message)
        end

        (failed, new_token) = provider.end_push
        failed_messages += failed
        new_token_messages += new_token
      end

      @queued_messages = {}
      return FlushResult.new(failed_messages, new_token_messages)
    end
  end
end