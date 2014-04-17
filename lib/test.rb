require './push0r.rb'

service = Push0r::ApnsService.new(File.read("aps.pem"), true)

service.push do |p|
	p.send_simple("f8453450 60fe19b0 f801be51 6242dbfe 2a065b16 1c3b3c88 dbf92557 77186529", "Alert 2!", "default")
end