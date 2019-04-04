Gem::Specification.new do |s|
  s.name        = 'Push0r'
  s.version     = '0.5.3'
  s.date        = '2019-04-04'
  s.summary     = 'Push0r gem'
  s.description = 'Library to push messages using APNS and FCM'
  s.authors     = ['Kai Straßmann']
  s.email       = 'derkai@gmail.com'
  s.files       = %w(lib/push0r.rb lib/push0r/FlushResult.rb lib/push0r/Queue.rb lib/push0r/PushMessage.rb lib/push0r/Service.rb lib/push0r/APNS/ApnsService.rb lib/push0r/APNS/ApnsPushMessage.rb lib/push0r/GCM/GcmService.rb lib/push0r/GCM/GcmPushMessage.rb)
  s.homepage    = 'https://github.com/cbot/push0r'
  s.license     = 'MIT'
end
