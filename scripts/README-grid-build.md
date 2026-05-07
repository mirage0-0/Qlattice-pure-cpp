# Grid 构建脚本说明

## 脚本对比

| 脚本 | 适用平台 | 架构优化 | 说明 |
|------|----------|----------|------|
| `build-grid-sve.sh` | Linux/HPC (ARM) | ARM SVE 256-bit | 超算/服务器使用 |
| `build-grid-mac.sh` | macOS (Apple Silicon) | Apple M1/M2/M3/M4 | MacBook/iMac 使用 |

## 使用方式

### 超算/服务器 (Linux ARM)
```bash
prefix=/opt/qlat-deps ./scripts/build-grid-sve.sh
```

### Mac (Apple Silicon)
```bash
prefix=/opt/qlat-deps ./scripts/build-grid-mac.sh
```

## 关键区别

### 1. SIMD 指令集
- **SVE 版本**: 使用 `-march=armv8-a+sve -msve-vector-bits=256`
- **Mac 版本**: 使用 `-march=native` (自动适配 M1/M2/M3/M4)

### 2. Grid 配置选项
- **SVE 版本**: `--enable-simd=ARM_SVE`
- **Mac 版本**: `--enable-simd=GEN` (通用版本)

### 3. 依赖库
两者都支持：
- FFTW3
- LIME
- HDF5
- GMP
- MPFR

## 故障排除

### 错误: `tee: : No such file or directory`
**原因**: LOG_FILE 变量未定义
**解决**: 确保使用最新版本的脚本（已修复）

### 错误: ` unrecognized command line option '-msve-vector-bits=256'`
**原因**: 在 Mac 上使用了 SVE 脚本
**解决**: Mac 用户使用 `build-grid-mac.sh` 而不是 `build-grid-sve.sh`

### 错误: `undefined symbol: ___sv*`
**原因**: 编译时使用了 SVE 指令但运行时 CPU 不支持
**解决**: 确保使用与目标 CPU 匹配的脚本
