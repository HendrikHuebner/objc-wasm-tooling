cmake_minimum_required(VERSION 3.21)
project(objc_wasm_mvc_demo LANGUAGES CXX OBJCXX)

find_package(Qt6 REQUIRED COMPONENTS Widgets)

set(OBJC_RUNTIME "" CACHE FILEPATH "Path to the static libobjc2 archive")
set(OBJC_INCLUDE "" CACHE PATH "Path to libobjc2 headers")
set(BASE_INCLUDE "" CACHE PATH "Path to GNUstep Base headers")
set(BASE_ARCHIVE "" CACHE FILEPATH "Path to the static GNUstep Base archive")
set(FFI_INCLUDE "" CACHE PATH "Path to libffi headers")
set(FFI_ARCHIVE "" CACHE FILEPATH "Path to the static libffi archive")

foreach(required OBJC_RUNTIME OBJC_INCLUDE BASE_INCLUDE BASE_ARCHIVE FFI_INCLUDE FFI_ARCHIVE)
    if(NOT ${required})
        message(FATAL_ERROR "${required} must be provided")
    endif()
endforeach()

qt_add_executable(objc-wasm-mvc main.mm)
set_source_files_properties(main.mm PROPERTIES COMPILE_OPTIONS
    "-fobjc-runtime=gnustep-2.0;-fconstant-string-class=NXConstantString")
target_include_directories(objc-wasm-mvc PRIVATE
    "${OBJC_INCLUDE}"
    "${BASE_INCLUDE}"
    "${BASE_INCLUDE}/Foundation"
    "${FFI_INCLUDE}")
target_compile_options(objc-wasm-mvc PRIVATE
    -fwasm-exceptions
    -sWASM_LEGACY_EXCEPTIONS=0
    -sSUPPORT_LONGJMP=wasm)
target_link_options(objc-wasm-mvc PRIVATE
    -fwasm-exceptions
    -sWASM_LEGACY_EXCEPTIONS=0
    -sSUPPORT_LONGJMP=wasm
    -sALLOW_MEMORY_GROWTH=1
    -Wl,--stack-first
    "-Wl,--whole-archive" "${BASE_ARCHIVE}" "-Wl,--no-whole-archive"
    "${OBJC_RUNTIME}" "${FFI_ARCHIVE}")
target_link_libraries(objc-wasm-mvc PRIVATE Qt6::Widgets)
