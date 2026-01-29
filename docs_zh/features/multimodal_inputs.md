# 多模态输入

本页面将教你如何在 vLLM 中向 [多模态模型](../models/supported_models.md#list-of-multimodal-language-models) 传递多模态输入。

!!! note
    我们正在积极迭代多模态支持功能。有关即将进行的更改，请参见 [此 RFC](https://github.com/vllm-project/vllm/issues/4194)，
    如果有任何反馈或功能请求，请在 [GitHub 上提交问题](https://github.com/vllm-project/vllm/issues/new/choose)。

!!! tip
    在提供多模态模型服务时，建议设置 `--allowed-media-domains` 以限制 vLLM 可访问的域，防止其访问可能容易受到服务器端请求伪造（SSRF）攻击的任意端点。你可以为此参数提供一个域列表。例如：`--allowed-media-domains upload.wikimedia.org github.com www.bogotobogo.com`

    此外，建议设置 `VLLM_MEDIA_URL_ALLOW_REDIRECTS=0` 以防止跟随 HTTP 重定向来绕过域限制。

    如果你在容器化环境中运行 vLLM，其中 vLLM Pod 可能对内部网络具有无限制访问权限，此限制尤为重要。

## 离线推理

要输入多模态数据，请在 [vllm.inputs.PromptType][] 中遵循以下架构：

- `prompt`: 提示应遵循 HuggingFace 上文档化的格式。
- `multi_modal_data`: 这是一个字典，遵循在 [vllm.multimodal.inputs.MultiModalDataDict][] 中定义的架构。

### 图像输入

你可以将单个图像传递到多模态字典的 `'image'` 字段，如下例所示：

??? code

    ```python
    from vllm import LLM

    llm = LLM(model="llava-hf/llava-1.5-7b-hf")

    # 请参阅 HuggingFace 仓库以获取正确的格式
    prompt = "USER: <image>\nWhat is the content of this image?\nASSISTANT:"

    # 使用 PIL.Image 加载图像
    image = PIL.Image.open(...)

    # 单提示推理
    outputs = llm.generate({
        "prompt": prompt,
        "multi_modal_data": {"image": image},
    })

    for o in outputs:
        generated_text = o.outputs[0].text
        print(generated_text)

    # 批量推理
    image_1 = PIL.Image.open(...)
    image_2 = PIL.Image.open(...)
    outputs = llm.generate(
        [
            {
                "prompt": "USER: <image>\nWhat is the content of this image?\nASSISTANT:",
                "multi_modal_data": {"image": image_1},
            },
            {
                "prompt": "USER: <image>\nWhat's the color of this image?\nASSISTANT:",
                "multi_modal_data": {"image": image_2},
            }
        ]
    )

    for o in outputs:
        generated_text = o.outputs[0].text
        print(generated_text)
    ```

完整示例：[examples/offline_inference/vision_language.py](../../examples/offline_inference/vision_language.py)

要在同一文本提示中替换多个图像，你可以传入图像列表：

??? code

    ```python
    from vllm import LLM

    llm = LLM(
        model="microsoft/Phi-3.5-vision-instruct",
        trust_remote_code=True,  # 加载 Phi-3.5-vision 所需
        max_model_len=4096,  # 否则可能无法在较小的 GPU 上运行
        limit_mm_per_prompt={"image": 2},  # 最大接受数量
    )

    # 请参阅 HuggingFace 仓库以获取正确的格式
    prompt = "<|user|>\n<|image_1|>\n<|image_2|>\nWhat is the content of each image?<|end|>\n<|assistant|>\n"

    # 使用 PIL.Image 加载图像
    image1 = PIL.Image.open(...)
    image2 = PIL.Image.open(...)

    outputs = llm.generate({
        "prompt": prompt,
        "multi_modal_data": {"image": [image1, image2]},
    })

    for o in outputs:
        generated_text = o.outputs[0].text
        print(generated_text)
    ```

完整示例：[examples/offline_inference/vision_language_multi_image.py](../../examples/offline_inference/vision_language_multi_image.py)

如果使用 [LLM.chat](../models/generative_models.md#llmchat) 方法，你可以使用多种格式在消息内容中直接传递图像：图像 URL、PIL Image 对象或预计算的嵌入：

??? code

    ```python
    from vllm import LLM
    from vllm.assets.image import ImageAsset

    llm = LLM(model="llava-hf/llava-1.5-7b-hf")
    image_url = "https://picsum.photos/id/32/512/512"
    image_pil = ImageAsset('cherry_blossom').pil_image
    image_embeds = torch.load(...)

    conversation = [
        {"role": "system", "content": "You are a helpful assistant"},
        {"role": "user", "content": "Hello"},
        {"role": "assistant", "content": "Hello! How can I assist you today?"},
        {
            "role": "user",
            "content": [
                {
                    "type": "image_url",
                    "image_url": {"url": image_url},
                },
                {
                    "type": "image_pil",
                    "image_pil": image_pil,
                },
                {
                    "type": "image_embeds",
                    "image_embeds": image_embeds,
                },
                {
                    "type": "text",
                    "text": "What's in these images?",
                },
            ],
        },
    ]

    # 执行推理并记录输出。
    outputs = llm.chat(conversation)

    for o in outputs:
        generated_text = o.outputs[0].text
        print(generated_text)
    ```

多图像输入可以扩展到执行视频字幕。我们使用 [Qwen2-VL](https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct) 展示这一点，因为它支持视频：

??? code

    ```python
    from vllm import LLM

    # 指定每段视频的最大帧数为 4。可以根据需要更改。
    llm = LLM("Qwen/Qwen2-VL-2B-Instruct", limit_mm_per_prompt={"image": 4})

    # 创建请求负载。
    video_frames = ... # 加载你的视频，确保其帧数与前面指定的相同。
    message = {
        "role": "user",
        "content": [
            {
                "type": "text",
                "text": "Describe this set of frames. Consider the frames to be a part of the same video.",
            },
        ],
    }
    for i in range(len(video_frames)):
        base64_image = encode_image(video_frames[i]) # base64 编码。
        new_image = {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}}
        message["content"].append(new_image)

    # 执行推理并记录输出。
    outputs = llm.chat([message])

    for o in outputs:
        generated_text = o.outputs[0].text
        print(generated_text)
    ```

#### 自定义 RGBA 背景色

加载 RGBA 图像（带透明度的图像）时，vLLM 会将其转换为 RGB 格式。默认情况下，透明像素会被替换为白色背景。你可以使用 `media_io_kwargs` 中的 `rgba_background_color` 参数自定义此背景色。

??? code

    ```python
    from vllm import LLM

    # 默认白色背景（无需配置）
    llm = LLM(model="llava-hf/llava-1.5-7b-hf")

    # 自定义黑色背景用于暗色主题
    llm = LLM(
        model="llava-hf/llava-1.5-7b-hf",
        media_io_kwargs={"image": {"rgba_background_color": [0, 0, 0]}},
    )

    # 自定义品牌颜色背景（例如蓝色）
    llm = LLM(
        model="llava-hf/llava-1.5-7b-hf",
        media_io_kwargs={"image": {"rgba_background_color": [0, 0, 255]}},
    )
    ```

!!! note
    - `rgba_background_color` 接受 RGB 值作为列表 `[R, G, B]` 或元组 `(R, G, B)`，其中每个值为 0-255
    - 此设置仅影响带透明度的 RGBA 图像；RGB 图像保持不变
    - 如果未指定，则默认使用白色背景 `(255, 255, 255)` 以保持向后兼容性

### 视频输入

你可以将 NumPy 数组列表直接传递到多模态字典的 `'video'` 字段，
而无需使用多图像输入。

你也可以传递 `'torch.Tensor'` 实例，而不是 NumPy 数组，如下例所示，使用 Qwen2.5-VL：

??? code

```python
from transformers import AutoProcessor
from vllm import LLM, SamplingParams
from qwen_vl_utils import process_vision_info

model_path = "Qwen/Qwen2.5-VL-3B-Instruct"
video_path = "https://content.pexels.com/videos/free-videos.mp4"

llm = LLM(
    model=model_path,
    gpu_memory_utilization=0.8,
    enforce_eager=True,
    limit_mm_per_prompt={"video": 1},
)

sampling_params = SamplingParams(max_tokens=1024)

video_messages = [
    {
        "role": "system",
        "content": "You are a helpful assistant.",
    },
    {
        "role": "user",
        "content": [
            {"type": "text", "text": "describe this video."},
            {
                "type": "video",
                "video": video_path,
                "total_pixels": 20480 * 28 * 28,
                "min_pixels": 16 * 28 * 28,
            },
        ]
    },
]

messages = video_messages
processor = AutoProcessor.from_pretrained(model_path)
prompt = processor.apply_chat_template(
    messages,
    tokenize=False,
    add_generation_prompt=True,
)

image_inputs, video_inputs = process_vision_info(messages)
mm_data = {}
if video_inputs is not None:
    mm_data["video"] = video_inputs

llm_inputs = {
    "prompt": prompt,
    "multi_modal_data": mm_data,
}

outputs = llm.generate([llm_inputs], sampling_params=sampling_params)
for o in outputs:
    generated_text = o.outputs[0].text
    print(generated_text)
```

!!! note
    'process_vision_info' 仅适用于 Qwen2.5-VL 及类似模型。

完整示例：[examples/offline_inference/vision_language.py](../../examples/offline_inference/vision_language.py)

### 音频输入

您可以将元组 `(array, sampling_rate)` 传递给多模态字典的 `'audio'` 字段。

完整示例：[examples/offline_inference/audio_language.py](../../examples/offline_inference/audio_language.py)

#### 自动音频通道标准化

vLLM 会自动对需要特定音频格式的模型进行音频通道标准化。使用 `torchaudio` 等库加载音频时，立体声文件返回形状 `[channels, time]`，但许多音频模型（特别是基于 Whisper 的模型）期望单声道音频，形状为 `[time]`。

**支持自动单声道转换的模型：**

- **Whisper** 及所有基于 Whisper 的模型
- **Qwen2-Audio**
- **Qwen2.5-Omni** / **Qwen3-Omni**（继承自 Qwen2.5-Omni）
- **Ultravox**

对于这些模型，vLLM 会自动：

1. 通过特征提取器检测模型是否需要单声道音频
2. 使用通道平均将多通道音频转换为单声道
3. 处理 `(channels, time)` 格式（torchaudio）和 `(time, channels)` 格式（soundfile）

**立体声音频示例：**

```python
import torchaudio
from vllm import LLM

# 加载立体声音频文件 - 返回 (channels, time) 形状
audio, sr = torchaudio.load("stereo_audio.wav")
print(f"原始形状: {audio.shape}")  # 例如 torch.Size([2, 16000])

# vLLM 会自动为基于 Whisper 的模型转换为单声道
llm = LLM(model="openai/whisper-large-v3")

outputs = llm.generate({
    "prompt": "",
    "multi_modal_data": {"audio": (audio.numpy(), sr)},
})
```

无需手动转换 - vLLM 会根据模型需求自动处理通道标准化。

### 嵌入输入

要将属于某种数据类型（即图像、视频或音频）的预计算嵌入直接输入语言模型，请将形状为 `(..., LM 的 hidden_size)` 的张量传递给多模态字典的相应字段。确切的形状取决于所使用的模型。

您必须通过 `enable_mm_embeds=True` 启用此功能。

!!! warning
    如果传递了错误形状的嵌入，vLLM 引擎可能会崩溃。
    仅对可信用户启用此标志！

#### 图像嵌入

??? code

    ```python
    from vllm import LLM

    # 使用图像嵌入进行推理
    llm = LLM(model="llava-hf/llava-1.5-7b-hf", enable_mm_embeds=True)

    # 请参考 HuggingFace 仓库以获取正确的格式
    prompt = "USER: <image>\nWhat is the content of this image?\nASSISTANT:"

    # 对于大多数模型，`image_embeds` 的形状为: (num_images, image_feature_size, hidden_size)
    image_embeds = torch.load(...)

    outputs = llm.generate({
        "prompt": prompt,
        "multi_modal_data": {"image": image_embeds},
    })

    for o in outputs:
        generated_text = o.outputs[0].text
        print(generated_text)

    # 需要额外字段的模型的额外示例
    llm = LLM(
        "Qwen/Qwen2-VL-2B-Instruct",
        limit_mm_per_prompt={"image": 4},
        enable_mm_embeds=True,
    )
    mm_data = {
        "image": {
            # 形状: (total_feature_size, hidden_size)
            # total_feature_size = sum(image_feature_size for image in images)
            "image_embeds": torch.load(...),
            # 形状: (num_images, 3)
            # image_grid_thw 用于计算位置编码。
            "image_grid_thw": torch.load(...),
        }
    }

    llm = LLM(
        "openbmb/MiniCPM-V-2_6",
        trust_remote_code=True,
        limit_mm_per_prompt={"image": 4},
        enable_mm_embeds=True,
    )
    mm_data = {
        "image": {
            # 形状: (num_images, num_slices, hidden_size)
            # num_slices 对每个图像可能不同
            "image_embeds": [torch.load(...) for image in images],  
            # 形状: (num_images, 2)
            # image_sizes 用于计算切片图像的细节。
            "image_sizes": [image.size for image in images],
        }
    }
    ```

对于 Qwen3-VL，`image_embeds` 应包含基础图像嵌入和 deepstack 特征。

#### 音频嵌入输入

您可以像图像嵌入一样传递预计算的音频嵌入：

??? code

    ```python
    from vllm import LLM
    import torch

    # 启用音频嵌入支持
    llm = LLM(model="fixie-ai/ultravox-v0_5-llama-3_2-1b", enable_mm_embeds=True)

    # 请参考 HuggingFace 仓库以获取正确的格式
    prompt = "USER: <audio>\nWhat is in this audio?\nASSISTANT:"

    # 加载预计算的音频嵌入，通常形状为:
    # (num_audios, audio_feature_size, LM 的 hidden_size)
    audio_embeds = torch.load(...)

    outputs = llm.generate({
        "prompt": prompt,
        "multi_modal_data": {"audio": audio_embeds},
    })

    for o in outputs:
        generated_text = o.outputs[0].text
        print(generated_text)
    ```

### 缓存输入

使用多模态输入时，vLLM 通常按内容对每个媒体项进行哈希，以在请求间启用缓存。您可以选择性地传递 `multi_modal_uuids` 为每个项目提供自己的稳定 ID，这样缓存可以在请求间重用工作而无需重新哈希原始内容。

??? code

    ```python
    from vllm import LLM
    from PIL import Image

    # Qwen2.5-VL 示例，包含两张图像
    llm = LLM(model="Qwen/Qwen2.5-VL-3B-Instruct")

    prompt = "USER: <image><image>\nDescribe the differences.\nASSISTANT:"
    img_a = Image.open("/path/to/a.jpg")
    img_b = Image.open("/path/to/b.jpg")

    outputs = llm.generate({
        "prompt": prompt,
        "multi_modal_data": {"image": [img_a, img_b]},
        # 为缓存提供稳定 ID。
        # 要求（通过此示例匹配）：
        #  - 包含 multi_modal_data 中存在的每种模态。
        #  - 对于列表，提供相同数量的条目。
        #  - 使用 None 回退到对该项的内容哈希。
        "multi_modal_uuids": {"image": ["sku-1234-a", None]},
    })

    for o in outputs:
        print(o.outputs[0].text)
    ```

使用 UUID，您还可以在预期命中相应项目缓存时完全跳过发送媒体数据。请注意，如果跳过的媒体没有对应的 UUID，或者 UUID 未能命中缓存，请求将会失败。

??? code

    ```python
    from vllm import LLM
    from PIL import Image

# 使用两张图像的 Qwen2.5-VL 示例
llm = LLM(model="Qwen/Qwen2.5-VL-3B-Instruct")

prompt = "USER: <image><image>\nDescribe the differences.\nASSISTANT:"
img_b = Image.open("/path/to/b.jpg")

outputs = llm.generate({
    "prompt": prompt,
    "multi_modal_data": {"image": [None, img_b]},
    # 由于 img_a 预期已被缓存，我们可以完全跳过发送实际图像。
    "multi_modal_uuids": {"image": ["sku-1234-a", None]},
})

for o in outputs:
    print(o.outputs[0].text)
```

!!! warning
    如果既禁用了多模态处理器缓存又禁用了前缀缓存，用户提供的 `multi_modal_uuids` 将被忽略。

## 在线服务

我们的 OpenAI 兼容服务器通过 [Chat Completions API](https://platform.openai.com/docs/api-reference/chat) 接受多模态数据。媒体输入也支持用户可提供的可选 UUID，用于唯一标识每个媒体，以便在请求间缓存媒体结果。

!!! important
    使用 Chat Completions API **必须**提供聊天模板。
    对于 HF 格式模型，默认聊天模板定义在 `chat_template.json` 或 `tokenizer_config.json` 中。

    如果没有默认聊天模板，我们将首先在 [vllm/transformers_utils/chat_templates/registry.py](../../vllm/transformers_utils/chat_templates/registry.py) 中查找内置的备用方案。
    如果没有备用方案，将抛出错误，您必须通过 `--chat-template` 参数手动提供聊天模板。

    对于某些模型，我们在 [examples](../../examples) 中提供了替代聊天模板。
    例如，VLM2Vec 使用 [examples/template_vlm2vec_phi3v.jinja](../../examples/template_vlm2vec_phi3v.jinja)，这与 Phi-3-Vision 的默认模板不同。

### 图像输入

图像输入遵循 [OpenAI Vision API](https://platform.openai.com/docs/guides/vision) 标准。
以下是使用 Phi-3.5-Vision 的简单示例。

首先，启动 OpenAI 兼容服务器：

```bash
vllm serve microsoft/Phi-3.5-vision-instruct --runner generate \
  --trust-remote-code --max-model-len 4096 --limit-mm-per-prompt '{"image":2}'
```

然后，您可以按如下方式使用 OpenAI 客户端：

??? code

    ```python
    import os
    from openai import OpenAI

    openai_api_key = "EMPTY"
    openai_api_base = "http://localhost:8000/v1"

    client = OpenAI(
        api_key=openai_api_key,
        base_url=openai_api_base,
    )

    # 单图像输入推理

    # 用于测试远程图像处理的公共图像 URL
    image_url = "https://vllm-public-assets.s3.us-west-2.amazonaws.com/vision_model_images/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg"

    # 使用远程图像创建聊天完成
    chat_response = client.chat.completions.create(
        model="microsoft/Phi-3.5-vision-instruct",
        messages=[
            {
                "role": "user",
                "content": [
                    # 注意：不需要手动使用图像标记 `<image>` 进行提示格式化，
                    # 因为提示将由 API 服务器自动处理。
                    {
                        "type": "text",
                        "text": "What’s in this image?",
                    },
                    {
                        "type": "image_url",
                        "image_url": {"url": image_url},
                        "uuid": image_url,  # 可选
                    },
                ],
            }
        ],
    )
    print("Chat completion output:", chat_response.choices[0].message.content)

    # 本地图像文件路径（请更新为您实际图像文件的路径）
    image_file = "/path/to/image.jpg"

    # 使用本地图像文件创建聊天完成
    # 启动 API 服务器/引擎时使用 --allowed-local-media-path 参数。
    if os.path.exists(image_file):
        chat_completion_from_local_image_url = client.chat.completions.create(
            model="microsoft/Phi-3.5-vision-instruct",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "What’s in this image?",
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": f"file://{image_file}"},
                        },
                    ],
                }
            ],
        )
        result = chat_completion_from_local_image_url.choices[0].message.content
        print("Chat completion output from local image file:\n", result)
    else:
        print(f"Local image file not found at {image_file}, skipping local file test.")

    # 多图像输入推理
    image_url_duck = "https://vllm-public-assets.s3.us-west-2.amazonaws.com/multimodal_asset/duck.jpg"
    image_url_lion = "https://vllm-public-assets.s3.us-west-2.amazonaws.com/multimodal_asset/lion.jpg"

    chat_response = client.chat.completions.create(
        model="microsoft/Phi-3.5-vision-instruct",
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": "What are the animals in these images?",
                    },
                    {
                        "type": "image_url",
                        "image_url": {"url": image_url_duck},
                        "uuid": image_url_duck,  # 可选
                    },
                    {
                        "type": "image_url",
                        "image_url": {"url": image_url_lion},
                        "uuid": image_url_lion,  # 可选
                    },
                ],
            }
        ],
    )
    print("Chat completion output:", chat_response.choices[0].message.content)
    ```

完整示例：[examples/online_serving/openai_chat_completion_client_for_multimodal.py](../../examples/online_serving/openai_chat_completion_client_for_multimodal.py)

!!! tip
    vLLM 也支持从本地文件路径加载：您可以在启动 API 服务器/引擎时通过 `--allowed-local-media-path` 指定允许的本地媒体路径，
    并在 API 请求中将文件路径作为 `url` 传递。

!!! tip
    在 API 请求的文本内容中无需放置图像占位符 - 它们已由图像内容表示。
    实际上，您可以通过交错文本和图像内容在文本中间放置图像占位符。

!!! note
    默认情况下，通过 HTTP URL 获取图像的超时时间为 `5` 秒。
    您可以通过设置环境变量来覆盖此设置：

    ```bash
    export VLLM_IMAGE_FETCH_TIMEOUT=<timeout>
    ```

### 视频输入

除了 `image_url`，您还可以通过 `video_url` 传递视频文件。以下是使用 [LLaVA-OneVision](https://huggingface.co/llava-hf/llava-onevision-qwen2-0.5b-ov-hf) 的简单示例。

首先，启动 OpenAI 兼容服务器：

```bash
vllm serve llava-hf/llava-onevision-qwen2-0.5b-ov-hf --runner generate --max-model-len 8192
```

然后，您可以按如下方式使用 OpenAI 客户端：

??? code

    ```python
    from openai import OpenAI

    openai_api_key = "EMPTY"
    openai_api_base = "http://localhost:8000/v1"

    client = OpenAI(
        api_key=openai_api_key,
        base_url=openai_api_base,
    )

    video_url = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4"

## 在载荷中使用视频 URL
chat_completion_from_url = client.chat.completions.create(
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "What's in this video?",
                },
                {
                    "type": "video_url",
                    "video_url": {"url": video_url},
                    "uuid": video_url,  # 可选
                },
            ],
        }
    ],
    model=model,
    max_completion_tokens=64,
)

result = chat_completion_from_url.choices[0].message.content
print("Chat completion output from image url:", result)
```

完整示例：[examples/online_serving/openai_chat_completion_client_for_multimodal.py](../../examples/online_serving/openai_chat_completion_client_for_multimodal.py)

!!! note
    默认情况下，通过 HTTP URL 获取视频的超时时间为 `30` 秒。
    您可以通过设置环境变量来覆盖此设置：

    ```bash
    export VLLM_VIDEO_FETCH_TIMEOUT=<timeout>
    ```

#### 视频帧恢复

为了在处理可能损坏或截断的视频文件时提高鲁棒性，vLLM 支持可选的帧恢复功能，使用动态窗口前向扫描方法。启用后，如果在顺序读取过程中目标帧加载失败，将使用下一个成功抓取的帧（在下一个目标帧之前）来替代。

要启用视频帧恢复，请通过 `--media-io-kwargs` 传递 `frame_recovery` 参数：

```bash
# 示例：启用帧恢复
vllm serve Qwen/Qwen3-VL-30B-A3B-Instruct \
  --media-io-kwargs '{"video": {"frame_recovery": true}}'
```

**参数：**

- `frame_recovery`: 布尔标志，启用前向扫描恢复。当为 `true` 时，失败的帧将使用动态窗口内下一个可用帧进行恢复（直到下一个目标帧）。默认为 `false`。

**工作原理：**

1. 系统顺序读取帧
2. 如果目标帧抓取失败，将其标记为"失败"
3. 使用下一个成功抓取的帧（在到达下一个目标帧之前）来恢复失败帧
4. 此方法可处理视频中间损坏和视频末尾截断的情况

与使用 OpenCV 后端的常见视频格式（如 MP4）兼容。

#### 自定义 RGBA 背景色

要为 RGBA 图像使用自定义背景色，请通过 `--media-io-kwargs` 传递 `rgba_background_color` 参数：

```bash
# 示例：为暗色主题使用黑色背景
vllm serve llava-hf/llava-1.5-7b-hf \
  --media-io-kwargs '{"image": {"rgba_background_color": [0, 0, 0]}}'

# 示例：自定义灰色背景
vllm serve llava-hf/llava-1.5-7b-hf \
  --media-io-kwargs '{"image": {"rgba_background_color": [128, 128, 128]}}'
```

### 音频输入

音频输入支持遵循 [OpenAI Audio API](https://platform.openai.com/docs/guides/audio?audio-generation-quickstart-example=audio-in)。
以下是一个使用 Ultravox-v0.5-1B 的简单示例。

首先，启动 OpenAI 兼容服务器：

```bash
vllm serve fixie-ai/ultravox-v0_5-llama-3_2-1b
```

然后，您可以如下使用 OpenAI 客户端：

??? code

    ```python
    import base64
    import requests
    from openai import OpenAI
    from vllm.assets.audio import AudioAsset

    def encode_base64_content_from_url(content_url: str) -> str:
        """将从远程 URL 获取的内容编码为 base64 格式。"""

        with requests.get(content_url) as response:
            response.raise_for_status()
            result = base64.b64encode(response.content).decode('utf-8')

        return result

    openai_api_key = "EMPTY"
    openai_api_base = "http://localhost:8000/v1"

    client = OpenAI(
        api_key=openai_api_key,
        base_url=openai_api_base,
    )

    # 所有 librosa 支持的格式都受支持
    audio_url = AudioAsset("winning_call").url
    audio_base64 = encode_base64_content_from_url(audio_url)

    chat_completion_from_base64 = client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": "What's in this audio?",
                    },
                    {
                        "type": "input_audio",
                        "input_audio": {
                            "data": audio_base64,
                            "format": "wav",
                        },
                        "uuid": audio_url,  # 可选
                    },
                ],
            },
        ],
        model=model,
        max_completion_tokens=64,
    )

    result = chat_completion_from_base64.choices[0].message.content
    print("Chat completion output from input audio:", result)
    ```

或者，您可以传递 `audio_url`，这是图像输入中 `image_url` 的音频对应项：

??? code

    ```python
    chat_completion_from_url = client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": "What's in this audio?",
                    },
                    {
                        "type": "audio_url",
                        "audio_url": {"url": audio_url},
                        "uuid": audio_url,  # 可选
                    },
                ],
            }
        ],
        model=model,
        max_completion_tokens=64,
    )

    result = chat_completion_from_url.choices[0].message.content
    print("Chat completion output from audio url:", result)
    ```

完整示例：[examples/online_serving/openai_chat_completion_client_for_multimodal.py](../../examples/online_serving/openai_chat_completion_client_for_multimodal.py)

!!! note
    默认情况下，通过 HTTP URL 获取音频的超时时间为 `10` 秒。
    您可以通过设置环境变量来覆盖此设置：

    ```bash
    export VLLM_AUDIO_FETCH_TIMEOUT=<timeout>
    ```

### 嵌入输入

要将属于某种数据类型（即图像、视频或音频）的预计算嵌入直接输入到语言模型中，请为每个项目传递一个形状为 `(..., hidden_size of LM)` 的张量到多模态字典的相应字段。

!!! important
    与离线推理不同，必须为每个项目分别传递嵌入
    才能确保聊天模板正确应用占位符令牌。

您必须通过 `vllm serve` 中的 `--enable-mm-embeds` 标志启用此功能。

!!! warning
    如果传递了错误形状的嵌入，vLLM 引擎可能会崩溃。
    仅对可信用户启用此标志！

#### 图像嵌入输入

对于图像嵌入，您可以将 base64 编码的张量传递给 `image_embeds` 字段。
以下示例演示如何向 OpenAI 服务器传递图像嵌入：

??? code

    ```python
    from vllm.utils.serial_utils import tensor2base64

    client = OpenAI(
        # 默认为 os.environ.get("OPENAI_API_KEY")
        api_key=openai_api_key,
        base_url=openai_api_base,
    )

    # 基本用法 - 这等同于离线推理的 LLaVA 示例
    model = "llava-hf/llava-1.5-7b-hf"
    embeds = {
        "type": "image_embeds",
        "image_embeds": tensor2base64(torch.load(...)),  # 形状：(image_feature_size, hidden_size)
        "uuid": image_url,  # 可选
    }


    # 需要额外字段的模型的其他示例
    model = "Qwen/Qwen2-VL-2B-Instruct"
    embeds = {
        "type": "image_embeds",
        "image_embeds": {
            "image_embeds": tensor2base64(torch.load(...)),  # 形状：(image_feature_size, hidden_size)
            "image_grid_thw": tensor2base64(torch.load(...)),  # 形状：(3,)
        },
        "uuid": image_url,  # 可选
    }

### 缓存输入

就像离线推理一样，如果您预期缓存键与提供的 UUID 匹配，可以跳过发送媒体。您可以通过以下方式发送媒体来实现：

??? code

    ```python
        # 图片/视频/音频 URL:
        {
            "type": "image_url",
            "image_url": None,
            "uuid": image_uuid,
        },

        # image_embeds
        {
            "type": "image_embeds",
            "image_embeds": None,
            "uuid": image_uuid,
        },

        # input_audio:
        {
            "type": "input_audio",
            "input_audio": None,
            "uuid": audio_uuid,
        },

        # PIL Image:
        {
            "type": "image_pil",
            "image_pil": None,
            "uuid": image_uuid,
        },

    ```