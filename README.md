# qlat_cmake_0.90

CMake 构建版本，适用于离线超算环境。完全绕过 meson，实现一键构建。

## 目录结构

```
qlat_cmake_0.90/
├── CMakeLists.txt           # CMake 构建配置
├── scripts/                 # 构建脚本
│   ├── build-all.sh        # 完整构建流程（依赖+qlat）
│   ├── build-deps.sh      # 构建依赖库
│   ├── build.sh           # 单独构建 qlat
│   ├── copy_src.sh        # 复制源文件
│   ├── prepare_deps.sh   # 准备依赖库
│   ├── build-grid-*.sh   # Grid 构建脚本
├── distfiles/             # 依赖库源文件
├── include/               # 头文件
├── qlat/                 # qlat 源码
├── qutils/               # qutils 源码
├── qlat-grid/            # qlat-grid 源码
├── examples/              # 示例项目
│   └── example-qlat-grid/ # qlat+Grid 集成示例
└── install/              # 安装目录（构建后生成）
```

## 依赖

构建过程中会自动安装以下依赖库：

- **zlib** - 压缩库
- **FFTW3** - `libfftw3`, `libfftw3f`
- **Eigen3** - 头文件库
- **HDF5** - 支持 C++ 接口（用于 Grid I/O）
- **GMP** - 高精度计算
- **MPFR** - 高精度计算

可选依赖：
- **Cuba** - 数值积分库
- **C-LIME** - I/O 库

## 快速开始

### 1. 完整构建

```bash
cd qlat_cmake_0.90

# 设置安装路径（必须）
export prefix=/your/install/path

# 运行完整构建
./scripts/build-all.sh
```

### 2. 超算环境

```bash
# 将项目复制到超算后
cd qlat_cmake_0.90

# 设置安装路径
export prefix=/thfs1/home/user/qlat-0.90-cpp

# 构建（会自动检测 CPU 类型并选择合适的配置）
./scripts/build-all.sh
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `prefix` | qlat 及依赖库的安装路径（必须设置） |
| `NUM_PROC` | 并行构建线程数 |

**版本管理策略**：使用不同的安装路径来管理多个 qlat 版本，避免覆盖旧版本。

## 包含的库

- **qlat** - 主库
- **qutils** - 工具库
- **qlat-grid** - Grid 接口库

## 示例项目

### example-qlat-grid

qlat+Grid 集成示例，展示如何使用 qlat-grid 库。

#### 构建

```bash
cd qlat_cmake_0.90/examples/example-qlat-grid

# 设置 qlat 安装路径（必须）
export prefix=/path/to/qlat

# 使用一键构建脚本
./build-test.sh
```

#### 运行

```bash
./build/test
```

#### 项目结构

```
example-qlat-grid/
├── CMakeLists.txt       # 构建配置
├── build-test.sh        # 一键构建脚本
├── src/                 # 库源码
│   └── example_utils.cpp
└── app/                 # 可执行文件
    └── test.cpp
```

## 构建脚本说明

| 脚本 | 说明 |
|------|------|
| `build-all.sh` | 完整流程：依赖 → qlat → 安装 |
| `build-deps.sh` | 仅构建依赖库 |
| `build.sh` | 仅构建 qlat |
| `copy_src.sh` | 复制源文件到构建目录 |
| `prepare_deps.sh` | 准备依赖库源码 |

## Grid 构建脚本

- `build-grid-mac.sh` - macOS 构建
- `build-grid-sve.sh` - Linux HPC (支持 SVE 指令)
- `build-grid-neonv8.sh` - Linux HPC (ARM NEONv8)
