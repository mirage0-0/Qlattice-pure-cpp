#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISTFILES_DIR="$PROJECT_ROOT/distfiles"
BUILD_DIR="$PROJECT_ROOT/build-deps"
INSTALL_PREFIX="${prefix:-$PROJECT_ROOT/install-deps}"
LOG_DIR="$PROJECT_ROOT/build-logs"

NUM_PROC=${NUM_PROC:-8}
# === 编译器设置 (macOS) ===
# 优先使用 Homebrew LLVM (包含内置 OpenMP)
if [[ "$(uname)" == "Darwin" ]]; then
    # 检测 Homebrew LLVM (ARM)
    if [ -x "/opt/homebrew/opt/llvm/bin/clang++" ]; then
        export CC="/opt/homebrew/opt/llvm/bin/clang"
        export CXX="/opt/homebrew/opt/llvm/bin/clang++"
        # 添加 OpenMP 支持 (使用 LLVM 内置 libomp)
        export OMP_LDFLAGS="-L/opt/homebrew/opt/llvm/lib -lomp"
        export CFLAGS="-fPIC -O3 -fopenmp"
        export CXXFLAGS="-fPIC -O3 -fopenmp"
        export LDFLAGS="$OMP_LDFLAGS"
        echo ">>> 使用 Homebrew LLVM (ARM): $CXX (内置 OpenMP)"
    # 检测 Homebrew LLVM (Intel)
    elif [ -x "/usr/local/opt/llvm/bin/clang++" ]; then
        export CC="/usr/local/opt/llvm/bin/clang"
        export CXX="/usr/local/opt/llvm/bin/clang++"
        export OMP_LDFLAGS="-L/usr/local/opt/llvm/lib -lomp"
        export CFLAGS="-fPIC -O3 -fopenmp"
        export CXXFLAGS="-fPIC -O3 -fopenmp"
        export LDFLAGS="$OMP_LDFLAGS"
        echo ">>> 使用 Homebrew LLVM (Intel): $CXX (内置 OpenMP)"
    fi
fi

# 强制重装标志
FORCE_REBUILD=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_REBUILD=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  -f, --force    强制重新构建所有库（忽略已安装的库）"
            echo "  -h, --help     显示此帮助信息"
            echo ""
            echo "默认行为: 跳过已安装的库，只构建缺失的库"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 -h 查看帮助"
            exit 1
            ;;
    esac
done

# 检查库是否已安装
is_installed() {
    local prefix_dir="$1"
    local check_file="$2"
    
    if [ "$FORCE_REBUILD" = true ]; then
        return 1  # 返回未安装，强制重装
    fi
    
    if [ -d "$INSTALL_PREFIX/$prefix_dir" ] && [ -f "$INSTALL_PREFIX/$prefix_dir/$check_file" ]; then
        return 0  # 已安装
    fi
    return 1  # 未安装
}

echo "=== 构建 qlat 依赖库 ==="
if [ "$FORCE_REBUILD" = true ]; then
    echo "模式: 强制重装所有库"
else
    echo "模式: 跳过已安装的库"
fi
echo "安装路径: $INSTALL_PREFIX"
echo "并行数: $NUM_PROC"
echo "日志目录: $LOG_DIR"
echo ""

mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_PREFIX"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/build-deps.log"
exec > >(tee -a "$LOG_FILE") 2>&1

cd "$BUILD_DIR"

build_lib_to_prefix() {
    local name="$1"
    local src_dir="$2"
    local prefix_dir="$3"
    local configure_cmd="$4"
    
    local full_prefix="$INSTALL_PREFIX/$prefix_dir"
    local lib_log="$LOG_DIR/${prefix_dir}.log"
    
    echo ">>> 构建 $name -> $full_prefix"
    
    rm -rf "$prefix_dir"
    if [ -d "$DISTFILES_DIR/$src_dir" ]; then
        rsync -a --delete "$DISTFILES_DIR/$src_dir/" "$src_dir/"
    else
        echo "    错误: 未找到 $src_dir"
        return 1
    fi
    
    cd "$src_dir"
    mkdir -p "$full_prefix"
    {
        echo "=== 配置 $name ==="
        eval "$configure_cmd"
        echo "=== 编译 $name ==="
        make -j$NUM_PROC
        echo "=== 安装 $name ==="
        make install
    } 2>&1 | tee "$lib_log"
    cd "$BUILD_DIR"
}

install_eigen() {
    # 检查是否已安装
    if is_installed "eigen" "include/eigen3/Eigen/Dense"; then
        echo ">>> 跳过 eigen (已安装)"
        return 0
    fi
    
    local eigen_dir="eigen-3.4.0"
    local eigen_src=""
    local eigen_prefix="$INSTALL_PREFIX/eigen"
    local lib_log="$LOG_DIR/eigen.log"
    
    if [ -d "$DISTFILES_DIR/$eigen_dir" ]; then
        eigen_src="$DISTFILES_DIR/$eigen_dir"
    elif [ -f "$DISTFILES_DIR/eigen-3.4.0.tar.bz2" ]; then
        echo ">>> 解压 eigen-3.4.0"
        rm -rf "$eigen_dir"
        tar xjf "$DISTFILES_DIR/eigen-3.4.0.tar.bz2"
        eigen_src="$BUILD_DIR/$eigen_dir"
    fi
    
    if [ -n "$eigen_src" ] && [ -d "$eigen_src" ]; then
        echo ">>> 安装 eigen-3.4.0 -> $eigen_prefix"
        {
            echo "=== 安装 Eigen ==="
            mkdir -p "$eigen_prefix/include/eigen3"
            cp -r "$eigen_src/Eigen" "$eigen_prefix/include/eigen3/"
            cp -r "$eigen_src/unsupported" "$eigen_prefix/include/eigen3/"
            if [ -f "$eigen_src/signature_of_eigen3_matrix_library" ]; then
                cp "$eigen_src/signature_of_eigen3_matrix_library" "$eigen_prefix/include/eigen3/"
            fi
        } 2>&1 | tee "$lib_log"
    else
        echo ">>> 跳过 eigen (未找到)"
    fi
}

build_fftw() {
    # 检查是否已安装
    if is_installed "fftw" "lib/libfftw3.so"; then
        echo ">>> 跳过 fftw (已安装)"
        return 0
    fi
    
    local fftw_dir="fftw-3.3.10"
    local fftw_src=""
    local fftw_prefix="$INSTALL_PREFIX/fftw"
    local lib_log="$LOG_DIR/fftw.log"
    
    if [ -d "$DISTFILES_DIR/$fftw_dir" ]; then
        fftw_src="$DISTFILES_DIR/$fftw_dir"
    elif [ -f "$DISTFILES_DIR/fftw-3.3.10.tar.gz" ]; then
        echo ">>> 解压 fftw-3.3.10"
        rm -rf "$fftw_dir"
        tar xzf "$DISTFILES_DIR/fftw-3.3.10.tar.gz"
        fftw_src="$BUILD_DIR/$fftw_dir"
    fi
    
    if [ -n "$fftw_src" ] && [ -d "$fftw_src" ]; then
        cd "$fftw_src"
        
        {
            echo "=== 构建 fftw-3.3.10 (double) -> $fftw_prefix ==="
            make distclean 2>/dev/null || true
            mkdir -p "$fftw_prefix"
            CFLAGS="-fPIC -O3" CXXFLAGS="-fPIC -O3" ./configure --prefix="$fftw_prefix" --enable-shared
            make -j$NUM_PROC
            make install
            
            echo "=== 构建 fftw-3.3.10 (float) -> $fftw_prefix ==="
            make clean
            CFLAGS="-fPIC -O3" CXXFLAGS="-fPIC -O3" ./configure --prefix="$fftw_prefix" --enable-float --enable-shared
            make -j$NUM_PROC
            make install
        } 2>&1 | tee "$lib_log"
        cd "$BUILD_DIR"
    else
        echo ">>> 跳过 fftw (未找到)"
    fi
}

build_zlib() {
    # 检查是否已安装
    if is_installed "zlib" "lib/libz.so"; then
        echo ">>> 跳过 zlib (已安装)"
        return 0
    fi
    
    local zlib_name=$(ls "$DISTFILES_DIR"/zlib-*.* 2>/dev/null | head -1)
    local zlib_dir=""
    local zlib_prefix="$INSTALL_PREFIX/zlib"
    local lib_log="$LOG_DIR/zlib.log"
    
    if [ -d "$DISTFILES_DIR/zlib-"* ]; then
        zlib_dir=$(ls -d "$DISTFILES_DIR"/zlib-* 2>/dev/null | head -1)
        zlib_dir=$(basename "$zlib_dir")
    elif [ -n "$zlib_name" ]; then
        zlib_dir=$(basename "$zlib_name" .tar.gz)
        if [ ! -d "$zlib_dir" ]; then
            echo ">>> 解压 $zlib_name"
            tar xzf "$zlib_name"
        fi
        zlib_dir="$BUILD_DIR/$zlib_dir"
    else
        zlib_dir=""
    fi
    
    if [ -n "$zlib_dir" ] && [ -d "$zlib_dir" ]; then
        local dir_name=$(basename "$zlib_dir")
        local prefix="$INSTALL_PREFIX/zlib"
        echo ">>> 构建 $dir_name -> $prefix"
        cd "$zlib_dir"
        {
            echo "=== 配置 $dir_name ==="
            mkdir -p "$prefix"
            CFLAGS="-O3 -fPIC" ./configure --prefix="$prefix"
            echo "=== 编译 $dir_name ==="
            make -j$NUM_PROC
            echo "=== 安装 $dir_name ==="
            make install
        } 2>&1 | tee "$lib_log"
        cd "$BUILD_DIR"
    else
        echo ">>> 跳过 zlib (未找到)"
    fi
}

build_gmp() {
    # 检查是否已安装
    if is_installed "gmp" "lib/libgmp.so"; then
        echo ">>> 跳过 gmp (已安装)"
        return 0
    fi
    
    local gmp_name=$(ls "$DISTFILES_DIR"/gmp-*.* 2>/dev/null | head -1)
    local gmp_dir=""
    local gmp_prefix="$INSTALL_PREFIX/gmp"
    local lib_log="$LOG_DIR/gmp.log"
    
    if [ -d "$DISTFILES_DIR/gmp-"* ]; then
        gmp_dir=$(ls -d "$DISTFILES_DIR"/gmp-* 2>/dev/null | head -1)
        gmp_dir=$(basename "$gmp_dir")
    elif [ -n "$gmp_name" ]; then
        gmp_dir=$(basename "$gmp_name" .tar.xz)
        if [ ! -d "$gmp_dir" ]; then
            echo ">>> 解压 $gmp_name"
            tar xJf "$gmp_name"
        fi
        gmp_dir="$BUILD_DIR/$gmp_dir"
    else
        gmp_dir=""
    fi
    
    if [ -n "$gmp_dir" ] && [ -d "$gmp_dir" ]; then
        local dir_name=$(basename "$gmp_dir")
        local prefix="$INSTALL_PREFIX/gmp"
        echo ">>> 构建 $dir_name -> $prefix"
        cd "$gmp_dir"
        {
            echo "=== 配置 $dir_name ==="
            mkdir -p "$prefix"
            CFLAGS="-O3 -fPIC" CXXFLAGS="-O3 -fPIC" ./configure --prefix="$prefix" --enable-shared
            echo "=== 编译 $dir_name ==="
            make -j$NUM_PROC
            echo "=== 安装 $dir_name ==="
            make install
        } 2>&1 | tee "$lib_log"
        cd "$BUILD_DIR"
    else
        echo ">>> 跳过 gmp (未找到)"
    fi
}

build_mpfr() {
    # 检查是否已安装
    if is_installed "mpfr" "lib/libmpfr.so"; then
        echo ">>> 跳过 mpfr (已安装)"
        return 0
    fi
    
    local mpfr_name=$(ls "$DISTFILES_DIR"/mpfr-*.* 2>/dev/null | head -1)
    local mpfr_dir=""
    local mpfr_prefix="$INSTALL_PREFIX/mpfr"
    local gmp_prefix="$INSTALL_PREFIX/gmp"
    local lib_log="$LOG_DIR/mpfr.log"
    
    if [ -d "$DISTFILES_DIR/mpfr-"* ]; then
        mpfr_dir=$(ls -d "$DISTFILES_DIR"/mpfr-* 2>/dev/null | head -1)
        mpfr_dir=$(basename "$mpfr_dir")
    elif [ -n "$mpfr_name" ]; then
        mpfr_dir=$(basename "$mpfr_name" .tar.xz)
        if [ ! -d "$mpfr_dir" ]; then
            echo ">>> 解压 $mpfr_name"
            tar xJf "$mpfr_name"
        fi
        mpfr_dir="$BUILD_DIR/$mpfr_dir"
    else
        mpfr_dir=""
    fi
    
    if [ -n "$mpfr_dir" ] && [ -d "$mpfr_dir" ]; then
        local dir_name=$(basename "$mpfr_dir")
        local prefix="$INSTALL_PREFIX/mpfr"
        echo ">>> 构建 $dir_name -> $prefix"
        cd "$mpfr_dir"
        {
            echo "=== 配置 $dir_name ==="
            mkdir -p "$prefix"
            CFLAGS="-O3 -fPIC" CXXFLAGS="-O3 -fPIC" \
                ./configure --prefix="$prefix" --with-gmp="$gmp_prefix" --enable-shared
            echo "=== 编译 $dir_name ==="
            make -j$NUM_PROC
            echo "=== 安装 $dir_name ==="
            make install
        } 2>&1 | tee "$lib_log"
        cd "$BUILD_DIR"
    else
        echo ">>> 跳过 mpfr (未找到)"
    fi
}

build_cuba() {
    # 检查是否已安装
    if is_installed "cuba" "lib/libcuba.a"; then
        echo ">>> 跳过 cuba (已安装)"
        return 0
    fi
    
    local cuba_dir="Cuba-4.2.2"
    local cuba_prefix="$INSTALL_PREFIX/cuba"
    local lib_log="$LOG_DIR/cuba.log"
    
    if [ -d "$DISTFILES_DIR/$cuba_dir" ]; then
        echo ">>> 构建 Cuba-4.2.2 -> $cuba_prefix"
        rm -rf "$cuba_dir"
        rsync -a --delete "$DISTFILES_DIR/$cuba_dir/" "$cuba_dir/"
        cd "$cuba_dir"
        {
            echo "=== 配置 Cuba ==="
            mkdir -p "$cuba_prefix"
            CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix="$cuba_prefix"
            echo "=== 编译 Cuba (单线程) ==="
            make
            echo "=== 安装 Cuba ==="
            make install
        } 2>&1 | tee "$lib_log"
        cd "$BUILD_DIR"
    elif [ -f "$DISTFILES_DIR/Cuba-4.2.2.tar.gz" ]; then
        echo ">>> 解压并构建 Cuba-4.2.2 -> $cuba_prefix"
        rm -rf "$cuba_dir"
        tar xzf "$DISTFILES_DIR/Cuba-4.2.2.tar.gz"
        cd "$cuba_dir"
        {
            echo "=== 配置 Cuba ==="
            mkdir -p "$cuba_prefix"
            CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix="$cuba_prefix"
            echo "=== 编译 Cuba (单线程) ==="
            make
            echo "=== 安装 Cuba ==="
            make install
        } 2>&1 | tee "$lib_log"
        cd "$BUILD_DIR"
    else
        echo ">>> 跳过 Cuba (未找到)"
    fi
}

build_lime() {
    # 检查是否已安装
    if is_installed "lime" "lib/liblime.a"; then
        echo ">>> 跳过 lime (已安装)"
        return 0
    fi
    
    local lime_dir="lime-1.3.2"
    local lime_prefix="$INSTALL_PREFIX/lime"
    local lib_log="$LOG_DIR/lime.log"
    
    if [ -d "$DISTFILES_DIR/$lime_dir" ]; then
        echo ">>> 构建 lime-1.3.2 -> $lime_prefix"
        rm -rf "$lime_dir"
        rsync -a --delete "$DISTFILES_DIR/$lime_dir/" "$lime_dir/"
        cd "$lime_dir"
        {
            echo "=== 配置 Lime ==="
            mkdir -p "$lime_prefix"
            CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix="$lime_prefix"
            echo "=== 编译 Lime ==="
            make -j$NUM_PROC
            echo "=== 安装 Lime ==="
            make install
        } 2>&1 | tee "$lib_log"
        cd "$BUILD_DIR"
    elif [ -f "$DISTFILES_DIR/lime-1.3.2.tar.gz" ]; then
        echo ">>> 解压并构建 lime-1.3.2 -> $lime_prefix"
        rm -rf "$lime_dir"
        tar xzf "$DISTFILES_DIR/lime-1.3.2.tar.gz"
        cd "$lime_dir"
        {
            echo "=== 配置 Lime ==="
            mkdir -p "$lime_prefix"
            CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix="$lime_prefix"
            echo "=== 编译 Lime ==="
            make -j$NUM_PROC
            echo "=== 安装 Lime ==="
            make install
        } 2>&1 | tee "$lib_log"
        cd "$BUILD_DIR"
    else
        echo ">>> 跳过 Lime (未找到)"
    fi
}

build_hdf5() {
    # 检查是否已安装
    if is_installed "hdf5" "lib/libhdf5.a"; then
        echo ">>> 跳过 hdf5 (已安装)"
        return 0
    fi
    
    local hdf5_dir="hdf5-1.14.5"
    local hdf5_prefix="$INSTALL_PREFIX/hdf5"
    local lib_log="$LOG_DIR/hdf5.log"
    local zlib_prefix="$INSTALL_PREFIX/zlib"
    
    # 查找源码目录
    local hdf5_src=""
    if [ -d "$DISTFILES_DIR/$hdf5_dir" ]; then
        hdf5_src="$DISTFILES_DIR/$hdf5_dir"
    elif [ -f "$DISTFILES_DIR/hdf5-1.14.5.tar.gz" ]; then
        echo ">>> 解压 hdf5-1.14.5"
        rm -rf "$hdf5_dir"
        tar xzf "$DISTFILES_DIR/hdf5-1.14.5.tar.gz"
        hdf5_src="$BUILD_DIR/$hdf5_dir"
    elif [ -f "$DISTFILES_DIR/hdf5-1.14.5.tar.bz2" ]; then
        echo ">>> 解压 hdf5-1.14.5"
        rm -rf "$hdf5_dir"
        tar xjf "$DISTFILES_DIR/hdf5-1.14.5.tar.bz2"
        hdf5_src="$BUILD_DIR/$hdf5_dir"
    fi
    
    if [ -n "$hdf5_src" ] && [ -d "$hdf5_src" ]; then
        echo ">>> 构建 HDF5 -> $hdf5_prefix"
        cd "$hdf5_src"
        rm -rf "build"
        mkdir -p "build"
        cd "build"
        {
            echo "=== 配置 HDF5 (静态库 + C++ 支持) ==="
            cmake .. \
                -DCMAKE_INSTALL_PREFIX="$hdf5_prefix" \
                -DCMAKE_BUILD_TYPE=Release \
                -DBUILD_SHARED_LIBS=OFF \
                -DBUILD_STATIC_LIBS=ON \
                -DHDF5_BUILD_CPP_LIB=ON \
                -DHDF5_BUILD_HL_LIB=ON \
                -DHDF5_BUILD_EXAMPLES=OFF \
                -DHDF5_BUILD_TESTS=OFF \
                -DZLIB_INCLUDE_DIR="$zlib_prefix/include" \
                -DZLIB_LIBRARY="$zlib_prefix/lib/libz.a"
            echo "=== 编译 HDF5 ==="
            make -j$NUM_PROC
            echo "=== 安装 HDF5 ==="
            make install
        } 2>&1 | tee "$lib_log"
        cd "$BUILD_DIR"
    else
        echo ">>> 跳过 HDF5 (未找到)"
    fi
}

build_grid() {
    # 检查是否已安装
    if is_installed "Grid-clehner" "lib/libGrid.a"; then
        echo ">>> 跳过 Grid (已安装)"
        return 0
    fi
    
    local grid_dir="Grid-clehner"
    local grid_prefix="$INSTALL_PREFIX/Grid-clehner"
    
    # 根据系统选择 Grid 构建脚本
    local grid_script
    if [[ "$(uname)" == "Darwin" ]]; then
        grid_script="$SCRIPT_DIR/build-grid-mac.sh"
        echo ">>> 检测到 macOS，使用 build-grid-mac.sh"
    else
        # Linux: 检测 CPU 是否支持 SVE
        if command -v lscpu &> /dev/null && lscpu | grep -q "sve"; then
            grid_script="$SCRIPT_DIR/build-grid-sve.sh"
            echo ">>> 检测到 Linux HPC (支持 SVE)，使用 build-grid-sve.sh"
        else
            grid_script="$SCRIPT_DIR/build-grid-neonv8.sh"
            echo ">>> 检测到 Linux HPC (NEONv8，无 SVE)，使用 build-grid-neonv8.sh"
        fi
    fi
    
    # 支持目录或 tar.gz
    if [ -d "$DISTFILES_DIR/$grid_dir" ]; then
        echo ">>> 构建 Grid -> $grid_prefix (使用目录)"
        export GRID_PREFIX="$grid_prefix"
        export INSTALL_PREFIX="$INSTALL_PREFIX"
        "$grid_script" 2>&1 | tee "$LOG_DIR/grid.log"
    elif [ -f "$DISTFILES_DIR/$grid_dir.tar.gz" ]; then
        echo ">>> 构建 Grid -> $grid_prefix (使用 tar.gz)"
        export GRID_PREFIX="$grid_prefix"
        export INSTALL_PREFIX="$INSTALL_PREFIX"
        "$grid_script" 2>&1 | tee "$LOG_DIR/grid.log"
    else
        echo ">>> 跳过 Grid (未找到 Grid-clehner)"
    fi
}

echo ">>> 步骤 1: 构建 zlib"
build_zlib

echo ""
echo ">>> 步骤 2: 构建 FFTW"
build_fftw

echo ""
echo ">>> 步骤 3: 安装 Eigen"
install_eigen

echo ""
echo ">>> 步骤 4: 构建 GMP (可选，用于Grid高精度计算)"
build_gmp

echo ""
echo ">>> 步骤 5: 构建 MPFR (可选，用于Grid高精度计算)"
build_mpfr

echo ""
echo ">>> 步骤 6: 构建 Cuba (可选)"
build_cuba

echo ""
echo ">>> 步骤 7: 构建 Lime (可选)"
build_lime

echo ""
echo ">>> 步骤 8: 构建 HDF5 (可选，用于 Grid I/O)"
build_hdf5

echo ""
echo ">>> 步骤 9: 构建 Grid (可选，需要qlat-grid时)"
build_grid

# 清理 build 目录（可选，注释掉以便调试）
# echo ""
# echo ">>> 清理 build 目录" | tee -a "$LOG_FILE"
# cd "$PROJECT_ROOT"
# rm -rf "$BUILD_DIR"
# echo "已删除 build-deps 目录" | tee -a "$LOG_FILE"

echo ""
echo "=== 依赖库构建完成 ==="
echo "安装目录: $INSTALL_PREFIX"
echo "日志目录: $LOG_DIR"
echo ""
echo "结构:"
echo "  $INSTALL_PREFIX/"
echo "  ├── zlib/"
echo "  ├── fftw/"
echo "  ├── eigen/"
echo "  ├── gmp/"
echo "  ├── mpfr/"
echo "  ├── cuba/"
echo "  ├── lime/"
echo "  ├── hdf5/"
echo "  └── Grid-clehner/"
echo ""
echo "日志文件:"
ls -la "$LOG_DIR"/*.log 2>/dev/null || echo "  (无日志文件)"
