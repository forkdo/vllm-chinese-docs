使用 fastsafetensors 加载模型权重
===================================================================

使用 fastsafetensors 库可以通过 GPU 直连存储技术将模型权重加载到 GPU 内存中。详见其 [GitHub 仓库](https://github.com/foundation-model-stack/fastsafetensors) 了解更多信息。

要启用此功能，请使用 `--load-format fastsafetensors` 命令行参数