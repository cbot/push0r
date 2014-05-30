push0r
======

push0r is a ruby library that makes it easy to send push notifications to iOS, OSX and Android users.

## Installation
Gemfile for Rails 3, Rails 4, Sinatra, and Merb:
``` ruby
gem 'push0r', '~> 0.3.0'
```

Manual installation:
``` ruby
gem install push0r
```


## Usage
``` ruby
# create a new queue
queue = Push0r::Queue.new

# create the GcmService to push to Android devices and register it with our queue.
gcm_service = Push0r::GcmService.new("__gcm_api_token__")
queue.register_service(gcm_service)

# create the ApnsService to push to iOS and OSX devices and register it with our queue.
apns_service = Push0r::ApnsService.new(File.read("aps.pem"), true)
queue.register_service(apns_service)

# create a GcmPushMessage and attach a dummy payload
gcm_message = Push0r::GcmPushMessage.new("__registration_id__")
gcm_message.attach({"data" => {"d" => "1"}})

# create a ApnsPushMessage and attach a dummy payload
apns_message = Push0r::ApnsPushMessage.new("__device_token__")
apns_message.attach({"data" => {"v" => "1"}}

# add both messages to the queue
queue.add(gcm_message)
queue.add(apns_message)

# flush the queue to actually transmit the messages
queue.flush
```

Please [report bugs][issues] on GitHub.

[issues]: https://github.com/cbot/push0r/issues
