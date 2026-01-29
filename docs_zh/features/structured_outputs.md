# 结构化输出

vLLM 支持使用 [xgrammar](https://github.com/mlc-ai/xgrammar) 或 [guidance](https://github.com/guidance-ai/llguidance) 作为后端来生成结构化输出。  
本文档展示了可用于生成结构化输出的不同选项的示例。

!!! warning
    如果您仍在使用 v0.12.0 中已移除的以下已弃用 API 字段，请更新代码以使用 `structured_outputs`，如下文所示：

    - `guided_json` -> `{"structured_outputs": {"json": ...}}` 或 `StructuredOutputsParams(json=...)`
    - `guided_regex` -> `{"structured_outputs": {"regex": ...}}` 或 `StructuredOutputsParams(regex=...)`
    - `guided_choice` -> `{"structured_outputs": {"choice": ...}}` 或 `StructuredOutputsParams(choice=...)`
    - `guided_grammar` -> `{"structured_outputs": {"grammar": ...}}` 或 `StructuredOutputsParams(grammar=...)`
    - `guided_whitespace_pattern` -> `{"structured_outputs": {"whitespace_pattern": ...}}` 或 `StructuredOutputsParams(whitespace_pattern=...)`
    - `structural_tag` -> `{"structured_outputs": {"structural_tag": ...}}` 或 `StructuredOutputsParams(structural_tag=...)`
    - `guided_decoding_backend` -> 从请求中移除此字段

## 在线服务（OpenAI API）

您可以使用 OpenAI 的 [Completions](https://platform.openai.com/docs/api-reference/completions) 和 [Chat](https://platform.openai.com/docs/api-reference/chat) API 生成结构化输出。

支持以下参数，这些参数必须作为额外参数添加：

- `choice`：输出将是给定选项中的一个。
- `regex`：输出将遵循正则表达式模式。
- `json`：输出将遵循 JSON 模式。
- `grammar`：输出将遵循上下文无关文法。
- `structural_tag`：在生成文本的指定标签范围内遵循 JSON 模式。

您可以在 [OpenAI 兼容服务器](../serving/openai_compatible_server.md) 页面查看支持的参数完整列表。

OpenAI 兼容服务器默认支持结构化输出。您可以通过设置 `--structured-outputs-config.backend` 标志来选择使用的后端。默认后端为 `auto`，它会根据请求的详细信息尝试选择合适的后端。您也可以选择特定的后端，并配置一些选项。完整的选项集可在 `vllm serve --help` 的输出文本中找到。

现在让我们来看每种情况的示例，从最简单的 `choice` 开始：

??? code

    ```python
    from openai import OpenAI
    client = OpenAI(
        base_url="http://localhost:8000/v1",
        api_key="-",
    )
    model = client.models.list().data[0].id

    completion = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "user", "content": "Classify this sentiment: vLLM is wonderful!"}
        ],
        extra_body={"structured_outputs": {"choice": ["positive", "negative"]}},
    )
    print(completion.choices[0].message.content)
    ```

下一个示例展示了如何使用 `regex`。支持的正则表达式语法取决于结构化输出后端。例如，`xgrammar`、`guidance` 和 `outlines` 使用 Rust 风格的正则表达式，而 `lm-format-enforcer` 使用 Python 的 `re` 模块。其思路是根据一个简单的正则模板生成一个电子邮件地址：

??? code

    ```python
    completion = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "user",
                "content": "Generate an example email address for Alan Turing, who works in Enigma. End in .com and new line. Example result: alan.turing@enigma.com\n",
            }
        ],
        extra_body={"structured_outputs": {"regex": r"\w+@\w+\.com\n"}, "stop": ["\n"]},
    )
    print(completion.choices[0].message.content)
    ```

结构化文本生成中最重要的功能之一是能够生成具有预定义字段和格式的有效 JSON。  
为此，我们可以通过两种方式使用 `json` 参数：

- 直接使用 [JSON Schema](https://json-schema.org/)
- 定义一个 [Pydantic 模型](https://docs.pydantic.dev/latest/)，然后从中提取 JSON Schema（通常这是更简单的选择）

下一个示例展示了如何使用 `response_format` 参数配合 Pydantic 模型：

??? code

    ```python
    from pydantic import BaseModel
    from enum import Enum

    class CarType(str, Enum):
        sedan = "sedan"
        suv = "SUV"
        truck = "Truck"
        coupe = "Coupe"

    class CarDescription(BaseModel):
        brand: str
        model: str
        car_type: CarType

    json_schema = CarDescription.model_json_schema()

    completion = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "user",
                "content": "Generate a JSON with the brand, model and car_type of the most iconic car from the 90's",
            }
        ],
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "car-description",
                "schema": CarDescription.model_json_schema()
            },
        },
    )
    print(completion.choices[0].message.content)
    ```

!!! tip
    虽然不是严格必需，但通常建议在提示中指明 JSON 模式以及如何填充字段。这在大多数情况下可以显著改善结果。

最后是 `grammar` 选项，它可能是最难使用的，但功能非常强大。它允许我们定义完整的语言，例如 SQL 查询。其工作原理是使用上下文无关的 EBNF 文法。  
例如，我们可以使用它来定义简化 SQL 查询的特定格式：

??? code

    ```python
    simplified_sql_grammar = """
        root ::= select_statement

        select_statement ::= "SELECT " column " from " table " where " condition

        column ::= "col_1 " | "col_2 "

        table ::= "table_1 " | "table_2 "

        condition ::= column "= " number

        number ::= "1 " | "2 "
    """

    completion = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "user",
                "content": "Generate an SQL query to show the 'username' and 'email' from the 'users' table.",
            }
        ],
        extra_body={"structured_outputs": {"grammar": simplified_sql_grammar}},
    )
    print(completion.choices[0].message.content)
    ```

另见：[完整示例](../examples/online_serving/structured_outputs.md)

## 推理输出

您也可以将结构化输出与 <project:#reasoning-outputs> 推理模型结合使用。

```bash
vllm serve deepseek-ai/DeepSeek-R1-Distill-Qwen-7B --reasoning-parser deepseek_r1
```

请注意，您可以将推理与任何提供的结构化输出功能结合使用。以下示例使用了 JSON Schema：

??? code

    ```python
    from pydantic import BaseModel


    class People(BaseModel):
        name: str
        age: int


    completion = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "user",
                "content": "Generate a JSON with the name and age of one random person.",
            }
        ],
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "people",
                "schema": People.model_json_schema()
            }
        },
    )
    print("reasoning: ", completion.choices[0].message.reasoning)
    print("content: ", completion.choices[0].message.content)
    ```

另见：[完整示例](../examples/online_serving/structured_outputs.md)

## 实验性自动解析（OpenAI API）

本节介绍 `client.chat.completions.create()` 方法的 OpenAI beta 封装，该封装提供了与 Python 特定类型的更丰富集成。

在撰写本文时（`openai==1.54.4`），这是 OpenAI 客户端库中的一个“测试版”功能。代码参考可参见[此处](https://github.com/openai/openai-python/blob/52357cff50bee57ef442e94d78a0de38b4173fc2/src/openai/resources/beta/chat/completions.py#L100-L104)。

以下示例中，vLLM 通过 `vllm serve meta-llama/Llama-3.1-8B-Instruct` 启动。

下面是一个简单的示例，演示如何使用 Pydantic 模型获取结构化输出：

??? code

    ```python
    from pydantic import BaseModel
    from openai import OpenAI

    class Info(BaseModel):
        name: str
        age: int

    client = OpenAI(base_url="http://0.0.0.0:8000/v1", api_key="dummy")
    model = client.models.list().data[0].id
    completion = client.beta.chat.completions.parse(
        model=model,
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "My name is Cameron, I'm 28. What's my name and age?"},
        ],
        response_format=Info,
    )

    message = completion.choices[0].message
    print(message)
    assert message.parsed
    print("Name:", message.parsed.name)
    print("Age:", message.parsed.age)
    ```

```console
ParsedChatCompletionMessage[Testing](content='{"name": "Cameron", "age": 28}', refusal=None, role='assistant', audio=None, function_call=None, tool_calls=[], parsed=Testing(name='Cameron', age=28))
Name: Cameron
Age: 28
```

下面是一个更复杂的示例，使用嵌套的 Pydantic 模型来处理分步数学解答：

??? code

    ```python
    from typing import List
    from pydantic import BaseModel
    from openai import OpenAI

    class Step(BaseModel):
        explanation: str
        output: str

    class MathResponse(BaseModel):
        steps: list[Step]
        final_answer: str

    completion = client.beta.chat.completions.parse(
        model=model,
        messages=[
            {"role": "system", "content": "You are a helpful expert math tutor."},
            {"role": "user", "content": "Solve 8x + 31 = 2."},
        ],
        response_format=MathResponse,
    )

    message = completion.choices[0].message
    print(message)
    assert message.parsed
    for i, step in enumerate(message.parsed.steps):
        print(f"Step #{i}:", step)
    print("Answer:", message.parsed.final_answer)
    ```

输出：

```console
ParsedChatCompletionMessage[MathResponse](content='{ "steps": [{ "explanation": "First, let\'s isolate the term with the variable \'x\'. To do this, we\'ll subtract 31 from both sides of the equation.", "output": "8x + 31 - 31 = 2 - 31"}, { "explanation": "By subtracting 31 from both sides, we simplify the equation to 8x = -29.", "output": "8x = -29"}, { "explanation": "Next, let\'s isolate \'x\' by dividing both sides of the equation by 8.", "output": "8x / 8 = -29 / 8"}], "final_answer": "x = -29/8" }', refusal=None, role='assistant', audio=None, function_call=None, tool_calls=[], parsed=MathResponse(steps=[Step(explanation="First, let's isolate the term with the variable 'x'. To do this, we'll subtract 31 from both sides of the equation.", output='8x + 31 - 31 = 2 - 31'), Step(explanation='By subtracting 31 from both sides, we simplify the equation to 8x = -29.', output='8x = -29'), Step(explanation="Next, let's isolate 'x' by dividing both sides of the equation by 8.", output='8x / 8 = -29 / 8')], final_answer='x = -29/8'))
Step #0: explanation="First, let's isolate the term with the variable 'x'. To do this, we'll subtract 31 from both sides of the equation." output='8x + 31 - 31 = 2 - 31'
Step #1: explanation='By subtracting 31 from both sides, we simplify the equation to 8x = -29.' output='8x = -29'
Step #2: explanation="Next, let's isolate 'x' by dividing both sides of the equation by 8." output='8x / 8 = -29 / 8'
Answer: x = -29/8
```

关于 `structural_tag` 的示例可参见：[examples/online_serving/structured_outputs](../../examples/online_serving/structured_outputs)

## 离线推理

离线推理支持相同类型的结构化输出。  
要使用它，我们需要在 `SamplingParams` 中通过 `StructuredOutputsParams` 类配置结构化输出。  
`StructuredOutputsParams` 中可用的主要参数包括：

- `json`
- `regex`
- `choice`
- `grammar`
- `structural_tag`

这些参数的使用方式与上述在线服务示例中的参数相同。下面展示了 `choice` 参数的一个使用示例：

??? code

    ```python
    from vllm import LLM, SamplingParams
    from vllm.sampling_params import StructuredOutputsParams

    llm = LLM(model="HuggingFaceTB/SmolLM2-1.7B-Instruct")

    structured_outputs_params = StructuredOutputsParams(choice=["Positive", "Negative"])
    sampling_params = SamplingParams(structured_outputs=structured_outputs_params)
    outputs = llm.generate(
        prompts="Classify this sentiment: vLLM is wonderful!",
        sampling_params=sampling_params,
    )
    print(outputs[0].outputs[0].text)
    ```

另请参阅：[完整示例](../examples/online_serving/structured_outputs.md)