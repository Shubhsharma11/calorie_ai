#
# No-op iOS pod for the `health` Flutter plugin.
# Android still uses the real Health Connect implementation from pub.dev.
# iOS step tracking uses Core Motion via the `pedometer` plugin only.
#
Pod::Spec.new do |s|
  s.name             = 'health'
  s.version          = '13.3.1'
  s.summary          = 'No-op health plugin for iOS (Health Connect is Android-only).'
  s.description      = <<-DESC
Registers the health plugin channel without linking HealthKit.
                       DESC
  s.homepage         = 'https://pub.dev/packages/health'
  s.license          = { :type => 'MIT' }
  s.author           = { 'MyCaloriePal' => 'support@mycaloriepal.app' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.ios.deployment_target = '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
