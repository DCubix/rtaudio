# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(rtaudio_library VERSION 0.0.1 LANGUAGES C)

add_library(rtaudio SHARED
  "rtaudio.c"
  "miniaudio.c"
)

set_target_properties(rtaudio PROPERTIES
  PUBLIC_HEADER rtaudio.h
  OUTPUT_NAME "rtaudio"
)

if (WIN32)
  set_target_properties(rtaudio PROPERTIES
    WINDOWS_EXPORT_ALL_SYMBOLS ON
  )
endif (WIN32)

# if platform is Android
if (ANDROID)
  target_link_libraries(rtaudio -llog)
endif (ANDROID)

target_compile_definitions(rtaudio PUBLIC DART_SHARED_LIB)
