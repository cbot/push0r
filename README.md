push0r
======
[![Gem Version](https://badge.fury.io/rb/Push0r.svg)](http://badge.fury.io/rb/Push0r)

push0r is a ruby library that makes it easy to send push notifications to iOS, OSX and Android users.

## Installation
Gemfile for Rails 3, Rails 4, Sinatra, and Merb:
``` ruby
gem 'Push0r', '~> 0.6.0'
```

Manual installation:
``` ruby
gem install Push0r
```


## Usage
``` ruby
include Push0r

# create a new Push0r instance
pusher = Push0r::Base.new

# add a GCM service provider to push to Android devices
pusher.add_provider(GCM::GCMProvider.new('__gcm_api_token__'), as: :gcm)

# add a APNS service provider to push to iOS and macOS devices.
pusher.add_provider(APNS::APNSProvider.new(File.read('aps.pem'), APNS::Environment::SANDBOX), as: :apns_sandbox)
pusher.add_provider(APNS::APNSProvider.new(File.read('aps.pem'), APNS::Environment::PRODUCTION), as: :apns_production)

# queue a gcm message and attach a dummy payload
pusher.queue(Message.new(:gcm, '__registration_id__', collapse_key: 'test').attach({"data" => {"d" => "1"}}))

# queue a apns message and attach a dummy payload
pusher.queue(Message.new(:apns_sandbox, '__device_token__').attach({"data" => {"d" => "1"}}))

# flush the queue to actually transmit the messages
pusher.flush
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
