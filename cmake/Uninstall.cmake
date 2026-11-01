if(EXISTS "${PRIMME_INSTALL_MANIFEST}")
  file(STRINGS "${PRIMME_INSTALL_MANIFEST}" PRIMME_INSTALLED_FILES)
  foreach(PRIMME_FILE IN LISTS PRIMME_INSTALLED_FILES)
    if(EXISTS "${PRIMME_FILE}")
      file(REMOVE "${PRIMME_FILE}")
    endif()
  endforeach()
else()
  message(STATUS "No install manifest found; no prefix files to remove")
endif()

if(DEFINED ENV{HOME} AND NOT "$ENV{HOME}" STREQUAL "")
  file(REMOVE
    "$ENV{HOME}/.modules.d/primme/${PRIMME_PLATFORM}/${PRIMME_VERSION}"
    "$ENV{HOME}/.pkgconfig.d/primme.pc")
endif()
message(STATUS "Removed PRIMME files listed in the install manifest and user registrations")
