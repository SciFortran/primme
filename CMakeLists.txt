CMAKE_MINIMUM_REQUIRED(VERSION 3.16)
PROJECT(primme C)

# Use the checked-out PRIMME release tag as the installed version.
EXECUTE_PROCESS(
  COMMAND git describe --tags --exact-match HEAD
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  RESULT_VARIABLE PRIMME_TAG_RESULT
  OUTPUT_VARIABLE VERSION
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_QUIET
)
IF(NOT PRIMME_TAG_RESULT EQUAL 0)
  EXECUTE_PROCESS(
    COMMAND git describe --tags --abbrev=0
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    RESULT_VARIABLE PRIMME_TAG_RESULT
    OUTPUT_VARIABLE VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
ENDIF()
IF(NOT VERSION)
  FILE(STRINGS ${CMAKE_SOURCE_DIR}/Make_flags PRIMME_VERSION_LINE REGEX "^VERSION[ ]*:=")
  STRING(REGEX REPLACE "^VERSION[ ]*:= *" "" VERSION "${PRIMME_VERSION_LINE}")
ENDIF()
MESSAGE(STATUS "PRIMME VERSION=${VERSION}")

SET(BUILD_TYPE "RELEASE" CACHE STRING "Build type")
MESSAGE(STATUS "BUILD_TYPE=${BUILD_TYPE}")
STRING(TOUPPER "${BUILD_TYPE}" BUILD_TYPE)
SET(CMAKE_BUILD_TYPE ${BUILD_TYPE} CACHE INTERNAL "Build type" FORCE)

# Use the same local CMake helpers and installation layout as the other Libs.
SET(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/Modules")
INCLUDE(${CMAKE_MODULE_PATH}/ColorsMsg.cmake)

OPTION(VERBOSE "Build a verbose Makefile" OFF)
IF(VERBOSE)
  SET(CMAKE_VERBOSE_MAKEFILE ON)
ELSE()
  SET(CMAKE_VERBOSE_MAKEFILE OFF)
ENDIF()

OPTION(PRIMME_WITH_FLOAT "Build single precision routines" ON)

# Keep the conventional Libs prefix, with the PRIMME release tag as version.
STRING(TOLOWER "${CMAKE_C_COMPILER_ID}" FC_PLAT)
SET(PRIMME_PREFIX "$ENV{HOME}/opt/${PROJECT_NAME}/${VERSION}" CACHE PATH
    "Prefix prepended to install directories")
SET(PREFIX "${PRIMME_PREFIX}")
SET(CMAKE_INSTALL_PREFIX "${PRIMME_PREFIX}" CACHE INTERNAL
    "Prefix prepended to install directories" FORCE)

# Define the source, metadata and installation directories.
SET(LIB_SRC ${CMAKE_SOURCE_DIR}/src)
SET(LIB_ETC ${CMAKE_SOURCE_DIR}/etc)
SET(LIB_ENV ${LIB_ETC}/environment_modules)
SET(LIB_TMP_ETC ${CMAKE_BINARY_DIR}/etc)
SET(LIB_TARGET_LIB ${CMAKE_INSTALL_PREFIX}/lib)
SET(LIB_TARGET_INC ${CMAKE_INSTALL_PREFIX}/include)
SET(LIB_TARGET_ETC ${CMAKE_INSTALL_PREFIX}/etc)

# Add the standard Libs clean target.
ADD_CUSTOM_TARGET(distclean
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/distclean.cmake
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)

FIND_PACKAGE(BLAS REQUIRED)
FIND_PACKAGE(LAPACK REQUIRED)

SET(PRIMME_SRC
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
  src/svds/primme_svds_interface.c
)

ADD_LIBRARY(primme STATIC ${PRIMME_SRC})
SET_TARGET_PROPERTIES(primme PROPERTIES POSITION_INDEPENDENT_CODE ON)
INCLUDE_DIRECTORIES(
  ${CMAKE_SOURCE_DIR}/include
  ${CMAKE_SOURCE_DIR}/src/include
  ${CMAKE_SOURCE_DIR}/src/eigs
  ${CMAKE_SOURCE_DIR}/src/linalg
  ${CMAKE_SOURCE_DIR}/src/svds
)
ADD_DEFINITIONS(-DF77UNDERSCORE)
IF(NOT PRIMME_WITH_FLOAT)
  ADD_DEFINITIONS(-DPRIMME_WITHOUT_FLOAT)
ENDIF()
TARGET_LINK_LIBRARIES(primme ${LAPACK_LIBRARIES} ${BLAS_LIBRARIES} m)

# Generate PRIMME's Environment Modules and pkg-config files with the shared
# helpers, then install them in the prefix and the user's discovery folders.
INCLUDE(${CMAKE_MODULE_PATH}/PostBuildLibrary.cmake)
FILE(MAKE_DIRECTORY ${LIB_TMP_ETC}/modules/${PROJECT_NAME}/${FC_PLAT})
SET(TMP_ENV_MODULE_FILE ${LIB_TMP_ETC}/modules/${PROJECT_NAME}/${FC_PLAT}/${VERSION})
BUILD_ENV_MODULE(${TMP_ENV_MODULE_FILE})
SET(TMP_PKCONFIG_FILE ${LIB_TMP_ETC}/${PROJECT_NAME}.pc)
BUILD_PKCONFIG(${TMP_PKCONFIG_FILE})

INSTALL(TARGETS primme DESTINATION ${LIB_TARGET_LIB})
INSTALL(DIRECTORY ${CMAKE_SOURCE_DIR}/include/ DESTINATION ${LIB_TARGET_INC})
INSTALL(DIRECTORY ${LIB_TMP_ETC}/ DESTINATION ${LIB_TARGET_ETC})
INSTALL(DIRECTORY ${LIB_TMP_ETC}/modules/ DESTINATION $ENV{HOME}/.modules.d)
INSTALL(FILES ${TMP_PKCONFIG_FILE} DESTINATION $ENV{HOME}/.pkgconfig.d)

# Uninstall only files recorded by CMake's install manifest and PRIMME's
# user-local module and pkg-config registration.
ADD_CUSTOM_TARGET(uninstall
  COMMAND ${CMAKE_COMMAND}
          -DPRIMME_INSTALL_MANIFEST=${CMAKE_BINARY_DIR}/install_manifest.txt
          -DPRIMME_VERSION=${VERSION}
          -DPRIMME_PLATFORM=${FC_PLAT}
          -P ${CMAKE_SOURCE_DIR}/cmake/Uninstall.cmake
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)

MESSAGE(STATUS "To build and install PRIMME:")
MESSAGE(STATUS "$ make")
MESSAGE(STATUS "$ make install")
MESSAGE(STATUS "Uninstall with: $ make uninstall")
