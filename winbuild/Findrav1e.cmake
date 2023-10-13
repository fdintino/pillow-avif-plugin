file(TO_CMAKE_PATH "${AVIF_RAV1E_ROOT}" RAV1E_ROOT_PATH)
add_library(rav1e STATIC IMPORTED GLOBAL)
set_target_properties(rav1e PROPERTIES
    IMPORTED_LOCATION "${RAV1E_ROOT_PATH}/lib/rav1e.lib"
    AVIF_LOCAL ON
    INTERFACE_INCLUDE_DIRECTORIES "${RAV1E_ROOT_PATH}/inc/rav1e"
)
add_library(rav1e::rav1e ALIAS rav1e)
