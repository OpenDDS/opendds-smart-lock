#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint smartlock_idl_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'smartlock_idl_plugin'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS' => [
      '__ACE_INLINE__', 'OPENDDS_SECURITY',
      'OPENDDS_RAPIDJSON', 'ACE_AS_STATIC_LIBS', 'TAO_AS_STATIC_LIBS',
      'ACE_HAS_IOS', 'ACE_HAS_CUSTOM_EXPORT_MACROS=0'
    ],
    'HEADER_SEARCH_PATHS' => [
      '/Users/taoadmin/Development/flutter/bin/cache/dart-sdk/include',
      '../../../../Idl',
      '../../../../middleware/ACE_TAO/include',
      '../../../../middleware/OpenDDS/include'
    ],
    'LIBRARY_SEARCH_PATHS'=> [
      '../../../../Idl',
      '../../../../middleware/ACE_TAO/lib',
      '../../../../middleware/OpenDDS/lib',
    ],
    'OTHER_LDFLAGS' => [
       '../../../../Idl/libSmartLock_Idl_Flutter.a',
       '../../../../middleware/OpenDDS/lib/libOpenDDS_Dcps.a',
       '../../../../middleware/OpenDDS/lib/libOpenDDS_Security.a',
       '../../../../middleware/OpenDDS/lib/libOpenDDS_Rtps_Udp.a',
       '../../../../middleware/OpenDDS/lib/libOpenDDS_Rtps.a',
       '../../../../middleware/ACE_TAO/lib/libTAO_AnyTypeCode.a',
       '../../../../middleware/ACE_TAO/lib/libTAO_Valuetype.a',
       '../../../../middleware/ACE_TAO/lib/libTAO.a',
       '../../../../middleware/ACE_TAO/lib/libACE_XML_Utils.a',
       '../../../../middleware/ACE_TAO/lib/libACE.a',
       '../../../../middleware/ios-openssl/lib/libcrypto.a',
       '../../../../middleware/ios-openssl/lib/libssl.a',
       '../../../../middleware/ios-xerces3/lib/libxerces-c.a',
    ],
    'ARCHS' => 'x86_64'
  }
  s.swift_version = '5.0'
end
