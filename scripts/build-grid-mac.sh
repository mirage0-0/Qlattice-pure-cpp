#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISTFILES_DIR="$PROJECT_ROOT/distfiles"
GRID_PREFIX="${GRID_PREFIX:-$prefix/Grid-clehner}"
INSTALL_PREFIX="${INSTALL_PREFIX:-$prefix}"
GRID_BUILD="$PROJECT_ROOT/build-deps/grid"
LOG_DIR="$PROJECT_ROOT/build-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/grid-build.log"
NUM_PROC=${NUM_PROC:-4}

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
        echo ">>> 使用 Homebrew LLVM (ARM): $CXX (内置 OpenMP)" | tee -a "$LOG_FILE"
    # 检测 Homebrew LLVM (Intel)
    elif [ -x "/usr/local/opt/llvm/bin/clang++" ]; then
        export CC="/usr/local/opt/llvm/bin/clang"
        export CXX="/usr/local/opt/llvm/bin/clang++"
        export OMP_LDFLAGS="-L/usr/local/opt/llvm/lib -lomp"
        export CFLAGS="-fPIC -O3 -fopenmp"
        export CXXFLAGS="-fPIC -O3 -fopenmp"
        export LDFLAGS="$OMP_LDFLAGS"
        echo ">>> 使用 Homebrew LLVM (Intel): $CXX (内置 OpenMP)" | tee -a "$LOG_FILE"
    fi
fi

# 检查 prefix 环境变量
if [ -z "$prefix" ] && [ -z "$INSTALL_PREFIX" ]; then
    echo "错误: 请设置 prefix 环境变量，例如: prefix=/path/to/install ./build-grid-sve.sh"
    echo "或者设置 INSTALL_PREFIX 环境变量"
    exit 1
fi


echo "=== 构建 Grid (macOS Apple Silicon) ===" | tee -a "$LOG_FILE"
echo "日志文件: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ -d "$DISTFILES_DIR/Grid-clehner" ] ; then
    GRID_SRC="$DISTFILES_DIR/Grid-clehner"
elif [ -f "$DISTFILES_DIR/Grid-clehner.tar.gz" ] ; then
    GRID_SRC="$DISTFILES_DIR/Grid-clehner"
else
    echo "错误: Grid-clehner 未找到 (目录或 tar.gz)" | tee -a "$LOG_FILE"
    exit 1
fi

echo "安装路径: $GRID_PREFIX" | tee -a "$LOG_FILE"
echo "源: $GRID_SRC" | tee -a "$LOG_FILE"
echo "并行数: $NUM_PROC" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

mkdir -p "$GRID_BUILD"
mkdir -p "$GRID_PREFIX"

cd "$GRID_BUILD"

echo ">>> 准备 Grid 源码" | tee -a "$LOG_FILE"
rm -rf Grid-clehner

if [ -d "$GRID_SRC" ] ; then
    rsync -a --delete "$GRID_SRC/" Grid-clehner/ 2>&1 | tee -a "$LOG_FILE"
elif [ -f "$GRID_SRC.tar.gz" ] ; then
    echo "解压 Grid tarball..." | tee -a "$LOG_FILE"
    rm -rf Grid-clehner
    mkdir -p Grid-clehner
    tar xzf "$GRID_SRC.tar.gz" -C Grid-clehner --strip-components=1 2>&1 | tee -a "$LOG_FILE"
fi

if [ ! -d "Grid-clehner" ] ; then
    echo "错误: 无法解压 Grid" | tee -a "$LOG_FILE"
    exit 1
fi

cd Grid-clehner

INITDIR="$(pwd)"

echo ">>> 处理 Eigen" | tee -a "$LOG_FILE"
rm -rfv "${INITDIR}/Eigen/Eigen/unsupported" 2>/dev/null || true
rm -rfv "${INITDIR}/Grid/Eigen" 2>/dev/null || true

EIGEN_INCLUDE="$INSTALL_PREFIX/eigen/include/eigen3"
if [ -d "$EIGEN_INCLUDE" ] ; then
    echo "使用系统 Eigen: $EIGEN_INCLUDE" | tee -a "$LOG_FILE"
    mkdir -p "${INITDIR}/Grid/Eigen"
    rsync -av --delete "$EIGEN_INCLUDE/Eigen/" "${INITDIR}/Grid/Eigen/" 2>&1 | tee -a "$LOG_FILE"
    rsync -av --delete "$EIGEN_INCLUDE/unsupported/Eigen/" "${INITDIR}/Grid/Eigen/unsupported/" 2>/dev/null || true
    cd "${INITDIR}/Grid"
    echo 'eigen_files =\' > "${INITDIR}/Grid/Eigen.inc"
    find -L Eigen -type f -print | sed 's/^/  /;$q;s/$/ \\/' >> "${INITDIR}/Grid/Eigen.inc"
    cd "${INITDIR}"
else
    echo "警告: 未找到系统 Eigen，使用 bundled" | tee -a "$LOG_FILE"
    ln -vs "${INITDIR}/Eigen/Eigen" "${INITDIR}/Grid/Eigen" 2>/dev/null || true
    ln -vs "${INITDIR}/Eigen/unsupported/Eigen" "${INITDIR}/Grid/Eigen/unsupported" 2>/dev/null || true
fi

export CXXFLAGS="-fPIC -DUSE_QLATTILE -fopenmp -w -Wno-psabi "
export CFLAGS="-fPIC"

# 添加 OpenSSL 路径
if [ -d "/opt/homebrew/opt/openssl@3" ]; then
    export CPPFLAGS="-I/opt/homebrew/opt/openssl@3/include $CPPFLAGS"
    export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib $LDFLAGS"
fi

FFTW_PREFIX="$INSTALL_PREFIX/fftw"
LIME_PREFIX="$INSTALL_PREFIX/lime"
HDF5_PREFIX="$INSTALL_PREFIX/hdf5"
GMP_PREFIX="$INSTALL_PREFIX/gmp"
MPFR_PREFIX="$INSTALL_PREFIX/mpfr"


if [ -d "$GMP_PREFIX/lib" ] || [ -d "$GMP_PREFIX/lib64" ] ; then
    GMP_LIB=$(ls -d $GMP_PREFIX/lib* 2>/dev/null | head -1)
    if [ -n "$GMP_LIB" ]; then
        LDFLAGS+=" -L$GMP_LIB"
        CPPFLAGS+=" -I$GMP_PREFIX/include"
    fi
fi

if [ -d "$MPFR_PREFIX/lib" ] || [ -d "$MPFR_PREFIX/lib64" ] ; then
    MPFR_LIB=$(ls -d $MPFR_PREFIX/lib* 2>/dev/null | head -1)
    if [ -n "$MPFR_LIB" ]; then
        LDFLAGS+=" -L$MPFR_LIB"
        CPPFLAGS+=" -I$MPFR_PREFIX/include"
    fi
fi

if [ -d "$FFTW_PREFIX/lib" ] || [ -d "$FFTW_PREFIX/lib64" ] ; then
    FFTW_LIB=$(ls -d $FFTW_PREFIX/lib* 2>/dev/null | head -1)
    if [ -n "$FFTW_LIB" ]; then
        LDFLAGS+=" -L$FFTW_LIB"
        CPPFLAGS+=" -I$FFTW_PREFIX/include"
    fi
fi

# 添加 OpenSSL 路径
if [ -d "/opt/homebrew/opt/openssl@3" ]; then
    CPPFLAGS="-I/opt/homebrew/opt/openssl@3/include $CPPFLAGS"
    LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib $LDFLAGS"
fi

if [ -n "$LDFLAGS" ]; then
    export LDFLAGS
    export CPPFLAGS
    echo "设置 LDFLAGS: $LDFLAGS" | tee -a "$LOG_FILE"
    echo "设置 CPPFLAGS: $CPPFLAGS" | tee -a "$LOG_FILE"
fi

echo "检测依赖库..." | tee -a "$LOG_FILE"
echo "  FFTW_PREFIX: $FFTW_PREFIX" | tee -a "$LOG_FILE"
echo "  LIME_PREFIX: $LIME_PREFIX" | tee -a "$LOG_FILE"
echo "  HDF5_PREFIX: $HDF5_PREFIX" | tee -a "$LOG_FILE"
echo "  GMP_PREFIX: $GMP_PREFIX" | tee -a "$LOG_FILE"
echo "  MPFR_PREFIX: $MPFR_PREFIX" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ -d "$FFTW_PREFIX/lib" ] || [ -d "$FFTW_PREFIX/lib64" ] ; then
    FFTW_LIB_DIR=$(ls -d $FFTW_PREFIX/lib* 2>/dev/null | head -1)
    if [ -f "$FFTW_LIB_DIR/libfftw3.a" ] || [ -f "$FFTW_LIB_DIR/libfftw3.so" ]; then
        opts+=" --with-fftw=$FFTW_PREFIX"
        echo "  -> FFTW 已启用 ($FFTW_PREFIX)" | tee -a "$LOG_FILE"
    fi
fi

if [ -d "$LIME_PREFIX/lib" ] || [ -d "$LIME_PREFIX/lib64" ] ; then
    LIME_LIB_DIR=$(ls -d $LIME_PREFIX/lib* 2>/dev/null | head -1)
    if [ -f "$LIME_LIB_DIR/liblime.a" ] || [ -f "$LIME_LIB_DIR/liblime.so" ]; then
        opts+=" --with-lime=$LIME_PREFIX"
        echo "  -> LIME 已启用 ($LIME_PREFIX)" | tee -a "$LOG_FILE"
    fi
fi

if [ -d "$HDF5_PREFIX/lib" ] || [ -d "$HDF5_PREFIX/lib64" ] ; then
    HDF5_LIB_DIR=$(ls -d $HDF5_PREFIX/lib* 2>/dev/null | head -1)
    if [ -f "$HDF5_LIB_DIR/libhdf5_hl_cpp.a" ] || [ -f "$HDF5_LIB_DIR/libhdf5_hl_cpp.so" ]; then
        opts+=" --with-hdf5=$HDF5_PREFIX"
        echo "  -> HDF5 已启用 ($HDF5_PREFIX)" | tee -a "$LOG_FILE"
    fi
fi

if [ -d "$GMP_PREFIX/lib" ] || [ -d "$GMP_PREFIX/lib64" ] ; then
    GMP_LIB_DIR=$(ls -d $GMP_PREFIX/lib* 2>/dev/null | head -1)
    if [ -f "$GMP_LIB_DIR/libgmp.a" ] || [ -f "$GMP_LIB_DIR/libgmp.so" ]; then
        opts+=" --with-gmp=$GMP_PREFIX"
        echo "  -> GMP 已启用 ($GMP_PREFIX)" | tee -a "$LOG_FILE"
    fi
fi

if [ -d "$MPFR_PREFIX/lib" ] || [ -d "$MPFR_PREFIX/lib64" ] ; then
    MPFR_LIB_DIR=$(ls -d $MPFR_PREFIX/lib* 2>/dev/null | head -1)
    if [ -f "$MPFR_LIB_DIR/libmpfr.a" ] || [ -f "$MPFR_LIB_DIR/libmpfr.so" ]; then
        opts+=" --with-mpfr=$MPFR_PREFIX"
        echo "  -> MPFR 已启用 ($MPFR_PREFIX)" | tee -a "$LOG_FILE"
    else
        echo "  -> MPFR 库文件未找到 (libmpfr.a 或 libmpfr.so)" | tee -a "$LOG_FILE"
        ls -la "$MPFR_LIB_DIR/" 2>/dev/null | tee -a "$LOG_FILE" || echo "无法列出 $MPFR_LIB_DIR 内容" | tee -a "$LOG_FILE"
    fi
else
    echo "  -> MPFR 库目录不存在: $MPFR_PREFIX/lib*" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "检测到的选项: $opts" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# 如果 Eigen 已存在，跳过 bootstrap 中的 Eigen 下载，直接运行 update_eigen.sh 和 autoreconf
echo ">>> 运行 bootstrap (跳过 Eigen 下载，使用本地 Eigen)" | tee -a "$LOG_FILE"
if [ -d "${INITDIR}/Grid/Eigen" ]; then
    echo "使用已配置的 Eigen，跳过下载" | tee -a "$LOG_FILE"
    # 运行 filelist 和 autoreconf
    ./scripts/filelist 2>&1 | tee -a "$LOG_FILE"
    autoreconf -fvi 2>&1 | tee -a "$LOG_FILE"
else
    ./bootstrap.sh 2>&1 | tee -a "$LOG_FILE"
fi

echo ">>> 配置 Grid (macOS Apple Silicon 256-bit)" | tee -a "$LOG_FILE"
mkdir -p build
cd build

../configure \
    --enable-simd=GEN \
    --enable-gen-simd-width=32 \
    --enable-alloc-align=4k \
    --enable-comms=mpi-auto \
    --enable-gparity=no \
    --enable-unified=yes \
    --enable-shm=no \
    --enable-shm-fast-path=no \
    --disable-fermion-reps \
    $opts \
    --prefix="$GRID_PREFIX" 2>&1 | tee -a "$LOG_FILE"

echo ">>> 编译 Grid" | tee -a "$LOG_FILE"
make -j$NUM_PROC -C Grid 2>&1 | tee -a "$LOG_FILE"

echo ">>> 安装 Grid" | tee -a "$LOG_FILE"
make install -C Grid 2>&1 | tee -a "$LOG_FILE"

# 清理 build 目录（可选，注释掉以便调试）
# echo "" | tee -a "$LOG_FILE"
# echo ">>> 清理 build 目录" | tee -a "$LOG_FILE"
# cd "$PROJECT_ROOT"
# rm -rf "$GRID_BUILD"
# echo "已删除 build-grid 目录" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=== Grid 构建完成 ===" | tee -a "$LOG_FILE"
echo "安装路径: $GRID_PREFIX" | tee -a "$LOG_FILE"
echo "日志文件: $LOG_FILE" | tee -a "$LOG_FILE"
