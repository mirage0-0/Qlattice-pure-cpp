#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# PROJECT_ROOT 应该是 scripts 的上级目录 (qlat_cmake_0.90)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "PROJECT_ROOT: $PROJECT_ROOT"
LOG_DIR="$PROJECT_ROOT/build-logs"

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/qlat-build.log"

echo "=== 构建 qlat (CMake) ===" | tee "$LOG_FILE"
echo "日志文件: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

cd "$PROJECT_ROOT"

# 确保在正确的目录运行 cmake
echo "当前目录: $(pwd)" | tee -a "$LOG_FILE"
ls -la CMakeLists.txt 2>&1 | tee -a "$LOG_FILE" || (echo "错误: CMakeLists.txt 不存在" | tee -a "$LOG_FILE" && exit 1)

mkdir -p build
echo ">>> 运行 CMake" | tee -a "$LOG_FILE"
cd build
cmake .. 2>&1 | tee -a "$LOG_FILE"

echo ">>> 编译" | tee -a "$LOG_FILE"
make -j 4 2>&1 | tee -a "$LOG_FILE"

echo ">>> 安装" | tee -a "$LOG_FILE"
make install 2>&1 | tee -a "$LOG_FILE"

cd "$PROJECT_ROOT"

#echo ">>> 清理 build 目录" | tee -a "$LOG_FILE"
#rm -rf build
#echo "已删除 build 目录" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=== qlat 构建完成 ===" | tee -a "$LOG_FILE"
echo "日志文件: $LOG_FILE" | tee -a "$LOG_FILE"
