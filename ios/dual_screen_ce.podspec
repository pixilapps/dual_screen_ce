Pod::Spec.new do |s|
  s.name             = 'dual_screen_ce'
  s.version          = '1.1.0'
  s.summary          = 'Hinge, fold, reserved regions and the vertical bar on iPhone Duo.'
  s.description      = <<-DESC
iPhone Duo support for dual_screen_ce: hinge status and angle, fold and camera reserved regions,
size classes, and the system vertical bar edge and region, bridged to Flutter.
                       DESC
  s.homepage         = 'https://github.com/pixilapps/dual_screen_ce'
  s.license          = { :file => '../LICENSE' }
  s.authors          = 'Pixil Apps'
  s.source           = { :path => '.' }
  s.source_files     = 'dual_screen_ce/Sources/dual_screen_ce/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
