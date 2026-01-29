# --8<-- [start:installation]

vLLM 对搭载 Apple Silicon 的 macOS 提供实验性支持。目前，用户必须从源码构建才能在 macOS 上原生运行。

当前 macOS 的 CPU 实现支持 FP32 和 FP16 数据类型。

!!! tip "使用 vLLM-Metal 进行 GPU 加速推理"
    要在 Apple Silicon 上使用 Metal 进行 GPU 加速推理，请查看 [vllm-metal](https://github.com/vllm-project/vllm-metal)，这是一个由社区维护的硬件插件，使用 MLX 作为计算后端。

# --8<-- [end:installation]
# --8<-- [start:requirements]

- 操作系统：`macOS Sonoma` 或更高版本
- SDK：`XCode 15.4` 或更高版本，包含命令行工具
- 编译器：`Apple Clang >= 15.0.0`

# --8<-- [end:requirements]
# --8<-- [start:set-up-using-python]

# --8<-- [end:set-up-using-python]
# --8<-- [start:pre-built-wheels]

目前暂无适用于 Apple Silicon CPU 的预构建 wheel 文件。

# --8<-- [end:pre-built-wheels]
# --8<-- [start:build-wheel-from-source]

安装 XCode 和命令行工具（包含 Apple Clang）后，执行以下命令从源码构建并安装 vLLM。

```bash
git clone https://github.com/vllm-project/vllm.git
cd vllm
uv pip install -r requirements/cpu.txt --index-strategy unsafe-best-match
uv pip install -e .
```

!!! tip
    `--index-strategy unsafe-best-match` 标志用于跨多个包索引解析依赖关系（PyTorch CPU 索引和 PyPI）。缺少此标志时，您可能会遇到 `typing-extensions` 版本冲突问题。
    
    此处的“unsafe”指的是包解析策略，而非安全性。默认情况下，`uv` 只搜索找到包的第一个索引，以防止依赖混淆攻击。此标志允许 `uv` 搜索所有配置的索引以找到最佳兼容版本。由于 PyTorch 和 PyPI 都是受信任的包源，使用此策略在 vLLM 安装中是安全且合适的。

!!! note
    在 macOS 上，`VLLM_TARGET_DEVICE` 会自动设置为 `cpu`，这目前是唯一支持的设备。

!!! example "故障排除"
    如果构建失败并显示如下错误，提示找不到标准 C++ 头文件，请尝试卸载并重新安装您的
    [Xcode 命令行工具](https://developer.apple.com/download/all/)。

    ```text
    [...] fatal error: 'map' file not found
            1 | #include <map>
                |          ^~~~~
        1 error generated.
        [2/8] Building CXX object CMakeFiles/_C.dir/csrc/cpu/pos_encoding.cpp.o

    [...] fatal error: 'cstddef' file not found
            10 | #include <cstddef>
                |          ^~~~~~~~~
        1 error generated.
    ```

    ---

    如果构建失败并显示如下 C++11/C++17 兼容性错误，则问题是构建系统默认使用了较旧的 C++ 标准：

    ```text
    [...] error: 'constexpr' is not a type
    [...] error: expected ';' before 'constexpr'
    [...] error: 'constexpr' does not name a type
    ```

    **解决方案**：您的编译器可能使用的是较旧的 C++ 标准。编辑 `cmake/cpu_extension.cmake`，在 `set(CMAKE_CXX_STANDARD_REQUIRED ON)` 前添加 `set(CMAKE_CXX_STANDARD 17)`。

    要检查您的编译器 C++ 标准支持情况：
    ```bash
    clang++ -std=c++17 -pedantic -dM -E -x c++ /dev/null | grep __cplusplus
    ```
    在 Apple Clang 16 上，您应该看到：`#define __cplusplus 201703L`

# --8<-- [end:build-wheel-from-source]
# --8<-- [start:pre-built-images]

目前暂无适用于 Arm Silicon CPU 的预构建镜像。

# --8<-- [end:pre-built-images]
# --8<-- [start:build-image-from-source]

# --8<-- [end:build-image-from-source]
# --8<-- [start:extra-information]
# --8<-- [end:extra-information]