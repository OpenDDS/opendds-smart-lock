# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(smartlock_idl_plugin_library VERSION 0.0.1 LANGUAGES CXX C)

set(ACE_ROOT ../../middleware/ACE_TAO/include)
set(DDS_ROOT ../../middleware/OpenDDS/include)
string(REGEX REPLACE "\\\\" "/" FLUTTER_ROOT $ENV{FLUTTER_ROOT})

set(TARGET smartlock_idl_plugin)

add_library(${TARGET} SHARED
  "${FLUTTER_ROOT}/bin/cache/dart-sdk/include/dart_api_dl.c"
  "smartlock_idl_plugin.cpp"
)

set_target_properties(${TARGET} PROPERTIES
  PUBLIC_HEADER smartlock_idl_plugin.h
  OUTPUT_NAME "smartlock_idl_plugin"
)

target_compile_definitions(${TARGET} PUBLIC DART_SHARED_LIB)

target_include_directories(${TARGET} PRIVATE
                           "${FLUTTER_ROOT}/bin/cache/dart-sdk/include"
                           ../../Idl
                           "${ACE_ROOT}" "${DDS_ROOT}")

target_compile_definitions(${TARGET} PUBLIC __ACE_INLINE__ OPENDDS_SECURITY)
target_link_directories(${TARGET} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../android/src/main/jniLibs/${ANDROID_ABI})
target_link_libraries(${TARGET} SmartLock_Idl_Flutter OpenDDS_Security OpenDDS_Rtps_Udp OpenDDS_Rtps OpenDDS_Dcps TAO_Valuetype TAO ACE_XML_Utils ACE)
