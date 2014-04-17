class Push0r::PushMessage
	def initialize(pushdata)
		@pushdata = pushdata
	end
	
	def send(receiver_token, payload = {}, identifier = nil)
	end	
	
	def send_simple(receiver_token, alert_text = nil, sound = nil, badge = nil, identifier = nil)
	end
end

require './push0r/APNS/ApnsPushMessage.rb'
require './push0r/GCM/GcmPushMessage.rb'