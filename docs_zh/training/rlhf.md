# 人类反馈强化学习

人类反馈强化学习（RLHF）是一种使用人类生成的偏好数据对语言模型进行微调的技术，以使模型输出与期望行为对齐。vLLM 可用于生成 RLHF 的完成文本。

以下开源强化学习库使用 vLLM 进行快速推演（按字母顺序排列，非穷尽列表）：

- [Cosmos-RL](https://github.com/nvidia-cosmos/cosmos-rl)
- [ms-swift](https://github.com/modelscope/ms-swift/tree/main)
- [NeMo-RL](https://github.com/NVIDIA-NeMo/RL)
- [Open Instruct](https://github.com/allenai/open-instruct)
- [OpenRLHF](https://github.com/OpenRLHF/OpenRLHF)
- [PipelineRL](https://github.com/ServiceNow/PipelineRL)
- [Prime-RL](https://github.com/PrimeIntellect-ai/prime-rl)
- [SkyRL](https://github.com/NovaSky-AI/SkyRL)
- [TRL](https://github.com/huggingface/trl)
- [Unsloth](https://github.com/unslothai/unsloth)
- [verl](https://github.com/volcengine/verl)

如果您不想使用现有库，可以通过以下基础示例开始使用：

- [训练和推理过程位于独立 GPU 上（受 OpenRLHF 启发）](../examples/offline_inference/rlhf.md)
- [使用 Ray 在同一 GPU 上共置训练和推理过程](../examples/offline_inference/rlhf_colocate.md)
- [使用 vLLM 执行 RLHF 的工具](../examples/offline_inference/rlhf_utils.md)

查看以下笔记本，了解如何使用 vLLM 进行 GRPO：

- [在 TRL 中使用 GRPO 和 vLLM 进行高效的在线训练](https://huggingface.co/learn/cookbook/grpo_vllm_online_training)
- [使用 Unsloth + vLLM 进行 Qwen-3 4B GRPO](https://colab.research.google.com/github/unslothai/notebooks/blob/main/nb/Qwen3_(4B)-GRPO.ipynb)