cmake_minimum_required(VERSION 3.20)

# Must be set before project(); also used for LSMinimumSystemVersion in Info.plist
set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum macOS version")

project(HideNotch VERSION 1.0 LANGUAGES OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Compile the Icon Composer icon into Assets.car (+ .icns fallback for pre-Tahoe)
find_program(XCRUN xcrun REQUIRED)
set(ICON_SRC "${CMAKE_CURRENT_SOURCE_DIR}/Resources/HideNotch.icon")
set(ICON_OUT "${CMAKE_CURRENT_BINARY_DIR}/icon")
set(ICON_OUTPUTS "${ICON_OUT}/Assets.car" "${ICON_OUT}/HideNotch.icns")
file(GLOB_RECURSE ICON_INPUTS CONFIGURE_DEPENDS "${ICON_SRC}/*")

add_custom_command(
    OUTPUT ${ICON_OUTPUTS}
    COMMAND ${CMAKE_COMMAND} -E make_directory "${ICON_OUT}"
    COMMAND ${XCRUN} actool "${ICON_SRC}"
        --compile "${ICON_OUT}"
        --output-partial-info-plist "${ICON_OUT}/partial.plist"
        --app-icon HideNotch
        --platform macosx
        --target-device mac
        --minimum-deployment-target ${CMAKE_OSX_DEPLOYMENT_TARGET}
        --output-format human-readable-text --warnings --errors
    DEPENDS ${ICON_INPUTS}
    COMMENT "Compiling app icon"
    VERBATIM
)
set_source_files_properties(${ICON_OUTPUTS} PROPERTIES
    GENERATED TRUE
    MACOSX_PACKAGE_LOCATION Resources
)

add_executable(HideNotch MACOSX_BUNDLE
    Source/main.mm
    Source/AppDelegate.mm
    Source/LockScreen.mm
    ${ICON_OUTPUTS}
)

target_compile_options(HideNotch PRIVATE $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>)

# Info.plist is a template; ${...} variables in it are filled in by CMake
set_target_properties(HideNotch PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist"
)

target_link_libraries(HideNotch PRIVATE "-framework Cocoa" "-framework QuartzCore")
