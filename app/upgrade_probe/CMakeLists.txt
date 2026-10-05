cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

project(upgrade_probe)

if(NOT DEFINED APP_VERSION)
  set(APP_VERSION 1)
endif()

target_sources(app PRIVATE src/main.c)

target_compile_definitions(app PRIVATE APP_VERSION=${APP_VERSION})

target_include_directories(app PRIVATE
  $<TARGET_PROPERTY:tfm,TFM_BINARY_DIR>/api_ns/interface/include
)
