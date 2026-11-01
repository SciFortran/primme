cmake_minimum_required(VERSION 3.16)
project(primme LANGUAGES C)

# Prefer the checked-out release tag. Fall back to the closest tag for a
# development checkout, then to the version recorded by the upstream source.
execute_process(
  COMMAND git describe --tags --exact-match HEAD
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  RESULT_VARIABLE PRIMME_EXACT_TAG_RESULT
  OUTPUT_VARIABLE PRIMME_VERSION
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_QUIET)
if(NOT PRIMME_EXACT_TAG_RESULT EQUAL 0)
  execute_process(
    COMMAND git describe --tags --abbrev=0
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    RESULT_VARIABLE PRIMME_TAG_RESULT
    OUTPUT_VARIABLE PRIMME_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  if(NOT PRIMME_TAG_RESULT EQUAL 0)
    set(PRIMME_VERSION "3.2")
  endif()
endif()
message(STATUS "PRIMME version: ${PRIMME_VERSION}")
string(REGEX MATCH "^[0-9]+" PRIMME_SOVERSION "${PRIMME_VERSION}")

include(GNUInstallDirs)

string(TOLOWER "${CMAKE_C_COMPILER_ID}" PRIMME_PLATFORM)
set(PROJECT_NAME primme)
set(VERSION ${PRIMME_VERSION})
set(FC_PLAT ${PRIMME_PLATFORM})
set(PREFIX ${CMAKE_INSTALL_PREFIX})
set(LIB_ETC ${CMAKE_CURRENT_SOURCE_DIR}/etc)
set(LIB_ENV ${LIB_ETC}/environment_modules)
set(LIB_TMP_ETC ${CMAKE_CURRENT_BINARY_DIR}/etc)
set(LIB_TARGET_ETC ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_SYSCONFDIR})
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules)
include(${CMAKE_MODULE_PATH}/ColorsMsg.cmake)
include(${CMAKE_MODULE_PATH}/PostBuildLibrary.cmake)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "$ENV{HOME}/opt/primme/${PRIMME_VERSION}" CACHE PATH
      "PRIMME installation prefix" FORCE)
endif()

option(PRIMME_WITH_FLOAT "Build single precision routines" ON)
option(PRIMME_BUILD_SHARED "Build shared library in addition to static library" ON)

find_package(BLAS REQUIRED)
find_package(LAPACK REQUIRED)

set(PRIMME_SOURCES
  src/eigs/auxiliary_eigs.c
  src/eigs/auxiliary_eigs_normal.c
  src/eigs/convergence.c
  src/eigs/correction.c
  src/eigs/factorize.c
  src/eigs/init.c
  src/eigs/inner_solve.c
  src/eigs/main_iter.c
  src/eigs/ortho.c
  src/eigs/primme_c.c
  src/eigs/primme_f77.c
  src/eigs/primme_interface.c
  src/eigs/restart.c
  src/eigs/solve_projection.c
  src/eigs/update_projection.c
  src/eigs/update_W.c
  src/linalg/auxiliary.c
  src/linalg/blaslapack.c
  src/linalg/magma_wrapper.c
  src/linalg/cublas_wrapper.c
  src/linalg/memman.c
  src/linalg/wtime.c
  src/svds/primme_svds_c.c
  src/svds/primme_svds_f77.c
  src/svds/primme_svds_interface.c)

add_library(primme_static STATIC ${PRIMME_SOURCES})
add_library(PRIMME::primme ALIAS primme_static)
set_target_properties(primme_static PROPERTIES OUTPUT_NAME primme POSITION_INDEPENDENT_CODE ON)
target_include_directories(primme_static
  PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
         $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
  PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src/include
          ${CMAKE_CURRENT_SOURCE_DIR}/src/eigs
          ${CMAKE_CURRENT_SOURCE_DIR}/src/svds)
target_compile_definitions(primme_static PRIVATE F77UNDERSCORE)
if(NOT PRIMME_WITH_FLOAT)
  target_compile_definitions(primme_static PUBLIC PRIMME_WITHOUT_FLOAT)
endif()
target_link_libraries(primme_static PUBLIC LAPACK::LAPACK BLAS::BLAS m)

if(PRIMME_BUILD_SHARED)
  add_library(primme_shared SHARED ${PRIMME_SOURCES})
  set_target_properties(primme_shared PROPERTIES OUTPUT_NAME primme VERSION ${PRIMME_VERSION} SOVERSION ${PRIMME_SOVERSION} POSITION_INDEPENDENT_CODE ON INSTALL_NAME_DIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
  target_include_directories(primme_shared
    PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
           $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src/include
            ${CMAKE_CURRENT_SOURCE_DIR}/src/eigs
            ${CMAKE_CURRENT_SOURCE_DIR}/src/svds)
  target_compile_definitions(primme_shared PRIVATE F77UNDERSCORE)
  if(NOT PRIMME_WITH_FLOAT)
    target_compile_definitions(primme_shared PUBLIC PRIMME_WITHOUT_FLOAT)
  endif()
  target_link_libraries(primme_shared PRIVATE LAPACK::LAPACK BLAS::BLAS m)
endif()

set(PRIMME_PUBLIC_HEADERS
  include/primme.h include/primme_eigs.h include/primme_eigs_f77.h
  include/primme_eigs_f90.inc include/primme_f77.h include/primme_f90.inc
  include/primme_svds.h include/primme_svds_f77.h include/primme_svds_f90.inc)
install(FILES ${PRIMME_PUBLIC_HEADERS} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(TARGETS primme_static ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
if(PRIMME_BUILD_SHARED)
  install(TARGETS primme_shared LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

# Generate the versioned environment module and pkg-config file with the
# same helpers used by the other standalone libraries in Libs.
file(MAKE_DIRECTORY ${LIB_TMP_ETC}/modules/${PROJECT_NAME}/${FC_PLAT})
set(TMP_ENV_MODULE_FILE ${LIB_TMP_ETC}/modules/${PROJECT_NAME}/${FC_PLAT}/${VERSION})
BUILD_ENV_MODULE(${TMP_ENV_MODULE_FILE})
set(TMP_PKCONFIG_FILE ${LIB_TMP_ETC}/${PROJECT_NAME}.pc)
BUILD_PKCONFIG(${TMP_PKCONFIG_FILE})
install(DIRECTORY ${LIB_TMP_ETC}/ DESTINATION ${CMAKE_INSTALL_SYSCONFDIR})

# Register the same user-local module and pkg-config files during `make install`,
# as done by the nssDMRG installer.
install(DIRECTORY ${LIB_TMP_ETC}/modules/ DESTINATION "$ENV{HOME}/.modules.d")
install(FILES ${TMP_PKCONFIG_FILE} DESTINATION "$ENV{HOME}/.pkgconfig.d")

add_custom_target(distclean
  COMMAND "${CMAKE_COMMAND}" -P ${CMAKE_SOURCE_DIR}/distclean.cmake
  WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
  COMMENT "Removing PRIMME build artifacts")

add_custom_target(uninstall
  COMMAND "${CMAKE_COMMAND}"
          -DPRIMME_INSTALL_MANIFEST=${CMAKE_BINARY_DIR}/install_manifest.txt
          -DPRIMME_VERSION=${PRIMME_VERSION}
          -DPRIMME_PLATFORM=${PRIMME_PLATFORM}
          -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Uninstall.cmake
  WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
  COMMENT "Uninstalling PRIMME")
