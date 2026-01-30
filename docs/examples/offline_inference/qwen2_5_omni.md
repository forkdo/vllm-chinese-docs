# Qwen2.5-Omni 离线推理示例

源代码 <https://github.com/vllm-project/vllm/tree/main/examples/offline_inference/qwen2_5_omni>。

此文件夹提供了多个关于如何离线推理 Qwen2.5-Omni 的示例脚本。

## 仅使用 Thinker

```bash
# 音频 + 图像 + 视频
python examples/offline_inference/qwen2_5_omni/only_thinker.py \
    -q mixed_modalities

# 从单个视频文件中读取视觉和音频输入
python examples/offline_inference/qwen2_5_omni/only_thinker.py \
    -q use_audio_in_video

# 多个音频
python examples/offline_inference/qwen2_5_omni/only_thinker.py \
    -q multi_audios
```

此脚本将运行 Qwen2.5-Omni 的 thinker 部分，并生成文本响应。

您也可以测试 Qwen2.5-Omni 在单个模态上的表现：

```bash
# 处理音频输入
python examples/offline_inference/audio_language.py \
    --model-type qwen2_5_omni

# 处理图像输入
python examples/offline_inference/vision_language.py \
    --modality image \
    --model-type qwen2_5_omni

# 处理视频输入
python examples/offline_inference/vision_language.py \
    --modality video \
    --model-type qwen2_5_omni
```

## 示例材料

??? abstract "only_thinker.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/qwen2_5_omni/only_thinker.py"
    ``````