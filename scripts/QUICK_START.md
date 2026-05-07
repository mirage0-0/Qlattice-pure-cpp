# 🚀 快速开始指南

## 1. 选择正确的脚本

| 你的环境 | 构建依赖 | 构建 Grid |
|---------|---------|----------|
| **Mac M1/M2/M3/M4** | `build-deps.sh` | `build-grid-mac.sh` ✅ |
| **Mac Intel** | `build-deps.sh` | `build-grid-mac.sh` ✅ |
| **Linux/HPC ARM** | `build-deps.sh` | `build-grid-sve.sh` |

## 2. 一键构建 (Mac M4 示例)

```bash
cd /Users/wzy/Documents/package/Qlattice-master/qlat_cmake_0.90

# 设置安装路径
export prefix=/opt/qlat-deps

# 1. 构建依赖 (zlib, fftw, gmp, mpfr, cuba, lime)
./scripts/build-deps.sh

# 2. 构建 Grid (针对 Apple Silicon 优化)
./scripts/build-grid-mac.sh
```

## 3. 常见问题

### ❌ 错误: `tee: : No such file or directory`
**解决**: 已修复，请使用最新版本的脚本

### ❌ 错误: `unrecognized command line option '-msve-vector-bits=256'`
**原因**: 在 Mac 上使用了 HPC 脚本
**解决**: Mac 用户使用 `build-grid-mac.sh` (使用 `-march=native`)

### ❌ 错误: `Grid-clehner 未找到`
**解决**: 确保 `distfiles/Grid-clehner` 或 `distfiles/Grid-clehner.tar.gz` 存在

## 4. 检查构建结果

```bash
# 检查 Grid 是否安装成功
ls -la /opt/qlat-deps/Grid-clehner/lib/libGrid.*

# 查看构建日志
cat /Users/wzy/Documents/package/Qlattice-master/qlat_cmake_0.90/build-logs/grid-build-mac.log
```

## 5. 下一步

构建完成后，继续构建 qlat 主项目：

```bash
cd /Users/wzy/Documents/package/Qlattice-master/qlat_cmake_0.90
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/qlat-deps
make -j4
make install
```

---

**现在你已经准备好开始构建了！** 🎉

选择你的平台：
- 🍎 **Mac**: 使用 `build-grid-mac.sh`
- 🖥️ **HPC**: 使用 `build-grid-sve.sh`
