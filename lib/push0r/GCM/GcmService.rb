require 'net/http'

module Push0r
	
	module GcmErrorCodes
		NO_ERROR 				= 0
		UNABLE_TO_PARSE_JSON	= 400
		NOT_AUTHENTICATED 		= 401
		INTERNAL_ERROR			= 500
		INVALID_REGISTRATION	= 1
		UNAVAILABLE				= 2
		NOT_REGISTERED			= 3
		UNKNOWN_ERROR			= 4
		CONNECTION_ERROR		= 5
	end
	
	class GcmService < Service
		def initialize(api_key, sender_id)
			@api_key = api_key
			@sender_id = sender_id
			@messages = []
		end
		
		def can_send?(message)
			return message.is_a?(GcmPushMessage)
		end
		
		def send(message)
			@messages << message
		end
		
		def init_push
			## not used for gcm
		end
		
		def end_push
			failed_messages = []
			new_registration_messages = []
			
			uri = URI.parse("https://android.googleapiss.com/gcm/send")
			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = true

			@messages.each do |message|
				begin
					request = Net::HTTP::Post.new(uri.path, {"Content-Type" => "application/json", "Authorization" => "key=#{@api_key}"})
					request.body = message.attach({"registration_ids" => message.receiver_token}).payload.to_json
					response = http.request(request)
				rescue SocketError => e
					## connection error
					failed_messages << {:error_code => Push0r::GcmErrorCodes::CONNECTION_ERROR, :identifier => message.identifier, :receivers => message.receiver_token}
					next
				end
				
				if response.code.to_i == 200
					json = JSON.parse(response.body)
					
					if json["failure"].to_i > 0 || json["canonical_ids"].to_i > 0
						error_receivers = {}
						
						json["results"].each_with_index do |result,i|
							receiver_token = message.receiver_token[i]
							error = result["error"]
							message_id = result["message_id"]
							registration_id = result["registration_id"]
							
							if message_id && registration_id
								new_registration_messages << {:identifier => message.identifier, :receiver => receiver_token, :new_receiver => registration_id}
							elsif error
								error_code = Push0r::GcmErrorCodes::UNKNOWN_ERROR
								if error == "InvalidRegistration"
									error_code == Push0r::GcmErrorCodes::INVALID_REGISTRATION
								elsif error == "Unavailable"
									error_code == Push0r::GcmErrorCodes::UNAVAILABLE
								elsif error == "NotRegistered"
									error_code == Push0r::GcmErrorCodes::NOT_REGISTERED
								end
								if error_receivers[error_code].nil? then error_receivers[error_code] = [] end
								error_receivers[error_code] << receiver_token
							end
						end
						
						## if there are any receivers with errors: add a hash for every distinct error code and the related receivers to the failed_messages array
						error_receivers.each do |error_code, receivers|
							failed_messages << {:error_code => error_code, :identifier => message.identifier, :receivers => receivers}
						end
					end
				elsif response.code.to_i >= 500 && response.code.to_i <= 599
					failed_messages << {:error_code => Push0r::GcmErrorCodes::INTERNAL_ERROR, :identifier => message.identifier, :receivers => message.receiver_token}
				else
					failed_messages << {:error_code => response.code.to_i, :identifier => message.identifier, :receivers => message.receiver_token}
				end
			end
				
			return [failed_messages, new_registration_messages]
		end
	end
end