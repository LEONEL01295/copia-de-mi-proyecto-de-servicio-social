# Project-level configuration.
cmake_minimum_required(VERSION 3.14)

project(analytics_dashboard LANGUAGES CXX)

# ============================================================
# COMPATIBILIDAD CON WEBVIEW_WINDOWS Y MSVC RECIENTE
# ============================================================

# webview_windows 0.4.0 utiliza <experimental/coroutine>.
# Visual Studio 2026 / MSVC 14.51 lo trata como error.
if(MSVC)
  add_compile_definitions(
    _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
  )
endif()

# El plugin webview_windows utiliza una forma antigua de
# add_custom_command con DEPENDS. Se conserva el comportamiento
# anterior para evitar la advertencia CMP0175.
if(POLICY CMP0175)
  cmake_policy(SET CMP0175 OLD)
endif()

# The name of the executable created for the application.
set(BINARY_NAME "analytics_dashboard")

# Explicitly opt in to modern CMake behaviors.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(
  IS_MULTICONFIG
  GLOBAL
  PROPERTY GENERATOR_IS_MULTI_CONFIG
)

if(IS_MULTICONFIG)
  set(
    CMAKE_CONFIGURATION_TYPES
    "Debug;Profile;Release"
    CACHE STRING ""
    FORCE
  )
else()
  if(NOT CMAKE_BUILD_TYPE AND
     NOT CMAKE_CONFIGURATION_TYPES)

    set(
      CMAKE_BUILD_TYPE
      "Debug"
      CACHE STRING
      "Flutter build mode"
      FORCE
    )

    set_property(
      CACHE CMAKE_BUILD_TYPE
      PROPERTY STRINGS
      "Debug"
      "Profile"
      "Release"
    )
  endif()
endif()

# Define settings for the Profile build mode.
set(
  CMAKE_EXE_LINKER_FLAGS_PROFILE
  "${CMAKE_EXE_LINKER_FLAGS_RELEASE}"
)

set(
  CMAKE_SHARED_LINKER_FLAGS_PROFILE
  "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}"
)

set(
  CMAKE_C_FLAGS_PROFILE
  "${CMAKE_C_FLAGS_RELEASE}"
)

set(
  CMAKE_CXX_FLAGS_PROFILE
  "${CMAKE_CXX_FLAGS_RELEASE}"
)

# Use Unicode for all projects.
add_definitions(
  -DUNICODE
  -D_UNICODE
)

# ============================================================
# CONFIGURACIÓN GENERAL DE COMPILACIÓN
# ============================================================

function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(
    ${TARGET}
    PUBLIC
    cxx_std_17
  )

  target_compile_options(
    ${TARGET}
    PRIVATE
    /W4
    /WX
    /wd"4100"
  )

  target_compile_options(
    ${TARGET}
    PRIVATE
    /EHsc
  )

  target_compile_definitions(
    ${TARGET}
    PRIVATE
    "_HAS_EXCEPTIONS=0"
    "$<$<CONFIG:Debug>:_DEBUG>"
  )

  # Se agrega también por objetivo para asegurar que el
  # ejecutable principal reciba la compatibilidad.
  if(MSVC)
    target_compile_definitions(
      ${TARGET}
      PRIVATE
      _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
    )
  endif()
endfunction()

# ============================================================
# FLUTTER
# ============================================================

set(
  FLUTTER_MANAGED_DIR
  "${CMAKE_CURRENT_SOURCE_DIR}/flutter"
)

add_subdirectory(
  ${FLUTTER_MANAGED_DIR}
)

# Application build.
add_subdirectory("runner")

# Generated plugin build rules.
# La definición global colocada al inicio también se aplica
# a los plugins agregados desde este archivo.
include(flutter/generated_plugins.cmake)

# ============================================================
# INSTALACIÓN
# ============================================================

set(
  BUILD_BUNDLE_DIR
  "$<TARGET_FILE_DIR:${BINARY_NAME}>"
)

set(
  CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD
  1
)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(
    CMAKE_INSTALL_PREFIX
    "${BUILD_BUNDLE_DIR}"
    CACHE PATH
    "..."
    FORCE
  )
endif()

set(
  INSTALL_BUNDLE_DATA_DIR
  "${CMAKE_INSTALL_PREFIX}/data"
)

set(
  INSTALL_BUNDLE_LIB_DIR
  "${CMAKE_INSTALL_PREFIX}"
)

install(
  TARGETS ${BINARY_NAME}
  RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime
)

install(
  FILES "${FLUTTER_ICU_DATA_FILE}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime
)

install(
  FILES "${FLUTTER_LIBRARY}"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime
)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(
    FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime
  )
endif()

# Copy native assets provided by build.dart packages.
set(
  NATIVE_ASSETS_DIR
  "${PROJECT_BUILD_DIR}native_assets/windows/"
)

install(
  DIRECTORY "${NATIVE_ASSETS_DIR}"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime
)

# Fully re-copy Flutter assets on each build.
set(
  FLUTTER_ASSET_DIR_NAME
  "flutter_assets"
)

install(
  CODE "
    file(
      REMOVE_RECURSE
      \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\"
    )
  "
  COMPONENT Runtime
)

install(
  DIRECTORY
  "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime
)

# Install the AOT library on non-Debug builds only.
install(
  FILES "${AOT_LIBRARY}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS
  Profile
  Release
  COMPONENT Runtime
)