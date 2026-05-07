#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPS_PREFIX="${prefix:-$SCRIPT_DIR/install-deps}"
QLAT_PREFIX="${prefix:-$SCRIPT_DIR/install}"

export prefix="$DEPS_PREFIX"
export CMAKE_PREFIX_PATH="$DEPS_PREFIX"

echo "=============================================="
echo "qlat_cmake_0.90 完整构建流程"
echo "=============================================="
echo ""
echo "依赖库安装路径: $DEPS_PREFIX"
echo "qlat 安装路径: $QLAT_PREFIX"
echo ""

# ========== 步骤 1: 构建依赖库 ==========
echo ">>> 步骤 1: 构建依赖库"
"$SCRIPT_DIR/build-deps.sh"

# ========== 步骤 2: 构建 qlat ==========
echo ""
echo ">>> 步骤 2: 构建 qlat"

cd "$SCRIPT_DIR"

mkdir -p build
cd build

cmake .. -DCMAKE_INSTALL_PREFIX="$QLAT_PREFIX" \
         -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" \
         -DEIGEN_PREFIX="$DEPS_PREFIX"

make -j ${NUM_PROC:-4}
make install

cd "$SCRIPT_DIR"
rm -rf build

echo ""
echo "=============================================="
echo "构建完成!"
echo "=============================================="
echo ""
echo "依赖库: $DEPS_PREFIX"
echo "qlat: $QLAT_PREFIX"
echo ""
echo "使用方式:"
echo "  export LD_LIBRARY_PATH=$QLAT_PREFIX/lib:\$LD_LIBRARY_PATH"
