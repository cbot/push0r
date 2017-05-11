require 'net/http'

module Push0r
  module FCM
    # A module that contains constants for Firebase Cloud Messaging error codes
    module ErrorCodes
      UNKNOWN_ERROR = 1
      INVALID_REGISTRATION = 2
      UNAVAILABLE = 3
      NOT_REGISTERED = 4
      MISMATCH_SENDER_ID = 5
      MISSING_REGISTRATION = 6
      MESSAGE_TOO_BIG = 7
      INVALID_DATA_KEY = 8
      INVALID_TTL = 9
      INVALID_PACKAGE_NAME = 10
      CONNECTION_ERROR = 11
      UNABLE_TO_PARSE_JSON = 400
      NOT_AUTHENTICATED = 401
      INTERNAL_ERROR = 500
    end

    class FCMProvider < Provider
      # @param api_key [String] the FCM server key obtained from the Firebase Console
      def initialize(api_key)
        @api_key = api_key
        @messages = []
      end

      def supports_multiple_recipients?
        true
      end

      # @see Service#send
      def send(message)
        @messages << message
      end

      # @see Service#init_push
      def init_push
        ## not used for fcm
      end

      # @see Service#end_push
      def end_push
        failed_messages = []
        new_registration_messages = []

        uri = URI.parse('https://fcm.googleapis.com/fcm/send')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        @messages.each do |message|
          if message.time_to_live && message.time_to_live.to_i >= 0
            message.attach({time_to_live: time_to_live.to_i})
          end

          begin
            request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/json', 'Authorization' => "key=#{@api_key}"})

            payload = {data: message.payload, notification: build_notification_hash(message)}

            if message.receiver_tokens.count == 1
              payload.merge!({to: message.receiver_tokens.first})
            else
              payload.merge!({registration_ids: message.receiver_tokens})
            end

            if message.collapse_key && !message.collapse_key.empty?
              payload.merge!({collapse_key: message.collapse_key})
            end

            request.body = payload.to_json
            response = http.request(request)
          rescue SocketError
            ## connection error
            failed_messages << FailedMessage.new(ErrorCodes::CONNECTION_ERROR, message.receiver_tokens, message, self)
            next
          end

          if response.code.to_i == 200
            json = JSON.parse(response.body)

            if json['failure'].to_i > 0 || json['canonical_ids'].to_i > 0
              error_receivers = {}

              json['results'].each_with_index do |result, i|
                receiver_token = message.receiver_tokens[i]
                error = result['error']
                message_id = result['message_id']
                registration_id = result['registration_id']

                if message_id && registration_id
                  new_registration_messages << NewTokenMessage.new(receiver_token, registration_id, message, self)
                elsif error
                  error_code = ErrorCodes::UNKNOWN_ERROR
                  if error == 'InvalidRegistration'
                    error_code = ErrorCodes::INVALID_REGISTRATION
                  elsif error == 'Unavailable'
                    error_code = ErrorCodes::UNAVAILABLE
                  elsif error == 'NotRegistered'
                    error_code = ErrorCodes::NOT_REGISTERED
                  elsif error == 'MismatchSenderId'
                    error_code = ErrorCodes::MISMATCH_SENDER_ID
                  elsif error == 'MissingRegistration'
                    error_code = ErrorCodes::MISSING_REGISTRATION
                  elsif error == 'MessageTooBig'
                    error_code = ErrorCodes::MESSAGE_TOO_BIG
                  elsif error == 'InvalidDataKey'
                    error_code = ErrorCodes::INVALID_DATA_KEY
                  elsif error == 'InvalidTtl'
                    error_code = ErrorCodes::INVALID_TTL
                  elsif error == 'InvalidPackageName'
                    error_code = ErrorCodes::INVALID_PACKAGE_NAME
                  end
                  if error_receivers[error_code].nil?
                    error_receivers[error_code] = []
                  end
                  error_receivers[error_code] << receiver_token
                end
              end

              ## if there are any receivers with errors: add a hash for every distinct error code and the related receivers to the failed_messages array
              error_receivers.each do |error_code, receivers|
                failed_messages << FailedMessage.new(error_code, receivers, message, self)
              end
            end
          elsif response.code.to_i >= 500 && response.code.to_i <= 599
            failed_messages << FailedMessage.new(ErrorCodes::INTERNAL_ERROR, message.receiver_tokens, message, self)
          else
            failed_messages << FailedMessage.new(response.code.to_i, message.receiver_tokens, message, self)
          end
        end

        @messages = [] ## reset
        [failed_messages, new_registration_messages]
      end

      private
      # @param [Push0r::Message] message
      def build_notification_hash(message)
        hash = {}
        hash[:title] = message.alert_title unless message.alert_title.nil?
        hash[:body] = message.alert_body unless message.alert_body.nil?
        hash[:sound] = message.sound_name
        hash[:color] = message.color_name unless message.color_name.nil?
        hash[:icon] = message.icon_name unless message.icon_name.nil?
        hash[:tag] = message.tag_name unless message.tag_name.nil?
        hash[:click_action] = message.click_action_name unless message.click_action_name.nil?

        hash
      end
    end
  end
end
