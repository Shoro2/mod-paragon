# Include at the end of an isolated core's top-level CMakeLists.txt only.
add_executable(paragon_delete_native
    "${CMAKE_CURRENT_LIST_DIR}/native_character_deletion.cpp")
target_link_libraries(paragon_delete_native PRIVATE
    acore-core-interface modules scripts game gsoap readline gperftools libsidecar)
