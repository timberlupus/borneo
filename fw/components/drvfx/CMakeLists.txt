file(GLOB_RECURSE DRVFX_SOURCES 
    "kernel/*.c" 
    "kernel/*.cpp" 
    "drivers/*.c" 
    "drivers/*.cpp" 
)

set(DRVFX_INCLUDE_DIRS "./include")


idf_component_register(
    SRCS ${DRVFX_SOURCES} 
    INCLUDE_DIRS ${DRVFX_INCLUDE_DIRS} 
    REQUIRES driver
    LDFRAGMENTS kernel-linker.lf
    WHOLE_ARCHIVE
)
