cmake_minimum_required(VERSION 3.12)
project(example_free_propagator)

set(CMAKE_CXX_STANDARD 17)

# Generate compile_commands.json for LSP (clangd)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Generate compile_commands.json" FORCE)

set(default_build_type "Release")
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    message(STATUS "Setting build type to '${default_build_type}' as none was specified.")
    set(CMAKE_BUILD_TYPE "${default_build_type}" CACHE
            STRING "Choose the type of build." FORCE)
    # Set the possible values of build type for cmake-gui
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
            "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

# ============================================================
# 使用 QLAT_PREFIX 作为 qlat 库路径
# ============================================================
if (DEFINED ENV{QLAT_PREFIX})
    set(QLAT_PREFIX $ENV{QLAT_PREFIX})
else()
    message(FATAL_ERROR "Please set QLAT_PREFIX environment variable. \nExample: export QLAT_PREFIX=/opt/lattice-package/qlat-0.90-cpp")
endif()
message("Using qlat from: ${QLAT_PREFIX}")

# ============================================================
# 共享的依赖库前缀定义 (所有平台共用)
# ============================================================
set(DEPS_PREFIX "${QLAT_PREFIX}")
set(EIGEN_PREFIX "${DEPS_PREFIX}/eigen")
set(FFT_PREFIX "${DEPS_PREFIX}/fftw")
set(ZLIB_PREFIX "${DEPS_PREFIX}/zlib")

# 共享的 include 路径 (qlat 安装目录下的库)
set(DEPS_INC
    ${EIGEN_PREFIX}/include/eigen3
    ${FFT_PREFIX}/include
    ${ZLIB_PREFIX}/include
)

# 共享的 library 路径 (qlat 安装目录下的库)
set(DEPS_LIB
    ${FFT_PREFIX}/lib
    ${ZLIB_PREFIX}/lib
)

# ============================================================
# 平台特定配置
# ============================================================
if (APPLE)
    add_compile_definitions(QLAT_USE_MACHINE_ENDIAN_H)
    add_compile_definitions(QLAT_NO_SYSINFO)
    add_compile_definitions(QLAT_NO_CUBA)
    add_compile_definitions(__QLAT_NO_FLOAT128__)
    add_compile_definitions(QLAT_NO_MALLOPT)
    set(DEVICE_NAME "Mac_mini_m4")

    if(DEVICE_NAME STREQUAL "MacBook_Pro_Intel")
        set(CMAKE_C_COMPILER "/usr/local/opt/llvm/bin/clang")
        set(CMAKE_CXX_COMPILER "/usr/local/opt/llvm/bin/clang++")
    elseif(DEVICE_NAME STREQUAL "Mac_mini_m4")
        set(CMAKE_C_COMPILER "/opt/homebrew/opt/llvm/bin/clang")
        set(CMAKE_CXX_COMPILER "/opt/homebrew/opt/llvm/bin/clang++")
    endif()
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fopenmp -lz")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fopenmp -lz")
    set(CMAKE_CXX_FLAGS "-Xpreprocessor -fopenmp -Wno-deprecated")

    if(DEVICE_NAME STREQUAL "MacBook_Pro_Intel")
        include_directories(
                /usr/local/include
                /usr/local/opt/llvm/include
                /usr/local/opt/zlib/include
                include
        )
        link_directories(
            /usr/local/lib
            /usr/local/opt/llvm/lib
        )
    elseif(DEVICE_NAME STREQUAL "Mac_mini_m4")
        # 工具链库 (不在 prefix 下)
        set(TOOLCHAIN_INC
            /opt/homebrew/include
            /opt/homebrew/opt/llvm/include
            /opt/homebrew/opt/openmpi/include
        )
        # prefix 安装的库
        set(TOOLCHAIN_LIB
            /opt/homebrew/lib
            /opt/homebrew/opt/llvm/lib
        )
        include_directories(
            ${TOOLCHAIN_INC}
            ${QLAT_PREFIX}/include
            ${DEPS_INC}
        )
        link_directories(
            ${TOOLCHAIN_LIB}
            ${QLAT_PREFIX}/lib
            ${DEPS_LIB}
        )
    endif()

    # Using bundled Eigen from prefix
else()
    # Linux/HPC
    add_compile_definitions(__QLAT_NO_FLOAT128__)
    add_compile_definitions(QLAT_NO_SYSINFO)
    set(CMAKE_CXX_COMPILER mpic++)
    set(CMAKE_CXX_FLAGS "-fopenmp -Wall -Wno-unused-variable")

    include_directories(
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${QLAT_PREFIX}/include
        ${DEPS_INC}
    )

    link_directories(
        ${QLAT_PREFIX}/lib
        ${DEPS_LIB}
    )
endif()

# ============================================================
# 链接 qlat 和 qutils 库 (无 Grid)
# ============================================================
if(APPLE)
    if(DEVICE_NAME STREQUAL "MacBook_Pro_Intel")
        set(QLAT_LIBS
            "${QLAT_PREFIX}/lib/libqlat.dylib"
            "${QLAT_PREFIX}/lib/libqutils.dylib"
            "/usr/local/lib/libmpi.dylib"
            "/usr/local/opt/zlib/lib/libz.a"
            "/usr/local/opt/llvm/lib/unwind/libunwind.1.dylib"
            "/usr/local/Cellar/fftw/3.3.10_1/lib/libfftw3.dylib"
            "/usr/local/Cellar/fftw/3.3.10_1/lib/libfftw3f.dylib"
        )
    elseif(DEVICE_NAME STREQUAL "Mac_mini_m4")
        set(QLAT_LIBS
            "/opt/homebrew/lib/libcrc32c.dylib"
            "/opt/homebrew/opt/openmpi/lib/libmpi.dylib"
            "/opt/homebrew/opt/llvm/lib/libomp.dylib"
            "${QLAT_PREFIX}/lib/libqlat.dylib"
            "${QLAT_PREFIX}/lib/libqutils.dylib"
        )
    endif()
else()
    # Linux/HPC
    set(QLAT_LIBS
        ${QLAT_PREFIX}/lib/libqlat.so
        ${QLAT_PREFIX}/lib/libqutils.so
        ${ZLIB_PREFIX}/lib/libz.so
        ${FFT_PREFIX}/lib/libfftw3.so
        ${FFT_PREFIX}/lib/libfftw3f.so
    )
endif()

# 自动发现并编译 app/ 目录下的可执行文件
file(GLOB APP_SOURCES app/*.cpp)
foreach(sourcefile ${APP_SOURCES})
    file(RELATIVE_PATH filename ${CMAKE_CURRENT_SOURCE_DIR}/app ${sourcefile})
    string(REPLACE ".cpp" "" name ${filename})
    add_executable(${name} ${sourcefile})
    
    # 链接 qlat 和 qutils (无 Grid)
    target_link_libraries(${name} ${QLAT_LIBS})
endforeach()
