cmake_minimum_required(VERSION 3.12)
project(example_qlat_grid)

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
set(GMP_PREFIX "${DEPS_PREFIX}/gmp")
set(MPFR_PREFIX "${DEPS_PREFIX}/mpfr")
set(CUBA_PREFIX "${DEPS_PREFIX}/cuba")
set(LIME_PREFIX "${DEPS_PREFIX}/lime")
set(GRID_PREFIX "${DEPS_PREFIX}/Grid-clehner")
set(HDF5_PREFIX "${DEPS_PREFIX}/hdf5")

# 共享的 include 路径 (qlat 安装目录下的库)
set(DEPS_INC
    ${FFT_PREFIX}/include
    ${ZLIB_PREFIX}/include
    ${CUBA_PREFIX}/include
    ${GRID_PREFIX}/include
    ${HDF5_PREFIX}/include
    ${LIME_PREFIX}/include
    ${GMP_PREFIX}/include
    ${MPFR_PREFIX}/include
    ${EIGEN_PREFIX}/include/eigen3
)

# 共享的 library 路径 (qlat 安装目录下的库)
set(DEPS_LIB
    ${FFT_PREFIX}/lib
    ${ZLIB_PREFIX}/lib
    ${CUBA_PREFIX}/lib
    ${GMP_PREFIX}/lib
    ${MPFR_PREFIX}/lib
    ${GRID_PREFIX}/lib
    ${HDF5_PREFIX}/lib
    ${LIME_PREFIX}/lib
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
            /opt/homebrew/opt/gsl/include
        )
        # prefix 安装的库
        set(TOOLCHAIN_LIB
            /opt/homebrew/lib
            /opt/homebrew/opt/llvm/lib
            /opt/homebrew/opt/gsl/lib
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

    find_package (Eigen3 REQUIRED NO_MODULE)
else()
    # Linux/HPC
    add_compile_definitions(__QLAT_NO_FLOAT128__)
    add_compile_definitions(QLAT_NO_SYSINFO)
    set(CMAKE_CXX_COMPILER mpic++)
    set(CMAKE_CXX_FLAGS "-fopenmp -Wall -Wno-unused-variable") #-march=armv8-a+sve -msve-vector-bits=256

    include_directories(
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${DEPS_INC}
    )

    # 查找 GSL
    find_package(GSL REQUIRED)
    
    # HDF5 使用 DEPS_INC 和 DEPS_LIB 中的硬编码路径
    # 不再使用 find_package，因为 HDF5 静态库配置不稳定
    message(STATUS "HDF5 using: ${HDF5_PREFIX}")

    link_directories(
        ${DEPS_LIB}
    )
endif()

# 源文件目录
aux_source_directory(src SRCS)
message(STATUS "SRCS: ${SRCS}")

# 创建库
add_library(cntr ${SRCS})

# 链接 qlat-grid 库
if(APPLE)
    if(DEVICE_NAME STREQUAL "MacBook_Pro_Intel")
        target_link_libraries(cntr
            "${QLAT_PREFIX}/lib/libqlat-grid.dylib"
            "${QLAT_PREFIX}/lib/libqlat.dylib"
            "${QLAT_PREFIX}/lib/libqutils.dylib"
            "/usr/local/lib/libmpi.dylib"
            "/usr/local/opt/zlib/lib/libz.a"
            "/usr/local/opt/llvm/lib/unwind/libunwind.1.dylib"
            "/usr/local/Cellar/fftw/3.3.10_1/lib/libfftw3.dylib"
            "/usr/local/Cellar/fftw/3.3.10_1/lib/libfftw3f.dylib"
        )
    elseif(DEVICE_NAME STREQUAL "Mac_mini_m4")
        set(TOOLCHAIN_LINK_LIBS
            "/opt/homebrew/lib/libcrc32c.dylib"
            "/opt/homebrew/opt/openmpi/lib/libmpi.dylib"
            "/opt/homebrew/opt/llvm/lib/libomp.dylib"
            "/opt/homebrew/opt/gsl/lib/libgsl.dylib"
            "/opt/homebrew/opt/gsl/lib/libgslcblas.dylib"
        )
        target_link_libraries(cntr
            ${TOOLCHAIN_LINK_LIBS}
            "${QLAT_PREFIX}/lib/libqlat-grid.dylib"
            "${QLAT_PREFIX}/lib/libqlat.dylib"
            "${QLAT_PREFIX}/lib/libqutils.dylib"
        )
    endif()
else()
    # Linux/HPC
    target_link_libraries(cntr
        ${QLAT_PREFIX}/lib/libqlat-grid.so
        ${QLAT_PREFIX}/lib/libqlat.so
        ${QLAT_PREFIX}/lib/libqutils.so
        GSL::gsl
        GSL::gslcblas
        ${ZLIB_PREFIX}/lib/libz.so
        ${FFT_PREFIX}/lib/libfftw3.so
        ${FFT_PREFIX}/lib/libfftw3f.so
        ${GMP_PREFIX}/lib/libgmp.so
        ${MPFR_PREFIX}/lib/libmpfr.so
        ${HDF5_PREFIX}/lib/libhdf5_cpp.a
        ${HDF5_PREFIX}/lib/libhdf5.a
        ${HDF5_PREFIX}/lib/libhdf5_hl_cpp.a
        ${HDF5_PREFIX}/lib/libhdf5_hl.a
        stdc++fs
    )
endif()

# 自动发现并编译 app/ 目录下的可执行文件
file(GLOB APP_SOURCES app/*.cpp)
foreach(sourcefile ${APP_SOURCES})
    file(RELATIVE_PATH filename ${CMAKE_CURRENT_SOURCE_DIR}/app ${sourcefile})
    string(REPLACE ".cpp" "" name ${filename})
    add_executable(${name} ${sourcefile})
    
    # 链接 cntr 库和 qlat-grid
    if(APPLE)
        if(DEVICE_NAME STREQUAL "MacBook_Pro_Intel")
            target_link_libraries(${name} cntr
                "${QLAT_PREFIX}/lib/libqlat-grid.dylib"
                "${QLAT_PREFIX}/lib/libqlat.dylib"
                "${QLAT_PREFIX}/lib/libqutils.dylib"
                "/usr/local/lib/libmpi.dylib"
                "/usr/local/opt/zlib/lib/libz.a"
                "/usr/local/opt/llvm/lib/unwind/libunwind.1.dylib"
                "/usr/local/Cellar/fftw/3.3.10_1/lib/libfftw3.dylib"
                "/usr/local/Cellar/fftw/3.3.10_1/lib/libfftw3f.dylib"
                "/usr/local/opt/openblas/lib/libopenblas.a"
            )
        elseif(DEVICE_NAME STREQUAL "Mac_mini_m4")
            set(TOOLCHAIN_LINK_LIBS
                "/opt/homebrew/lib/libcrc32c.dylib"
                "/opt/homebrew/opt/openmpi/lib/libmpi.dylib"
                "/opt/homebrew/opt/llvm/lib/libomp.dylib"
                "/opt/homebrew/opt/gsl/lib/libgsl.dylib"
                "/opt/homebrew/opt/gsl/lib/libgslcblas.dylib"
            )
            target_link_libraries(${name} cntr
                ${TOOLCHAIN_LINK_LIBS}
                "${QLAT_PREFIX}/lib/libqlat-grid.dylib"
                "${QLAT_PREFIX}/lib/libqlat.dylib"
                "${QLAT_PREFIX}/lib/libqutils.dylib"
                "/opt/homebrew/opt/openblas/lib/libopenblas.a"
            )
        endif()
    else()
        # Linux/HPC
        target_link_libraries(${name} cntr
            ${QLAT_PREFIX}/lib/libqlat-grid.so
            ${QLAT_PREFIX}/lib/libqlat.so
            ${QLAT_PREFIX}/lib/libqutils.so
            GSL::gsl
            GSL::gslcblas
            ${ZLIB_PREFIX}/lib/libz.so
            ${FFT_PREFIX}/lib/libfftw3.so
            ${FFT_PREFIX}/lib/libfftw3f.so
            ${GMP_PREFIX}/lib/libgmp.so
            ${MPFR_PREFIX}/lib/libmpfr.so
            ${HDF5_PREFIX}/lib/libhdf5_cpp.a
            ${HDF5_PREFIX}/lib/libhdf5.a
            ${HDF5_PREFIX}/lib/libhdf5_hl_cpp.a
            ${HDF5_PREFIX}/lib/libhdf5_hl.a
            stdc++fs
        )
    endif()
endforeach()
