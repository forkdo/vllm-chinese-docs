# 多模态支持

本文档将指导您如何扩展基础模型以使其接受[多模态输入](../../features/multimodal_inputs.md)。

## 1. 更新基础 vLLM 模型

假设您已按照 [这些步骤](basic.md) 在 vLLM 中实现了模型。进一步更新模型如下：

- 实现 [get_placeholder_str][vllm.model_executor.models.interfaces.SupportsMultiModal.get_placeholder_str]，以定义在文本提示中表示多模态项的占位符字符串。该占位符应与模型的聊天模板保持一致。

    ??? code

        ```python
        class YourModelForImage2Seq(nn.Module):
            ...

            @classmethod
            def get_placeholder_str(cls, modality: str, i: int) -> str | None:
                if modality.startswith("image"):
                    return "<image>"

                raise ValueError("Only image modality is supported")
        ```

- 在 `__init__` 方法中，使用 [_mark_language_model][vllm.model_executor.models.interfaces.SupportsMultiModal._mark_language_model] 初始化模型的语言组件，使用 [_mark_tower_model][vllm.model_executor.models.interfaces.SupportsMultiModal._mark_tower_model] 初始化多模态组件，例如：

    ```python
        def __init__(self, *, vllm_config: VllmConfig, prefix: str = "") -> None:
            super().__init__()

            config = vllm_config.model_config.hf_config

            with self._mark_tower_model(vllm_config, "image"):
                self.vision_encoder = ...
                self.multi_modal_projector = ...

            with self._mark_language_model(vllm_config):
                self.language_model = init_vllm_registered_model(
                    vllm_config=vllm_config,
                    hf_config=config.text_config,
                    prefix=maybe_prefix(prefix, "language_model"),
                )
    ```

- 从 [forward][torch.nn.Module.forward] 方法中移除嵌入部分：
    - 将多模态嵌入移至 [embed_multimodal][vllm.model_executor.models.interfaces.SupportsMultiModal.embed_multimodal]。
    - 文本嵌入和嵌入合并由 [embed_input_ids][vllm.model_executor.models.interfaces.SupportsMultiModal.embed_input_ids] 的默认实现自动处理，大多数情况下无需重写。

    ```diff
      def forward(
          self,
          input_ids: torch.Tensor | None,
    -     pixel_values: torch.Tensor,
          positions: torch.Tensor,
          intermediate_tensors: IntermediateTensors | None = None,
          inputs_embeds: torch.Tensor | None = None,
      ) -> torch.Tensor:
    -     if inputs_embeds is None:
    -         inputs_embeds = self.get_input_embeddings()(input_ids)
    -
    -     if pixel_values is not None:
    -         image_features = self.get_image_features(
    -             pixel_values=pixel_values,
    -         )
    -         special_image_mask = self.get_placeholder_mask(
    -             input_ids,
    -             inputs_embeds=inputs_embeds,
    -             image_features=image_features,
    -         )
    -         inputs_embeds = inputs_embeds.masked_scatter(
    -             special_image_mask,
    -             image_features,
    -         )

           hidden_states = self.language_model(
               input_ids,
               positions,
               intermediate_tensors,
               inputs_embeds=inputs_embeds,
           )
         ...
  
    +  def embed_multimodal(
    +      self,
    +      pixel_values: torch.Tensor,
    +  ) -> MultiModalEmbeddings | None:
    +      return self.get_image_features(
    +          pixel_values=pixel_values,
    +      )
    ```

    以下是一个典型的 [embed_multimodal][vllm.model_executor.models.interfaces.SupportsMultiModal.embed_multimodal] 实现模板，您可以根据需要进行调整。

    ```python
    def _process_image_input(self, image_input: YourModelImageInputs) -> torch.Tensor:
        image_features = self.vision_encoder(image_input)
        return self.multi_modal_projector(image_features)

    def embed_multimodal(
        self,
        **kwargs: object,
    ) -> MultiModalEmbeddings | None:
        # 验证多模态输入关键字参数
        image_input = self._parse_and_validate_image_input(**kwargs)
        if image_input is None:
            return None

        # 将多模态输入通过编码器和投影器处理
        vision_embeddings = self._process_image_input(image_input)
        return vision_embeddings
    ```

!!! important
    返回的 `multimodal_embeddings` 必须是 **3D [torch.Tensor][]**，形状为 `(num_items, feature_size, hidden_size)`，或是一个 **2D [torch.Tensor][] 的列表/元组**，形状为 `(feature_size, hidden_size)`，使得 `multimodal_embeddings[i]` 可以获取来自请求中第 `i` 个多模态数据项（例如图像）生成的嵌入。

!!! note
    默认情况下，vLLM 根据 [PlaceholderRange][vllm.multimodal.inputs.PlaceholderRange] 中定义的位置信息，将多模态嵌入合并到文本嵌入中。
    此逻辑可在 [embed_input_ids][vllm.model_executor.models.interfaces.SupportsMultiModal.embed_input_ids] 中找到。

    如果您的模型在合并嵌入时需要额外逻辑，可以重写此方法。

- 完成上述步骤后，使用 [SupportsMultiModal][vllm.model_executor.models.interfaces.SupportsMultiModal] 接口更新模型类。

  ```diff
  + from vllm.model_executor.models.interfaces import SupportsMultiModal

  - class YourModelForImage2Seq(nn.Module):
  + class YourModelForImage2Seq(nn.Module, SupportsMultiModal):
  ```

!!! note
    模型类的名称不必以 `*ForCausalLM` 结尾。
    有关示例，请参阅 [HuggingFace Transformers 文档](https://huggingface.co/docs/transformers/model_doc/auto#multimodal)。

## 2. 指定处理信息

接下来，创建一个 [BaseProcessingInfo][vllm.multimodal.processing.BaseProcessingInfo] 的子类，以提供与 HF 处理相关的基本信息。

### 最大输入项数量

您需要重写抽象方法 [get_supported_mm_limits][vllm.multimodal.processing.BaseProcessingInfo.get_supported_mm_limits]，以返回模型支持的每种模态的最大输入项数量。

例如，如果模型支持任意数量的图像但每个提示仅支持一个视频：

```python
def get_supported_mm_limits(self) -> Mapping[str, int | None]:
    return {"image": None, "video": 1}
```

## 3. 指定虚拟输入

然后，继承 [BaseDummyInputsBuilder][vllm.multimodal.processing.BaseDummyInputsBuilder] 来构建用于 HF 处理的虚拟输入。处理后的输出也用于内存分析。

重写抽象方法 [get_dummy_text][vllm.multimodal.processing.BaseDummyInputsBuilder.get_dummy_text] 和 [get_dummy_mm_data][vllm.multimodal.processing.BaseDummyInputsBuilder.get_dummy_mm_data] 以构建虚拟输入。这些虚拟输入应导致模型的最坏情况内存使用，以便 vLLM 可以为其预留正确的内存量。

假设内存使用量随 token 数量增加而增加，虚拟输入可构建为最大化输出嵌入的数量，该数量与占位符特征 token 的数量相同。

=== "基础示例：LLaVA"

    查看 HF 的 `LlavaForConditionalGeneration` 代码：

    ??? code

        ```python
        # https://github.com/huggingface/transformers/blob/v4.47.1/src/transformers/models/llava/modeling_llava.py#L530-L544
        n_image_tokens = (input_ids == self.config.image_token_index).sum().item()
        n_image_features = image_features.shape[0] * image_features.shape[1]

```markdown
if n_image_tokens != n_image_features:
    raise ValueError(
        f"Image features and image tokens do not match: tokens: {n_image_tokens}, features {n_image_features}"
    )
special_image_mask = (
    (input_ids == self.config.image_token_index)
    .unsqueeze(-1)
    .expand_as(inputs_embeds)
    .to(inputs_embeds.device)
)
image_features = image_features.to(inputs_embeds.device, inputs_embeds.dtype)
inputs_embeds = inputs_embeds.masked_scatter(special_image_mask, image_features)
```

The number of placeholder feature tokens per image is `image_features.shape[1]`.
`image_features` is calculated inside the `get_image_features` method:

??? code

    ```python
    # https://github.com/huggingface/transformers/blob/v4.47.1/src/transformers/models/llava/modeling_llava.py#L290-L300
    image_outputs = self.vision_tower(pixel_values, output_hidden_states=True)

    selected_image_feature = image_outputs.hidden_states[vision_feature_layer]
    if vision_feature_select_strategy == "default":
        selected_image_feature = selected_image_feature[:, 1:]
    elif vision_feature_select_strategy == "full":
        selected_image_feature = selected_image_feature
    else:
        raise ValueError(f"Unexpected select feature strategy: {self.config.vision_feature_select_strategy}")
    image_features = self.multi_modal_projector(selected_image_feature)
    return image_features
    ```

We can infer that `image_features.shape[1]` is based on `image_outputs.hidden_states.shape[1]` from the vision tower
(`CLIPVisionModel` for the [`llava-hf/llava-1.5-7b-hf`](https://huggingface.co/llava-hf/llava-1.5-7b-hf) model).
Moreover, we only need the sequence length (the second dimension of the tensor) to get `image_features.shape[1]`.
The sequence length is determined by the initial hidden states in `CLIPVisionTransformer` since the attention
mechanism doesn't change the sequence length of the output hidden states.

```python
# https://github.com/huggingface/transformers/blob/v4.47.1/src/transformers/models/clip/modeling_clip.py#L1094-L1102
hidden_states = self.embeddings(pixel_values, interpolate_pos_encoding=interpolate_pos_encoding)
hidden_states = self.pre_layrnorm(hidden_states)

encoder_outputs = self.encoder(
    inputs_embeds=hidden_states,
    output_attentions=output_attentions,
    output_hidden_states=output_hidden_states,
    return_dict=return_dict,
)
```

To find the sequence length, we turn to the code of `CLIPVisionEmbeddings`:

??? code

    ```python
    # https://github.com/huggingface/transformers/blob/v4.47.1/src/transformers/models/clip/modeling_clip.py#L247-L257
    target_dtype = self.patch_embedding.weight.dtype
    patch_embeds = self.patch_embedding(pixel_values.to(dtype=target_dtype))  # shape = [*, width, grid, grid]
    patch_embeds = patch_embeds.flatten(2).transpose(1, 2)

    class_embeds = self.class_embedding.expand(batch_size, 1, -1)
    embeddings = torch.cat([class_embeds, patch_embeds], dim=1)
    if interpolate_pos_encoding:
        embeddings = embeddings + self.interpolate_pos_encoding(embeddings, height, width)
    else:
        embeddings = embeddings + self.position_embedding(self.position_ids)
    return embeddings
    ```

We can infer that `embeddings.shape[1] == self.num_positions`, where

```python
# https://github.com/huggingface/transformers/blob/v4.47.1/src/transformers/models/clip/modeling_clip.py#L195-L196
self.num_patches = (self.image_size // self.patch_size) ** 2
self.num_positions = self.num_patches + 1
```

Overall, the number of placeholder feature tokens for an image can be calculated as:

??? code

    ```python
    def get_num_image_tokens(
        self,
        *,
        image_width: int,
        image_height: int,
    ) -> int:
        hf_config = self.get_hf_config()
        hf_processor = self.get_hf_processor()

        image_size = hf_config.vision_config.image_size
        patch_size = hf_config.vision_config.patch_size

        num_image_tokens = (image_size // patch_size) ** 2 + 1
        if hf_processor.vision_feature_select_strategy == "default":
            num_image_tokens -= 1

        return num_image_tokens
    ```

Notice that the number of image tokens doesn't depend on the image width and height.
We can simply use a dummy `image_size` to calculate the multimodal profiling data:

??? code

    ```python
    # NOTE: In actuality, this is usually implemented as part of the
    # model's subclass of `BaseProcessingInfo`, but we show it as is
    # here for simplicity.
    def get_image_size_with_most_features(self) -> ImageSize:
        hf_config = self.get_hf_config()
        width = height = hf_config.image_size
        return ImageSize(width=width, height=height)

    def get_dummy_mm_data(
        self,
        seq_len: int,
        mm_counts: Mapping[str, int],
        mm_options: Mapping[str, BaseDummyOptions] | None = None,
    ) -> MultiModalDataDict:
        num_images = mm_counts.get("image", 0)

        target_width, target_height = \
            self.info.get_image_size_with_most_features()

        image_overrides = mm_options.get("image") if mm_options else None

        return {
            "image":
            self._get_dummy_images(width=target_width,
                                height=target_height,
                                num_images=num_images,
                                overrides=image_overrides)
        }
    ```

For the text, we simply expand the multimodal image token from the model config to match the desired number of images.

```python
def get_dummy_text(self, mm_counts: Mapping[str, int]) -> str:
    num_images = mm_counts.get("image", 0)

    processor = self.info.get_hf_processor()
    image_token = processor.image_token

    return image_token * num_images
```

=== "No input placeholders: Fuyu"

    Looking at the code of HF's `FuyuForCausalLM`:

    ??? code

        ```python
        # https://github.com/huggingface/transformers/blob/v4.48.3/src/transformers/models/fuyu/modeling_fuyu.py#L311-L322
        if image_patches is not None and past_key_values is None:
            patch_embeddings = [
                self.vision_embed_tokens(patch.to(self.vision_embed_tokens.weight.dtype))
                .squeeze(0)
                .to(inputs_embeds.device)
                for patch in image_patches
            ]
            inputs_embeds = self.gather_continuous_embeddings(
                word_embeddings=inputs_embeds,
                continuous_embeddings=patch_embeddings,
                image_patch_input_indices=image_patches_indices,
            )
        ```

    The number of placeholder feature tokens for the `i`th item in the batch is `patch_embeddings[i].shape[0]`,
    which is the same as `image_patches[i].shape[0]`, i.e. `num_total_patches`.

    Unlike LLaVA, Fuyu does not define the number of patches inside the modeling file. Where can we get more information?
    Considering that the model input comes from the output of `FuyuProcessor`, let's **look at the preprocessing files**.

    The image outputs are obtained by calling `FuyuImageProcessor.preprocess` and then
    `FuyuImageProcessor.preprocess_with_tokenizer_info` inside `FuyuProcessor`.

    In `FuyuImageProcessor.preprocess`, the images are resized and padded to the target `FuyuImageProcessor.size`,
    returning the dimensions after resizing (but before padding) as metadata.

    ??? code
```

```python
        # https://github.com/huggingface/transformers/blob/v4.48.3/src/transformers/models/fuyu/processing_fuyu.py#L541-L544
        image_encoding = self.image_processor.preprocess(images, **output_kwargs["images_kwargs"])
        batch_images = image_encoding["images"]
        image_unpadded_heights = image_encoding["image_unpadded_heights"]
        image_unpadded_widths = image_encoding["image_unpadded_widths"]

        # https://github.com/huggingface/transformers/blob/v4.48.3/src/transformers/models/fuyu/image_processing_fuyu.py#L480-L
        if do_resize:
            batch_images = [
                [self.resize(image, size=size, input_data_format=input_data_format) for image in images]
                for images in batch_images
            ]

        image_sizes = [get_image_size(images[0], channel_dim=input_data_format) for images in batch_images]
        image_unpadded_heights = [[image_size[0]] for image_size in image_sizes]
        image_unpadded_widths = [[image_size[1]] for image_size in image_sizes]

        if do_pad:
            batch_images = [
                [
                    self.pad_image(
                        image,
                        size=size,
                        mode=padding_mode,
                        constant_values=padding_value,
                        input_data_format=input_data_format,
                    )
                    for image in images
                ]
                for images in batch_images
            ]
        ```

    在 `FuyuImageProcessor.preprocess_with_tokenizer_info` 中，图像会根据这些元数据被划分为图像块：

    ??? code

        ```python
        # https://github.com/huggingface/transformers/blob/v4.48.3/src/transformers/models/fuyu/processing_fuyu.py#L417-L425
        model_image_input = self.image_processor.preprocess_with_tokenizer_info(
            image_input=tensor_batch_images,
            image_present=image_present,
            image_unpadded_h=image_unpadded_heights,
            image_unpadded_w=image_unpadded_widths,
            image_placeholder_id=image_placeholder_id,
            image_newline_id=image_newline_id,
            variable_sized=True,
        )

        # https://github.com/huggingface/transformers/blob/v4.48.3/src/transformers/models/fuyu/image_processing_fuyu.py#L638-L658
        image_height, image_width = image.shape[1], image.shape[2]
        if variable_sized:  # variable_sized=True
            new_h = min(
                image_height,
                math.ceil(image_unpadded_h[batch_index, subseq_index] / patch_height) * patch_height,
            )
            new_w = min(
                image_width,
                math.ceil(image_unpadded_w[batch_index, subseq_index] / patch_width) * patch_width,
            )
            image = image[:, :new_h, :new_w]
            image_height, image_width = new_h, new_w

        num_patches = self.get_num_patches(image_height=image_height, image_width=image_width)
        tensor_of_image_ids = torch.full(
            [num_patches], image_placeholder_id, dtype=torch.int32, device=image_input.device
        )
        patches = self.patchify_image(image=image.unsqueeze(0)).squeeze(0)
        assert num_patches == patches.shape[0]
        ```

    图像块的数量由 `FuyuImageProcessor.get_num_patches` 定义：

    ??? code

        ```python
        # https://github.com/huggingface/transformers/blob/v4.48.3/src/transformers/models/fuyu/image_processing_fuyu.py#L552-L562
        patch_size = patch_size if patch_size is not None else self.patch_size
        patch_height, patch_width = self.patch_size["height"], self.patch_size["width"]

        if image_height % patch_height != 0:
            raise ValueError(f"{image_height=} must be divisible by {patch_height}")
        if image_width % patch_width != 0:
            raise ValueError(f"{image_width=} must be divisible by {patch_width}")

        num_patches_per_dim_h = image_height // patch_height
        num_patches_per_dim_w = image_width // patch_width
        num_patches = num_patches_per_dim_h * num_patches_per_dim_w
        ```

    这些图像块对应占位符标记（`|SPEAKER|`）。因此，我们只需最大化图像块的数量。由于输入图像首先会被调整为适应 `image_processor.size` 的尺寸，我们可以通过输入大小等于 `image_processor.size` 的图像来最大化图像块的数量。

    ```python
    def get_image_size_with_most_features(self) -> ImageSize:
        image_processor = self.get_image_processor()
        return ImageSize(
            width=image_processor.size["width"],
            height=image_processor.size["height"],
        )
    ```

    Fuyu 不期望在输入到 Hugging Face 处理器时包含图像占位符，因此无论图像数量多少，虚拟提示文本始终为空。

    ```python
    def get_dummy_text(self, mm_counts: Mapping[str, int]) -> str:
        return ""
    ```

    对于多模态图像配置数据，其逻辑与 LLaVA 非常相似：

    ??? code

        ```python
        def get_dummy_mm_data(
            self,
            seq_len: int,
            mm_counts: Mapping[str, int],
            mm_options: Optional[Mapping[str, BaseDummyOptions]] = None,
        ) -> MultiModalDataDict:
            target_width, target_height = \
                self.info.get_image_size_with_most_features()
            num_images = mm_counts.get("image", 0)

            image_overrides = mm_options.get("image") if mm_options else None

            return {
                "image":
                self._get_dummy_images(
                    width=target_width,
                    height=target_height,
                    num_images=num_images,
                    overrides=image_overrides,
                )
            }
        ```

## 4. 指定处理细节

之后，创建一个 [BaseMultiModalProcessor][vllm.multimodal.processing.BaseMultiModalProcessor] 的子类，以填充有关 Hugging Face 处理的缺失细节。

!!! info
    [多模态数据处理](../../design/mm_processing.md)

### 多模态字段

重写 [_get_mm_fields_config][vllm.multimodal.processing.BaseMultiModalProcessor._get_mm_fields_config]，返回由 Hugging Face 处理器输出的、与输入多模态项目相关的张量的模式。

=== "基础示例：LLaVA"

    `CLIPImageProcessor` 的输出是一个简单的张量，形状为 `(num_images, num_channels, image_height, image_width)`：

    ```python
    # https://github.com/huggingface/transformers/blob/v4.47.1/src/transformers/models/clip/image_processing_clip.py#L339-L345
    images = [
        to_channel_dimension_format(image, data_format, input_channel_dim=input_data_format)
        for image in all_images
    ]

    data = {"pixel_values": images}
    return BatchFeature(data=data, tensor_type=return_tensors)
    ```

    因此，我们重写 [_get_mm_fields_config][vllm.multimodal.processing.BaseMultiModalProcessor._get_mm_fields_config] 如下：

    ```python
    def _get_mm_fields_config(
        self,
        hf_inputs: BatchFeature,
        hf_processor_mm_kwargs: Mapping[str, object],
    ) -> Mapping[str, MultiModalFieldConfig]:
        return dict(
            pixel_values=MultiModalFieldConfig.batched("image"),
        )
    ```

    !!! note
        我们的 [实际代码](../../../vllm/model_executor/models/llava.py) 额外支持预计算的图像嵌入，可通过 `image_embeds` 参数传递给模型。

=== "带后处理：Fuyu"

    `FuyuImageProcessor.preprocess_with_tokenizer_info` 的 `image_patches` 输出会将批次中每个项目所属图像的图像块连接起来：

    ```python
    # https://github.com/huggingface/transformers/blob/v4.48.3/src/transformers/models/fuyu/image_processing_fuyu.py#L673-L679
            image_input_ids.append(tensor_of_image_ids)
            image_patches.append(patches)
        else:
            image_input_ids.append(torch.tensor([], dtype=torch.int32, device=image_input.device))
```

```markdown
    batch_image_input_ids.append(image_input_ids)
    batch_image_patches.append(image_patches)
    ```

    因此，`FuyuImageProcessor` 输出的 `image_patches` 形状为 `(1, num_images, num_patches, patch_width * patch_height * num_channels)`。

    为了支持类似 LLaVA 中使用的
    [MultiModalFieldConfig.batched][vllm.multimodal.inputs.MultiModalFieldConfig.batched]，
    我们通过重写
    [BaseMultiModalProcessor._call_hf_processor][vllm.multimodal.processing.BaseMultiModalProcessor._call_hf_processor]
    来移除额外的 batch 维度：

    ??? code

        ```python
        def _call_hf_processor(
            self,
            prompt: str,
            mm_data: Mapping[str, object],
            mm_kwargs: Mapping[str, object],
            tok_kwargs: Mapping[str, object],
        ) -> BatchFeature:
            processed_outputs = super()._call_hf_processor(
                prompt=prompt,
                mm_data=mm_data,
                mm_kwargs=mm_kwargs,
                tok_kwargs=tok_kwargs,
            )

            image_patches = processed_outputs.get("image_patches")
            if image_patches is not None:
                images = mm_data["images"]
                assert isinstance(images, list)

                # 原始输出: (1, num_images, Pn, Px * Py * C)
                # 新输出: (num_images, Pn, Px * Py * C)
                assert (isinstance(image_patches, list)
                        and len(image_patches) == 1)
                assert (isinstance(image_patches[0], torch.Tensor)
                        and len(image_patches[0]) == len(images))

                processed_outputs["image_patches"] = image_patches[0]

            return processed_outputs
        ```

    !!! note
        我们的 [实际代码](../../../vllm/model_executor/models/fuyu.py) 对纯文本输入进行了特殊处理，以防止 Hugging Face 处理器产生不必要的警告。

    !!! note
        `_call_hf_processor` 方法同时指定了 `mm_kwargs` 和 `tok_kwargs` 用于处理。
        `mm_kwargs` 用于初始化和调用 Hugging Face 处理器，而 `tok_kwargs` 仅用于调用 Hugging Face 处理器。

    这使我们能够如下重写 [_get_mm_fields_config][vllm.multimodal.processing.BaseMultiModalProcessor._get_mm_fields_config]：

    ```python
    def _get_mm_fields_config(
        self,
        hf_inputs: BatchFeature,
        hf_processor_mm_kwargs: Mapping[str, object],
    ) -> Mapping[str, MultiModalFieldConfig]:
        return dict(image_patches=MultiModalFieldConfig.batched("image"))
    ```

### Prompt 更新

重写 [_get_prompt_updates][vllm.multimodal.processing.BaseMultiModalProcessor._get_prompt_updates] 以返回一组 [PromptUpdate][vllm.multimodal.processing.PromptUpdate] 实例。

每个 [PromptUpdate][vllm.multimodal.processing.PromptUpdate] 实例指定由 Hugging Face 处理器执行的更新操作（例如：插入、替换）。

=== "基本示例：LLaVA"

    查看 HF 的 `LlavaProcessor`：

    ```python
    # https://github.com/huggingface/transformers/blob/v4.47.1/src/transformers/models/llava/processing_llava.py#L167-L170
    prompt_strings = []
    for sample in text:
        sample = sample.replace(self.image_token, self.image_token * num_image_tokens)
        prompt_strings.append(sample)
    ```

    它只是将每个输入的 `image_token` 重复 `num_image_tokens` 次（即占位符特征 token 的数量）。
    基于此，我们重写 [_get_prompt_updates][vllm.multimodal.processing.BaseMultiModalProcessor._get_prompt_updates] 如下：

    ??? code

        ```python
        def _get_prompt_updates(
            self,
            mm_items: MultiModalDataItems,
            hf_processor_mm_kwargs: Mapping[str, object],
            out_mm_kwargs: MultiModalKwargsItems,
        ) -> Sequence[PromptUpdate]:
            hf_config = self.info.get_hf_config()
            image_token_id = hf_config.image_token_index

            def get_replacement(item_idx: int):
                images = mm_items.get_items("image", ImageProcessorItems)

                image_size = images.get_image_size(item_idx)
                num_image_tokens = self.info.get_num_image_tokens(
                    image_width=image_size.width,
                    image_height=image_size.height,
                )

                return [image_token_id] * num_image_tokens

            return [
                PromptReplacement(
                    modality="image",
                    target=[image_token_id],
                    replacement=get_replacement,
                ),
            ]
        ```

=== "处理额外 token：Fuyu"

    回顾第 2 步中的特征 token 布局：

    ```
    |SPEAKER||SPEAKER|...|SPEAKER||NEWLINE|
    |SPEAKER||SPEAKER|...|SPEAKER||NEWLINE|
    ...
    |SPEAKER||SPEAKER|...|SPEAKER||NEWLINE|
    ```

    我们定义一个辅助函数直接返回 `ncols` 和 `nrows`：

    ??? code

        ```python
        def get_image_feature_grid_size(
            self,
            *,
            image_width: int,
            image_height: int,
        ) -> tuple[int, int]:
            image_processor = self.get_image_processor()
            target_width = image_processor.size["width"]
            target_height = image_processor.size["height"]
            patch_width = image_processor.patch_size["width"]
            patch_height = image_processor.patch_size["height"]

            if not (image_width <= target_width and image_height <= target_height):
                height_scale_factor = target_height / image_height
                width_scale_factor = target_width / image_width
                optimal_scale_factor = min(height_scale_factor, width_scale_factor)

                image_height = int(image_height * optimal_scale_factor)
                image_width = int(image_width * optimal_scale_factor)

            ncols = math.ceil(image_width / patch_width)
            nrows = math.ceil(image_height / patch_height)
            return ncols, nrows
        ```

    基于此，我们可以初步定义替换 token 如下：

    ??? code

        ```python
        def get_replacement(item_idx: int):
            images = mm_items.get_items("image", ImageProcessorItems)
            image_size = images.get_image_size(item_idx)

            ncols, nrows = self.info.get_image_feature_grid_size(
                image_width=image_size.width,
                image_height=image_size.height,
            )

            # `_IMAGE_TOKEN_ID` 对应 `|SPEAKER|`
            # `_NEWLINE_TOKEN_ID` 对应 `|NEWLINE|`
            return ([_IMAGE_TOKEN_ID] * ncols + [_NEWLINE_TOKEN_ID]) * nrows
        ```

    然而，这并不完全正确。在调用 `FuyuImageProcessor.preprocess_with_tokenizer_info` 后，
    还会向 prompt 中添加一个 BOS token（`<s>`）：

    ??? code

        ```python
        # https://github.com/huggingface/transformers/blob/v4.48.3/src/transformers/models/fuyu/processing_fuyu.py#L417-L435
        model_image_input = self.image_processor.preprocess_with_tokenizer_info(
            image_input=tensor_batch_images,
            image_present=image_present,
            image_unpadded_h=image_unpadded_heights,
            image_unpadded_w=image_unpadded_widths,
            image_placeholder_id=image_placeholder_id,
            image_newline_id=image_newline_id,
            variable_sized=True,
        )
        prompt_tokens, prompts_length = _tokenize_prompts_with_image_and_batch(
            tokenizer=self.tokenizer,
            prompts=prompts,
            scale_factors=scale_factors,
            max_tokens_to_generate=self.max_tokens_to_generate,
            max_position_embeddings=self.max_position_embeddings,
            add_BOS=True,
            add_beginning_of_answer_token=True,
        )
        ```

    为了仅将视觉嵌入分配给图像 token，而不是字符串，
    你可以返回一个 [PromptUpdateDetails][vllm.multimodal.processing.PromptUpdateDetails] 实例：

    ??? code
```

```python
        hf_config = self.info.get_hf_config()
        bos_token_id = hf_config.bos_token_id  # `<s>`
        assert isinstance(bos_token_id, int)

        def get_replacement_fuyu(item_idx: int):
            images = mm_items.get_items("image", ImageProcessorItems)
            image_size = images.get_image_size(item_idx)

            ncols, nrows = self.info.get_image_feature_grid_size(
                image_width=image_size.width,
                image_height=image_size.height,
            )
            image_tokens = ([_IMAGE_TOKEN_ID] * ncols + [_NEWLINE_TOKEN_ID]) * nrows

            return PromptUpdateDetails.select_token_id(
                image_tokens + [bos_token_id],
                embed_token_id=_IMAGE_TOKEN_ID,
            )
        ```

    最后，注意到 HF 处理器在对提示词进行分词时会移除 `|ENDOFTEXT|` 令牌，因此我们可以在字符串开头搜索该令牌以执行替换操作：

    ??? code

        ```python
        def _get_prompt_updates(
            self,
            mm_items: MultiModalDataItems,
            hf_processor_mm_kwargs: Mapping[str, object],
            out_mm_kwargs: MultiModalKwargsItems,
        ) -> Sequence[PromptUpdate]:
            hf_config = self.info.get_hf_config()
            bos_token_id = hf_config.bos_token_id
            assert isinstance(bos_token_id, int)

            tokenizer = self.info.get_tokenizer()
            eot_token_id = tokenizer.bos_token_id
            assert isinstance(eot_token_id, int)

            def get_replacement_fuyu(item_idx: int):
                images = mm_items.get_items("image", ImageProcessorItems)
                image_size = images.get_image_size(item_idx)

                ncols, nrows = self.info.get_image_feature_grid_size(
                    image_width=image_size.width,
                    image_height=image_size.height,
                )
                image_tokens = ([_IMAGE_TOKEN_ID] * ncols + [_NEWLINE_TOKEN_ID]) * nrows

                return PromptUpdateDetails.select_token_id(
                    image_tokens + [bos_token_id],
                    embed_token_id=_IMAGE_TOKEN_ID,
                )

            return [
                PromptReplacement(
                    modality="image",
                    target=[eot_token_id],
                    replacement=get_replacement_fuyu,
                )
            ]
        ```

## 5. 注册与处理器相关的类

在定义了 [BaseProcessingInfo][vllm.multimodal.processing.BaseProcessingInfo]（第 2 步）、[BaseDummyInputsBuilder][vllm.multimodal.processing.BaseDummyInputsBuilder]（第 3 步）以及 [BaseMultiModalProcessor][vllm.multimodal.processing.BaseMultiModalProcessor]（第 4 步）之后，使用 [MULTIMODAL_REGISTRY.register_processor][vllm.multimodal.registry.MultiModalRegistry.register_processor] 装饰模型类，将其注册到多模态注册表中：

```diff
  from vllm.model_executor.models.interfaces import SupportsMultiModal
+ from vllm.multimodal import MULTIMODAL_REGISTRY

+ @MULTIMODAL_REGISTRY.register_processor(
+     YourMultiModalProcessor,
+     info=YourProcessingInfo,
+     dummy_inputs=YourDummyInputsBuilder,
+ )
  class YourModelForImage2Seq(nn.Module, SupportsMultiModal):
```

## 注意事项

### 不通过替换插入特征令牌

某些 HF 处理器会直接在原始提示词中插入特征令牌，而不替换原有内容。在这种情况下，您可以在 [_get_prompt_updates][vllm.multimodal.processing.BaseMultiModalProcessor._get_prompt_updates] 中使用 [PromptInsertion][vllm.multimodal.processing.PromptInsertion]，而不是 [PromptReplacement][vllm.multimodal.processing.PromptReplacement]。

示例：

- BLIP-2（在提示词开头插入）：[vllm/model_executor/models/blip2.py](../../../vllm/model_executor/models/blip2.py)
- Molmo（在 `` 令牌后插入）：[vllm/model_executor/models/molmo.py](../../../vllm/model_executor/models/molmo.py)

### 处理与多模态数据无关的提示词更新

[_get_prompt_updates][vllm.multimodal.processing.BaseMultiModalProcessor._get_prompt_updates] 假设每次提示词更新都对应一个单独的多模态数据项。如果 HF 处理器执行的处理与多模态数据项数量无关，您应重写 [_apply_hf_processor_tokens_only][vllm.multimodal.processing.BaseMultiModalProcessor._apply_hf_processor_tokens_only]，以确保仅处理令牌输入的结果与对纯文本输入应用 HF 处理器的结果保持一致。这是因为根据 [我们的设计](../../design/mm_processing.md)，令牌输入会绕过 HF 处理器。

示例：

- Chameleon（追加 `sep_token`）：[vllm/model_executor/models/chameleon.py](../../../vllm/model_executor/models/chameleon.py)
- Fuyu（追加 `boa_token`）：[vllm/model_executor/models/fuyu.py](../../../vllm/model_executor/models/fuyu.py)
- Molmo（应用未在其他地方定义的聊天模板）：[vllm/model_executor/models/molmo.py](../../../vllm/model_executor/models/molmo.py)

### 自定义 HF 处理器

某些模型在 Hugging Face Hub 上未定义 HF 处理器类。在这种情况下，您可以定义一个自定义的 HF 处理器，其调用签名与标准 HF 处理器一致，并将其传递给 [_call_hf_processor][vllm.multimodal.processing.BaseMultiModalProcessor._call_hf_processor]。

示例：

- DeepSeek-VL2：[vllm/model_executor/models/deepseek_vl2.py](../../../vllm/model_executor/models/deepseek_vl2.py)
- InternVL：[vllm/model_executor/models/internvl.py](../../../vllm/model_executor/models/internvl.py)
- Qwen-VL：[vllm/model_executor/models/qwen_vl.py](../../../vllm/model_executor/models/qwen_vl.py)
```