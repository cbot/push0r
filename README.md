push0r
======
[![Gem Version](https://badge.fury.io/rb/Push0r.svg)](http://badge.fury.io/rb/Push0r)

push0r is a ruby library that makes it easy to send push notifications to iOS, OSX and Android users.

## Installation
Gemfile for Rails 3, Rails 4, Sinatra, and Merb:
``` ruby
gem 'Push0r', '~> 0.5.3'
```

Manual installation:
``` ruby
gem install Push0r
```


## Usage
``` ruby
# create a new queue
queue = Push0r::Queue.new

# create the GcmService to push to Android devices and register it with our queue.
gcm_service = Push0r::GcmService.new("__gcm_api_token__")
queue.register_service(gcm_service)

# create ApnsService instances to push to iOS and OSX devices and register them with our queue.
apns_service_production = Push0r::ApnsService.new(File.read("aps_production.pem"), Push0r::ApnsEnvironment::PRODUCTION)
apns_service_sandbox = Push0r::ApnsService.new(File.read("aps_development.pem"), Push0r::ApnsEnvironment::SANDBOX)
queue.register_service(apns_service_production)
queue.register_service(apns_service_sandbox)

# create a GcmPushMessage and attach a dummy payload
gcm_message = Push0r::GcmPushMessage.new("__registration_id__")
gcm_message.attach({"data" => {"d" => "1"}})

# create a ApnsPushMessage to be sent via the Sandbox apns service and attach a dummy payload
apns_message = Push0r::ApnsPushMessage.new("__device_token__", Push0r::ApnsEnvironment::SANDBOX)
apns_message.attach({"data" => {"v" => "1"}}

# add both messages to the queue
queue.add(gcm_message)
queue.add(apns_message)

# flush the queue to actually transmit the messages
queue.flush
```

## Documentation
Push0r API documentation can be found [here][apidocs].

## Error handling
[Queue#flush][flush] returns an instance of [FlushResult][flushresult] which can be queried for [failed_messages][failed_messages]. This returns an array of [FailedMessage][failed_message] instances which in turn offer various attributes like the error code for the failed notification.

## Bugs
Please [report bugs][issues] on GitHub.

[issues]: https://github.com/cbot/push0r/issues
[apidocs]: http://rubydoc.info/gems/Push0r/frames
[flush]: http://rubydoc.info/gems/Push0r/Push0r/Queue#flush-instance_method
[flushresult]: http://rubydoc.info/gems/Push0r/Push0r/FlushResult
[failed_messages]: http://rubydoc.info/gems/Push0r/Push0r/FlushResult#failed_messages-instance_method
[failed_message]: http://rubydoc.info/gems/Push0r/Push0r/FailedMessage
