class Push0r::Service
	def push(&block)
		self.init_push
		block.call(self.push_message_object)
		self.end_push
	end
	
	private
	def init_push
	end
	
	def push_message_object	
	end
	
	def end_push
	end
end

require './push0r/APNS/ApnsService.rb'
require './push0r/GCM/GcmService.rb'