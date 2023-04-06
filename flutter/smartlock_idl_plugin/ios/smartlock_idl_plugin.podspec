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
      '__ACE_INLINE__', 'ACE_AS_STATIC_LIBS', 'TAO_AS_STATIC_LIBS',
      'ACE_HAS_IOS', 'ACE_HAS_CUSTOM_EXPORT_MACROS=0',
      'OPENDDS_SECURITY', 'OPENDDS_RAPIDJSON',
    ],
    ## The paths for headers and libraries are relative for both the example
    ## and the actual flutter smartlock app.
    'HEADER_SEARCH_PATHS' => [
      '$FLUTTER_ROOT/bin/cache/dart-sdk/include',
      '../../../Idl',
      '../../../../Idl',
      '../../../middleware/ACE_TAO/include',
      '../../../../middleware/ACE_TAO/include',
      '../../../middleware/OpenDDS/include',
      '../../../../middleware/OpenDDS/include',
    ],
    'LIBRARY_SEARCH_PATHS'=> [
      '../../../Idl',
      '../../../../Idl',
      '../../../middleware/ACE_TAO/lib',
      '../../../../middleware/ACE_TAO/lib',
      '../../../middleware/OpenDDS/lib',
      '../../../../middleware/OpenDDS/lib',
      '../../../middleware/ios-openssl/lib',
      '../../../../middleware/ios-openssl/lib',
      '../../../middleware/ios-xerces/lib',
      '../../../../middleware/ios-xerces/lib',
    ],
    'OTHER_LDFLAGS' => [
       '-lSmartLock_Idl_Flutter',
       '-lOpenDDS_Dcps',
       '-lOpenDDS_Security',
       '-lOpenDDS_Rtps_Udp',
       '-lOpenDDS_Rtps',
       '-lTAO_AnyTypeCode',
       '-lTAO_Valuetype',
       '-lTAO',
       '-lACE_XML_Utils',
       '-lACE',
       '-lcrypto',
       '-lssl',
       '-lxerces-c',
    ],
    ## Set your IOS_ARCH to x86_64 to build this for the simulator
    ## and to arm64 to build for the iPhone.  Be sure to do a "flutter clean"
    ## if you change this environment variable.
    'ARCHS' => '$IOS_ARCH',
  }
  s.swift_version = '5.0'
end
