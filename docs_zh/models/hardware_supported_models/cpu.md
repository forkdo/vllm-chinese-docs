# CPU - Intel® Xeon®

## 已验证硬件

| 硬件                                 |
| ----------------------------------------- |
| [Intel® Xeon® 6 处理器](https://www.intel.com/content/www/us/en/products/details/processors/xeon.html)                   |
| [Intel® Xeon® 5 处理器](https://www.intel.com/content/www/us/en/products/docs/processors/xeon/5th-gen-xeon-scalable-processors.html)              |

## 推荐模型

### 纯文本语言模型

| 模型                                | 架构                             | 是否支持 |
|--------------------------------------|-------------------------------------------|-----------|
| meta-llama/Llama-3.1-8B-Instruct     | LlamaForCausalLM                          | ✅        |
| meta-llama/Llama-3.2-3B-Instruct     | LlamaForCausalLM                          | ✅        |
| ibm-granite/granite-3.2-2b-instruct  | GraniteForCausalLM                        | ✅        |
| Qwen/Qwen3-1.7B                      | Qwen3ForCausalLM                          | ✅        |
| Qwen/Qwen3-4B                        | Qwen3ForCausalLM                          | ✅        |
| Qwen/Qwen3-8B                        | Qwen3ForCausalLM                          | ✅        |
| zai-org/glm-4-9b-hf                  | GLMForCausalLM                            | ✅        |
| google/gemma-7b                      | GemmaForCausalLM                          | ✅        |

### 多模态语言模型

| 模型                                | 架构                             | 是否支持 |
|--------------------------------------|-------------------------------------------|-----------|
| Qwen/Qwen2.5-VL-7B-Instruct          | Qwen2VLForConditionalGeneration           | ✅        |
| openai/whisper-large-v3              | WhisperForConditionalGeneration           | ✅        |

✅ 已运行并优化。  
🟨 已运行且结果正确，但尚未优化至绿色状态。  
❌ 未通过准确性测试或无法运行。