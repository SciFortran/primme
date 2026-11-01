cmake_minimum_required(VERSION 3.16)
project(primme VERSION 3.2 LANGUAGES C)

include(GNUInstallDirs)

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
  set_target_properties(primme_shared PROPERTIES OUTPUT_NAME primme VERSION ${PROJECT_VERSION} SOVERSION ${PROJECT_VERSION_MAJOR} POSITION_INDEPENDENT_CODE ON INSTALL_NAME_DIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
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

set(PRIMME_PKGCONFIG_LIBS "-lprimme -llapack -lblas -lm")
configure_file(etc/primme.pc.in ${CMAKE_CURRENT_BINARY_DIR}/primme.pc @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/primme.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)

string(TOLOWER "${CMAKE_C_COMPILER_ID}" PRIMME_PLATFORM)
set(PRIMME_MODULE_DIR "${CMAKE_INSTALL_LIBDIR}/modules/primme/${PRIMME_PLATFORM}")
configure_file(etc/environment_modules/primme.in ${CMAKE_CURRENT_BINARY_DIR}/primme.module @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/primme.module DESTINATION ${PRIMME_MODULE_DIR} RENAME ${PROJECT_VERSION})

