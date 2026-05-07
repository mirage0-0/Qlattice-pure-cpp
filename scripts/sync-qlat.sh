#!/bin/bash

#=====================================================================
# sync-qlat.sh - 从 Qlattice-master 同步源文件到 qlat_cmake
# 
# 用法: 
#   ./sync-qlat.sh /path/to/Qlattice-master
#   ./sync-qlat.sh                       # 默认使用 ../Qlattice-master
#=====================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QLAT_CMAKE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 获取 Qlattice-master 路径
if [ -n "$1" ]; then
    QLAT_MASTER="$1"
elif [ -d "$SCRIPT_DIR/../../../Qlattice-master" ]; then
    QLAT_MASTER="$SCRIPT_DIR/../../../Qlattice-master"
elif [ -d "$SCRIPT_DIR/../../Qlattice-master" ]; then
    QLAT_MASTER="$SCRIPT_DIR/../../Qlattice-master"
elif [ -d "$SCRIPT_DIR/../Qlattice-master" ]; then
    QLAT_MASTER="$SCRIPT_DIR/../Qlattice-master"
else
    echo "错误: 找不到 Qlattice-master 目录"
    echo "请提供路径，例如: ./sync-qlat.sh /path/to/Qlattice-master"
    exit 1
fi

# 验证路径
if [ ! -d "$QLAT_MASTER" ]; then
    echo "错误: Qlattice-master 目录不存在: $QLAT_MASTER"
    exit 1
fi

echo "=== 同步 Qlattice-master -> qlat_cmake ==="
echo "源目录: $QLAT_MASTER"
echo "目标目录: $QLAT_CMAKE_DIR"
echo ""

#---------------------------------------------------------------------
# 1. 同步 qlat 源文件 (cpp)
#---------------------------------------------------------------------
echo ">>> 同步 qlat 源文件..."

# qlat/qlat/lib/*.cpp -> qlat/*.cpp
if [ -d "$QLAT_MASTER/qlat/qlat/lib" ]; then
    mkdir -p "$QLAT_CMAKE_DIR/qlat"
    rsync -av --delete \
        "$QLAT_MASTER/qlat/qlat/lib/"*.cpp \
        "$QLAT_CMAKE_DIR/qlat/" 2>/dev/null || true
    echo "  qlat/qlat/lib/*.cpp -> qlat/"
fi

# qlat/cqlat/*.cpp -> qlat/*.cpp
if [ -d "$QLAT_MASTER/qlat/cqlat" ]; then
    mkdir -p "$QLAT_CMAKE_DIR/qlat"
    rsync -av --delete \
        "$QLAT_MASTER/qlat/cqlat/"*.cpp \
        "$QLAT_CMAKE_DIR/qlat/" 2>/dev/null || true
    echo "  qlat/cqlat/*.cpp -> qlat/"
fi

#---------------------------------------------------------------------
# 2. 同步 qutils 源文件 (cpp)
#---------------------------------------------------------------------
echo ">>> 同步 qutils 源文件..."

# qlat-utils/qlat_utils/lib/*.cpp -> qutils/*.cpp
if [ -d "$QLAT_MASTER/qlat-utils/qlat_utils/lib" ]; then
    mkdir -p "$QLAT_CMAKE_DIR/qutils"
    rsync -av --delete \
        "$QLAT_MASTER/qlat-utils/qlat_utils/lib/"*.cpp \
        "$QLAT_CMAKE_DIR/qutils/" 2>/dev/null || true
    echo "  qlat-utils/qlat_utils/lib/*.cpp -> qutils/"
fi

#---------------------------------------------------------------------
# 3. 同步 qlat-grid 源文件 (cpp)
#---------------------------------------------------------------------
echo ">>> 同步 qlat-grid 源文件..."

# qlat-grid/qlat_grid/lib/*.cpp -> qlat-grid/*.cpp
if [ -d "$QLAT_MASTER/qlat-grid/qlat_grid/lib" ]; then
    mkdir -p "$QLAT_CMAKE_DIR/qlat-grid"
    rsync -av --delete \
        "$QLAT_MASTER/qlat-grid/qlat_grid/lib/"*.cpp \
        "$QLAT_CMAKE_DIR/qlat-grid/" 2>/dev/null || true
    echo "  qlat-grid/qlat_grid/lib/*.cpp -> qlat-grid/"
fi

#---------------------------------------------------------------------
# 4. 同步头文件
#---------------------------------------------------------------------
echo ">>> 同步头文件..."

# qlat/include/qlat/*.h -> include/qlat/*.h
if [ -d "$QLAT_MASTER/qlat/qlat/include/qlat" ]; then
    mkdir -p "$QLAT_CMAKE_DIR/include/qlat"
    rsync -av --delete \
        "$QLAT_MASTER/qlat/qlat/include/qlat/"*.h \
        "$QLAT_CMAKE_DIR/include/qlat/" 2>/dev/null || true
    echo "  qlat/qlat/include/qlat/*.h -> include/qlat/"
fi

# qlat/include/qlat/vector_utils/*.h -> include/qlat/vector_utils/*.h
if [ -d "$QLAT_MASTER/qlat/qlat/include/qlat/vector_utils" ]; then
    mkdir -p "$QLAT_CMAKE_DIR/include/qlat/vector_utils"
    rsync -av --delete \
        "$QLAT_MASTER/qlat/qlat/include/qlat/vector_utils/"*.h \
        "$QLAT_CMAKE_DIR/include/qlat/vector_utils/" 2>/dev/null || true
    echo "  qlat/qlat/include/qlat/vector_utils/*.h -> include/qlat/vector_utils/"
fi

# qlat-utils/include/qlat-utils/*.h -> include/qlat-utils/*.h
if [ -d "$QLAT_MASTER/qlat-utils/qlat_utils/include/qlat-utils" ]; then
    mkdir -p "$QLAT_CMAKE_DIR/include/qlat-utils"
    rsync -av --delete \
        "$QLAT_MASTER/qlat-utils/qlat_utils/include/qlat-utils/"*.h \
        "$QLAT_CMAKE_DIR/include/qlat-utils/" 2>/dev/null || true
    echo "  qlat-utils/qlat_utils/include/qlat-utils/*.h -> include/qlat-utils/"
fi

# qlat-grid/include/qlat-grid/*.h -> include/qlat-grid/*.h
if [ -d "$QLAT_MASTER/qlat-grid/qlat_grid/include/qlat-grid" ]; then
    mkdir -p "$QLAT_CMAKE_DIR/include/qlat-grid"
    rsync -av --delete \
        "$QLAT_MASTER/qlat-grid/qlat_grid/include/qlat-grid/"*.h \
        "$QLAT_CMAKE_DIR/include/qlat-grid/" 2>/dev/null || true
    echo "  qlat-grid/qlat_grid/include/qlat-grid/*.h -> include/qlat-grid/"
fi

#---------------------------------------------------------------------
# 统计
#---------------------------------------------------------------------
echo ""
echo "=== 同步完成 ==="
echo ""
echo "文件统计:"
echo "  qlat/*.cpp:       $(ls -1 "$QLAT_CMAKE_DIR/qlat/"*.cpp 2>/dev/null | wc -l | tr -d ' ') 个"
echo "  qutils/*.cpp:     $(ls -1 "$QLAT_CMAKE_DIR/qutils/"*.cpp 2>/dev/null | wc -l | tr -d ' ') 个"
echo "  qlat-grid/*.cpp:  $(ls -1 "$QLAT_CMAKE_DIR/qlat-grid/"*.cpp 2>/dev/null | wc -l | tr -d ' ') 个"
echo "  include/qlat/*.h:     $(ls -1 "$QLAT_CMAKE_DIR/include/qlat/"*.h 2>/dev/null | wc -l | tr -d ' ') 个"
echo "  include/qlat-utils/*.h: $(ls -1 "$QLAT_CMAKE_DIR/include/qlat-utils/"*.h 2>/dev/null | wc -l | tr -d ' ') 个"
echo "  include/qlat-grid/*.h: $(ls -1 "$QLAT_CMAKE_DIR/include/qlat-grid/"*.h 2>/dev/null | wc -l | tr -d ' ') 个"
