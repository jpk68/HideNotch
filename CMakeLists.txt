cmake_minimum_required(VERSION 3.20)

# Must be set before project(); also used for LSMinimumSystemVersion in Info.plist
set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum macOS version")

project(HideNotch VERSION 1.0 LANGUAGES OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(HideNotch MACOSX_BUNDLE
    Source/main.mm
    Source/AppDelegate.mm
    Source/LockScreen.mm
)

target_compile_options(HideNotch PRIVATE $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>)

# Info.plist is a template; ${...} variables in it are filled in by CMake
set_target_properties(HideNotch PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
)

target_link_libraries(HideNotch PRIVATE "-framework Cocoa" "-framework QuartzCore")
