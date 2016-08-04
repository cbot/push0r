Gem::Specification.new do |s|
  s.name        = 'Push0r'
  s.version     = '0.6.0'
  s.date        = '2016-08-04'
  s.summary     = 'Push0r gem'
  s.description = 'Library to push messages using APNS and GCM'
  s.authors     = ['Kai Straßmann']
  s.email       = 'derkai@gmail.com'
  s.files       = Dir.glob('{bin,lib}/**/*') + %w(LICENSE README.md)
  s.homepage    = 'https://github.com/cbot/push0r'
  s.license     = 'MIT'

  s.add_runtime_dependency 'net-http2', '~> 0.12.1'
end
