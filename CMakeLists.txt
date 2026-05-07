cmake_minimum_required(VERSION 3.12)
project(qlat_build)

set(CMAKE_CXX_STANDARD 17)

if (DEFINED ENV{prefix})
    set(CMAKE_INSTALL_PREFIX $ENV{prefix})
else()
    set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_SOURCE_DIR}/install)
endif ()
message("Install to ${CMAKE_INSTALL_PREFIX}")

set(default_build_type "Release")
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    message(STATUS "Setting build type to '${default_build_type}' as none was specified.")
    set(CMAKE_BUILD_TYPE "${default_build_type}" CACHE
            STRING "Choose the type of build." FORCE)
endif()

# ============================================================
# 统一的依赖库前缀定义 (所有平台共用)
# ============================================================
set(DEPS_PREFIX "${CMAKE_INSTALL_PREFIX}")
set(EIGEN_PREFIX "${DEPS_PREFIX}/eigen")
set(FFT_PREFIX "${DEPS_PREFIX}/fftw")
set(ZLIB_PREFIX "${DEPS_PREFIX}/zlib")
set(GMP_PREFIX "${DEPS_PREFIX}/gmp")
set(MPFR_PREFIX "${DEPS_PREFIX}/mpfr")
set(CUBA_PREFIX "${DEPS_PREFIX}/cuba")
set(LIME_PREFIX "${DEPS_PREFIX}/lime")
set(GRID_PREFIX "${DEPS_PREFIX}/Grid-clehner")
set(HDF5_PREFIX "${DEPS_PREFIX}/hdf5")

if (APPLE)
    add_compile_definitions(QLAT_USE_MACHINE_ENDIAN_H)
    add_compile_definitions(QLAT_NO_SYSINFO)
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
        include_directories(
            ${TOOLCHAIN_INC}
            ${DEPS_INC}
            include
        )

        # 工具链库 (不在 prefix 下)
        set(TOOLCHAIN_LIB
            /opt/homebrew/lib
            /opt/homebrew/opt/llvm/lib
            /opt/homebrew/opt/gsl/lib
        )
        # prefix 安装的库
        set(DEPS_LIB
            ${FFT_PREFIX}/lib
            ${ZLIB_PREFIX}/lib
            ${CUBA_PREFIX}/lib
            ${GMP_PREFIX}/lib
            ${MPFR_PREFIX}/lib
        )
        link_directories(
            ${TOOLCHAIN_LIB}
            ${DEPS_LIB}
        )
    endif()

else()
    # Linux/HPC - 使用 MPI 编译器
    message("Dependencies prefix: ${DEPS_PREFIX}")
    # 禁用 quadmath (超算上可能没有 quadmath.h)
    add_compile_definitions(__QLAT_NO_FLOAT128__)
    add_compile_definitions(QLAT_NO_SYSINFO)

    set(CMAKE_C_COMPILER mpicc)
    set(CMAKE_CXX_COMPILER mpic++)
    set(CMAKE_CXX_FLAGS "-fopenmp -Wall -Wno-unused-variable")

    include_directories(
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${FFT_PREFIX}/include
        ${ZLIB_PREFIX}/include
        ${EIGEN_PREFIX}/include/eigen3
        ${GRID_PREFIX}/include
        ${GMP_PREFIX}/include
        ${MPFR_PREFIX}/include
        ${CUBA_PREFIX}/include
        ${LIME_PREFIX}/include
        ${HDF5_PREFIX}/include
    )

    find_package(MPI REQUIRED)

    find_path(FFTW3_INCLUDE_DIR "fftw3.h" HINTS ${FFT_PREFIX}/include)
    find_path(FFTW3F_INCLUDE_DIR "fftw3.f" HINTS ${FFT_PREFIX}/include)
    if(FFTW3_INCLUDE_DIR)
        include_directories(${FFTW3_INCLUDE_DIR})
    endif()

    find_library(FFTW3_LIBRARY fftw3 HINTS ${FFT_PREFIX}/lib)
    find_library(FFTW3F_LIBRARY fftw3f HINTS ${FFT_PREFIX}/lib)
    find_library(ZLIB_LIBRARY z HINTS ${ZLIB_PREFIX}/lib)

    link_directories(
        ${FFT_PREFIX}/lib
        ${ZLIB_PREFIX}/lib
        ${GRID_PREFIX}/lib
        ${GMP_PREFIX}/lib
        ${MPFR_PREFIX}/lib
        ${CUBA_PREFIX}/lib
        ${HDF5_PREFIX}/lib
        ${LIME_PREFIX}/lib
    )
endif()


set(QLAT_HEADERS include)

aux_source_directory(qlat QLAT_SRC)
aux_source_directory(qutils QUTILS_SRC)
aux_source_directory(qlat-grid QLAT_GRID_SRC)

add_library(qlat SHARED ${QLAT_SRC})
add_library(qutils SHARED ${QUTILS_SRC})
add_library(qlat-grid SHARED ${QLAT_GRID_SRC})

if (APPLE)

    if(DEVICE_NAME STREQUAL "MacBook_Pro_Intel")
        target_link_libraries (qlat qutils
            "/usr/local/lib/libmpi.dylib"
            "/usr/local/opt/zlib/lib/libz.a"
            "/usr/local/opt/llvm/lib/unwind/libunwind.1.dylib"
            "/usr/local/Cellar/fftw/3.3.10_1/lib/libfftw3.dylib"
            "/usr/local/Cellar/fftw/3.3.10_1/lib/libfftw3f.dylib"
        )
    elseif(DEVICE_NAME STREQUAL "Mac_mini_m4")
        # 工具链库 (不在 prefix 下)
        set(TOOLCHAIN_LIBS
            "/opt/homebrew/lib/libcrc32c.dylib"
            "/opt/homebrew/opt/openmpi/lib/libmpi.dylib"
            "/opt/homebrew/opt/llvm/lib/libomp.dylib"
            "/opt/homebrew/opt/gsl/lib/libgsl.dylib"
            "/opt/homebrew/opt/gsl/lib/libgslcblas.dylib"
        )
        # prefix 安装的库
        set(DEPS_LIBS
            "${ZLIB_PREFIX}/lib/libz.dylib"
            "${FFT_PREFIX}/lib/libfftw3.dylib"
            "${FFT_PREFIX}/lib/libfftw3f.dylib"
            "${CUBA_PREFIX}/lib/libcuba.a"
            "${GMP_PREFIX}/lib/libgmp.dylib"
            "${MPFR_PREFIX}/lib/libmpfr.dylib"
        )
        target_link_libraries (qlat qutils
            ${TOOLCHAIN_LIBS}
            ${DEPS_LIBS}
        )
    endif()

    # qlat-grid: 使用 Grid 自带的 Eigen 和依赖库
    if(DEVICE_NAME STREQUAL "Mac_mini_m4")
        set(TOOLCHAIN_LIBS
            "/opt/homebrew/lib/libcrc32c.dylib"
            "/opt/homebrew/opt/openmpi/lib/libmpi.dylib"
            "/opt/homebrew/opt/llvm/lib/libomp.dylib"
            "/opt/homebrew/opt/gsl/lib/libgsl.dylib"
            "/opt/homebrew/opt/gsl/lib/libgslcblas.dylib"
        )
        set(DEPS_LIBS
            "${ZLIB_PREFIX}/lib/libz.dylib"
            "${FFT_PREFIX}/lib/libfftw3.dylib"
            "${FFT_PREFIX}/lib/libfftw3f.dylib"
            "${CUBA_PREFIX}/lib/libcuba.a"
            "${GRID_PREFIX}/lib/libGrid.a"
            "${HDF5_PREFIX}/lib/libhdf5.a"
            "${HDF5_PREFIX}/lib/libhdf5_hl.a"
            "${LIME_PREFIX}/lib/liblime.a"
            "${GMP_PREFIX}/lib/libgmp.dylib"
            "${MPFR_PREFIX}/lib/libmpfr.dylib"
        )
        target_link_libraries (qlat-grid qlat qutils
            ${TOOLCHAIN_LIBS}
            ${DEPS_LIBS}
        )
    endif()

    # 安装: 库在 lib/, 头文件在 include/
    install(TARGETS qlat qutils qlat-grid DESTINATION ${CMAKE_INSTALL_PREFIX}/lib)
    install(DIRECTORY ${QLAT_HEADERS}/ DESTINATION ${CMAKE_INSTALL_PREFIX}/include)
else()
    # Linux/HPC
    set(FFTWLIB "")
    if(FFT_PREFIX AND FFTW3_LIBRARY)
        set(FFTWLIB ${FFTW3_LIBRARY} ${FFTW3F_LIBRARY})
    endif()

    set(ZLIBLIB "")
    if(ZLIB_PREFIX AND ZLIB_LIBRARY)
        set(ZLIBLIB "${ZLIB_LIBRARY}")
    endif()

    set(CUBALIB "")
    if(CUBA_PREFIX)
        find_library(CUBA_LIBRARY cuba HINTS ${CUBA_PREFIX}/lib)
        if(CUBA_LIBRARY)
            set(CUBALIB "${CUBA_LIBRARY}")
            include_directories(${CUBA_PREFIX}/include)
            link_directories(${CUBA_PREFIX}/lib)
        endif()
    endif()

    set(GRIDLIB "")
    if(GRID_PREFIX)
        find_library(GRID_LIBRARY Grid HINTS ${GRID_PREFIX}/lib)
        if(GRID_LIBRARY)
            set(GRIDLIB "${GRID_LIBRARY}")
        endif()
    endif()

    set(HDF5LIB "")
    if(HDF5_PREFIX)
        find_library(HDF5_LIBRARY hdf5 HINTS ${HDF5_PREFIX}/lib NO_DEFAULT_PATH)
        find_library(HDF5_HL_LIBRARY hdf5_hl HINTS ${HDF5_PREFIX}/lib NO_DEFAULT_PATH)
        if(HDF5_LIBRARY AND HDF5_HL_LIBRARY)
            # 使用列表格式（分号分隔）
            set(HDF5LIB ${HDF5_LIBRARY} ${HDF5_HL_LIBRARY})
            message(STATUS "HDF5 libraries found: ${HDF5LIB}")
        else()
            # fallback: 直接使用完整路径
            if(EXISTS "${HDF5_PREFIX}/lib/libhdf5.a")
                set(HDF5LIB "${HDF5_PREFIX}/lib/libhdf5.a")
                if(EXISTS "${HDF5_PREFIX}/lib/libhdf5_hl.a")
                    set(HDF5LIB "${HDF5LIB};${HDF5_PREFIX}/lib/libhdf5_hl.a")
                endif()
                message(STATUS "HDF5 using fallback path: ${HDF5LIB}")
            endif()
        endif()
    endif()

    set(LIMELIB "")
    if(LIME_PREFIX)
        find_library(LIME_LIBRARY lime HINTS ${LIME_PREFIX}/lib)
        if(LIME_LIBRARY)
            set(LIMELIB "${LIME_LIBRARY}")
        endif()
    endif()

    target_link_libraries(qlat qutils MPI::MPI_CXX ${FFTWLIB} ${ZLIBLIB} ${CUBALIB})
    target_link_libraries(qlat-grid qlat qutils MPI::MPI_CXX ${FFTWLIB} ${ZLIBLIB} ${CUBALIB} ${GRIDLIB} ${HDF5LIB} ${LIMELIB})

    # 安装: 库在 lib/, 头文件在 include/
    install(TARGETS qlat qutils qlat-grid DESTINATION ${CMAKE_INSTALL_PREFIX}/lib)
    install(DIRECTORY ${QLAT_HEADERS}/ DESTINATION ${CMAKE_INSTALL_PREFIX}/include)
endif()
