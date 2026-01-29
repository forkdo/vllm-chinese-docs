# 安装

vLLM 支持以下硬件平台：

- [GPU](gpu.md)
    - [NVIDIA CUDA](gpu.md#nvidia-cuda)
    - [AMD ROCm](gpu.md#amd-rocm)
    - [Intel XPU](gpu.md#intel-xpu)
- [CPU](cpu.md)
    - [Intel/AMD x86](cpu.md#intelamd-x86)
    - [ARM AArch64](cpu.md#arm-aarch64)
    - [Apple silicon](cpu.md#apple-silicon)
    - [IBM Z (S390X)](cpu.md#ibm-z-s390x)

## 硬件插件

vLLM 支持第三方硬件插件，这些插件**独立于**主 `vllm` 代码库。它们遵循[硬件可插拔 RFC](../../design/plugin_system.md)。

所有支持的硬件列表可在 [vllm.ai 网站](https://vllm.ai/#hardware) 上找到。如果您想添加新的硬件支持，请通过 [Slack](https://slack.vllm.ai/) 或 [电子邮件](mailto:collaboration@vllm.ai) 联系我们。