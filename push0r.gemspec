Gem::Specification.new do |s|
  s.name        = 'push0r'
  s.version     = '0.6.0.beta.1'
  s.date        = '2017-05-11'
  s.summary     = 'Push0r gem'
  s.description = 'Library to push messages using APNS and FCM'
  s.authors     = ['Kai Straßmann']
  s.email       = 'derkai@gmail.com'
  s.files       = Dir.glob('{bin,lib}/**/*') + %w(LICENSE README.md)
  s.homepage    = 'https://github.com/cbot/push0r'
  s.license     = 'MIT'

  s.add_runtime_dependency 'net-http2', '~> 0.15.0'
  s.add_runtime_dependency 'json_web_token', '~> 0.3.4'
  s.add_runtime_dependency 'openssl', '>= 2.0.3'
end
