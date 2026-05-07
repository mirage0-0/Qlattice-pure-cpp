#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISTFILES_DIR="$PROJECT_ROOT/distfiles"

mkdir -p "$DISTFILES_DIR"
cd "$DISTFILES_DIR"

# 下载函数：支持 wget 或 curl，跳过已存在文件
download() {
    local url="$1"
    local name="$2"
    if [ -z "$name" ]; then
        name="${url##*/}"
    fi
    if [ -f "$name" ]; then
        echo ">>> 已存在: $name，跳过"
        return 0
    fi
    echo ">>> 下载: $name"
    if command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate -O "$name" -c "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$name" -C - "$url"
    else
        echo "错误: 未找到 wget 或 curl，请安装其中一个。"
        exit 1
    fi
}

echo "=== 下载 qlat 依赖库到 distfiles ==="
echo "目标目录: $DISTFILES_DIR"
echo ""

# 直接下载的压缩包（URL 来自上层 scripts/download-core.sh 和 download.sh）
download "http://usqcd-software.github.io/downloads/c-lime/lime-1.3.2.tar.gz"
download "https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.bz2"
download "https://fftw.org/pub/fftw/fftw-3.3.10.tar.gz"
download "https://github.com/jinluchang/Qlattice-distfiles/raw/main/distfiles/Cuba-4.2.2.tar.gz"
download "https://github.com/jinluchang/Qlattice-distfiles/raw/refs/heads/main/distfiles/hdf5-1.14.5.tar.gz"
download "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz"
download "https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz"
download "https://zlib.net/fossils/zlib-1.3.1.tar.gz"

# Grid-clehner：从 git 克隆、bootstrap 并打包（无现成 release tarball）
echo ""
echo "=== 准备 Grid-clehner ==="

if [ -f "$DISTFILES_DIR/Grid-clehner.tar.gz" ]; then
    echo ">>> 已存在: Grid-clehner.tar.gz，跳过"
else
    echo ">>> 将从 git 克隆 Grid-clehner 并打包 ..."
    echo "    注意：这需要 autotools 环境 (autoconf, automake, libtool)"

    for cmd in git autoreconf automake libtoolize; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "错误: 未找到 '$cmd'，无法自动打包 Grid-clehner。"
            echo "       请安装 autotools 后重试，或手动准备 Grid-clehner.tar.gz 放到:"
            echo "       $DISTFILES_DIR/"
            exit 1
        fi
    done

    TMPDIR=$(mktemp -d)
    (
        cd "$TMPDIR"
        git clone https://github.com/lehner/Grid.git Grid-clehner
        cd Grid-clehner
        if [ ! -f "configure" ]; then
            ./bootstrap.sh
        fi
        cd "$TMPDIR"
        tar czf "$DISTFILES_DIR/Grid-clehner.tar.gz" Grid-clehner
    )
    rm -rf "$TMPDIR"
    echo ">>> 已生成: Grid-clehner.tar.gz"
fi

echo ""
echo "=== 所有 distfiles 准备完成 ==="
ls -lh "$DISTFILES_DIR"
