push0r
======
[![Gem Version](https://badge.fury.io/rb/Push0r.svg)](http://badge.fury.io/rb/Push0r)

push0r is a ruby library that makes it easy to send push notifications to iOS, OSX and Android users.

## Installation
Gemfile:
``` ruby
gem 'push0r', '~> 0.6.0'
```

Manual installation:
``` ruby
gem install push0r
```


## Usage
``` ruby
include Push0r

# create a new Push0r instance
instance = Push0r::Base.new

# add a certificate based APNS provider that pushes to iOS and macOS devices using the sandbox environment
provider_cert = APNS::APNSProvider.new(environment: APNS::Environment::SANDBOX, certificate_data: File.read('__pemfile__'))
instance.add_provider(provider_cert, as: :apns_cert)

# add an auth key (JWT) based APNS provider that pushes to iOS and macOS devices using the production environment
provider_jwt = APNS::APNSProvider.new(topic: '__bundleid__', team_id: '__teamid__', key_id: '__keyid__', key_data: File.read('__p8file__'))
instance.add_provider(provider_jwt, as: :apns_jwt)

# add a GCM service provider to push to Android devices
provider_gcm = GCM::GCMProvider.new('__gcm_api_token__')
instance.add_provider(provider_gcm, as: :gcm)

# enqueu a Message to be sent to iOS/macOS using the auth key (JWT) based APNS provider
jwt_message = Message.new(:apns_jwt, '__devicetoken__')
jwt_message.alert(title: 'Hi there', body: 'Sent via jwt auth')
instance.queue(jwt_message)

# enqueu another Message to be sent to iOS/macOS using the certificate based APNS provider
# this message also sets the app's batch and plays a sound
cert_message = Message.new(:apns_jwt, '__devicetoken__')
cert_message.alert(title: 'Hi there', body: 'Sent via certificate auth').sound.batch(2)
instance.queue(cert_message)

# enqueu a gcm message and attach a dummy payload
gcm_message = Message.new(:gcm, '__registration_id__', collapse_key: 'test')
gcm_message.attach({data: {action: 'test'}})
instance.queue(gcm_message)


# flush the queue to actually transmit the messages
instance.flush
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
