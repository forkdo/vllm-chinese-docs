# 增量编译工作流

在开发位于 `csrc/` 目录下的 vLLM C++/CUDA 内核时，每次修改都使用 `uv pip install -e .` 重新编译整个项目会非常耗时。通过使用 CMake 的增量编译工作流，可以在初始设置后仅重新编译必要的组件，从而实现更快的迭代开发。本指南将详细介绍如何设置和使用这种工作流，以配合您的可编辑 Python 安装。

## 先决条件

在设置增量编译之前：

1. **vLLM 可编辑安装：** 确保您已通过源码以可编辑模式安装了 vLLM。在初始可编辑安装阶段使用预编译的 wheel 包可以加快速度，因为 CMake 工作流将负责后续的内核重新编译。

    ```console
    uv venv --python 3.12 --seed
    source .venv/bin/activate
    VLLM_USE_PRECOMPILED=1 uv pip install -U -e . --torch-backend=auto
    ```

2. **CUDA 工具包：** 验证 NVIDIA CUDA 工具包已正确安装，并且 `nvcc` 可访问（即在您的 `PATH` 中）。CMake 依赖 `nvcc` 来编译 CUDA 代码。通常可以在 `$CUDA_HOME/bin/nvcc` 或通过运行 `which nvcc` 找到 `nvcc`。如果遇到问题，请参考 [官方 CUDA 工具包安装指南](https://developer.nvidia.com/cuda-toolkit-archive) 以及 vLLM 的主要 [GPU 安装文档](../getting_started/installation/gpu.md#troubleshooting) 进行故障排查。您的 `CMakeUserPresets.json` 中的 `CMAKE_CUDA_COMPILER` 变量也应指向您的 `nvcc` 二进制文件。

3. **构建工具：** 强烈建议安装 `ccache` 以通过缓存编译结果实现快速重新构建（例如 `sudo apt install ccache` 或 `conda install ccache`）。同时确保核心构建依赖项（如 `cmake` 和 `ninja`）已安装。这些可以通过 `requirements/build.txt` 或您的系统软件包管理器安装。

    ```console
    uv pip install -r requirements/build.txt --torch-backend=auto
    ```

## 设置 CMake 构建环境

增量编译过程通过 CMake 管理。您可以在 vLLM 仓库根目录下使用 `CMakeUserPresets.json` 文件来配置构建设置。

### 使用辅助脚本生成 `CMakeUserPresets.json`

为简化设置，vLLM 提供了一个辅助脚本，尝试自动检测您的系统配置（如 CUDA 路径、Python 环境和 CPU 核心数），并为您生成 `CMakeUserPresets.json` 文件。

**运行脚本：**

导航到您的 vLLM 克隆仓库根目录并执行以下命令：

```console
python tools/generate_cmake_presets.py
```

如果脚本无法自动确定某些路径（例如 `nvcc` 或用于 vLLM 开发环境的特定 Python 可执行文件），脚本会提示您。请按照屏幕上的提示操作。如果找到现有的 `CMakeUserPresets.json`，脚本会在覆盖前请求确认。

**强制覆盖现有文件：**

要在不提示的情况下自动覆盖现有的 `CMakeUserPresets.json`，请使用 `--force-overwrite` 标志：

```console
python tools/generate_cmake_presets.py --force-overwrite
```

这在自动化脚本或 CI/CD 环境中特别有用，因为这类环境不希望有交互式提示。

运行脚本后，将在您的 vLLM 仓库根目录下创建一个 `CMakeUserPresets.json` 文件。

### `CMakeUserPresets.json` 示例

以下是生成的 `CMakeUserPresets.json` 可能的样子。脚本将根据您的系统和您提供的任何输入来定制这些值。

```json
{
    "version": 6,
    "cmakeMinimumRequired": {
        "major": 3,
        "minor": 26,
        "patch": 1
    },
    "configurePresets": [
        {
            "name": "release",
            "generator": "Ninja",
            "binaryDir": "${sourceDir}/cmake-build-release",
            "cacheVariables": {
                "CMAKE_CUDA_COMPILER": "/usr/local/cuda/bin/nvcc",
                "CMAKE_C_COMPILER_LAUNCHER": "ccache",
                "CMAKE_CXX_COMPILER_LAUNCHER": "ccache",
                "CMAKE_CUDA_COMPILER_LAUNCHER": "ccache",
                "CMAKE_BUILD_TYPE": "Release",
                "VLLM_PYTHON_EXECUTABLE": "/home/user/venvs/vllm/bin/python",
                "CMAKE_INSTALL_PREFIX": "${sourceDir}",
                "CMAKE_CUDA_FLAGS": "",
                "NVCC_THREADS": "4",
                "CMAKE_JOB_POOLS": "compile=32"
            }
        }
    ],
    "buildPresets": [
        {
            "name": "release",
            "configurePreset": "release",
            "jobs": 32
        }
    ]
}
```

**各种配置的含义是什么？**

- `CMAKE_CUDA_COMPILER`：指向您的 `nvcc` 二进制文件的路径。脚本尝试自动找到它。
- `CMAKE_C_COMPILER_LAUNCHER`、`CMAKE_CXX_COMPILER_LAUNCHER`、`CMAKE_CUDA_COMPILER_LAUNCHER`：将这些设置为 `ccache`（或 `sccache`）可以通过缓存编译结果显著加快重新构建速度。确保已安装 `ccache`（例如 `sudo apt install ccache` 或 `conda install ccache`）。脚本默认设置这些。
- `VLLM_PYTHON_EXECUTABLE`：指向您的 vLLM 开发环境中 Python 可执行文件的路径。脚本会为此提示，如果合适，默认为当前的 Python 环境。
- `CMAKE_INSTALL_PREFIX: "${sourceDir}"`：指定编译后的组件应安装回您的 vLLM 源码目录。这对于可编辑安装至关重要，因为它使新构建的内核立即可用于您的 Python 环境。
- `CMAKE_JOB_POOLS` 和构建预设中的 `jobs`：控制构建的并行度。脚本会根据检测到的系统 CPU 核心数设置这些。
- `binaryDir`：指定构建产物将存储的位置（例如 `cmake-build-release`）。

## 使用 CMake 构建和安装

一旦您的 `CMakeUserPresets.json` 配置完成：

1. **初始化 CMake 构建环境：**
   此步骤根据您选择的预设（例如 `release`）配置构建系统，并在 `binaryDir` 创建构建目录

    ```console
    cmake --preset release
    ```

2. **构建并安装 vLLM 组件：**
   此命令编译代码并将生成的二进制文件安装到您的 vLLM 源码目录中，使它们可用于您的可编辑 Python 安装。

    ```console
    cmake --build --preset release --target install
    ```

3. **进行修改并重复！**
    现在您可以开始使用 vLLM 的可编辑安装，根据需要测试和进行修改。如果需要再次构建以根据更改进行更新，只需再次运行 CMake 命令来构建受影响的文件。

    ```console
    cmake --build --preset release --target install
    ```

## 验证构建

成功构建后，您将找到一个已填充的构建目录（例如，如果您使用了 `release` 预设和示例配置，则为 `cmake-build-release/`）。

```console
> ls cmake-build-release/
bin             cmake_install.cmake      _deps                                machete_generation.log
build.ninja     CPackConfig.cmake        detect_cuda_compute_capabilities.cu  marlin_generation.log
_C.abi3.so      CPackSourceConfig.cmake  detect_cuda_version.cc               _moe_C.abi3.so
CMakeCache.txt  ctest                    _flashmla_C.abi3.so                  moe_marlin_generation.log
CMakeFiles      cumem_allocator.abi3.so  install_local_manifest.txt           vllm-flash-attn
```

`cmake --build ... --target install` 命令将编译好的共享库（如 `_C.abi3.so`、`_moe_C.abi3.so` 等）复制到您的源码树中相应的 `vllm` 包目录。这会用新编译的内核更新您的可编辑安装。

## 额外提示

- **调整并行度：** 微调 `CMakeUserPresets.json` 文件中 `configurePresets` 的 `CMAKE_JOB_POOLS` 和 `buildPresets` 的 `jobs` 参数。过多的任务可能会使内存或 CPU 核心数有限的系统过载，导致构建速度变慢或系统不稳定。而过少的任务则无法充分利用可用资源。
- **必要时执行清理构建：** 如果遇到持续或奇怪的构建错误，尤其是在进行重大更改或切换分支后，建议删除 CMake 构建目录（例如 `rm -rf cmake-build-release`），然后重新运行 `cmake --preset` 和 `cmake --build` 命令。
- **特定目标构建：** 在开发特定模块时，为了获得更快的迭代速度，有时可以构建特定目标而非完整的 `install` 目标，尽管 `install` 能确保 Python 环境中所有必要组件都得到更新。有关更高级的目标管理方法，请参阅 CMake 文档。