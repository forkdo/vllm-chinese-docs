# CI 失败

当我的 PR 触发 CI 作业失败，但我不认为是我的 PR 导致的失败，我该怎么办？

- 查看当前 CI 测试失败的仪表板：  
  👉 [CI 失败仪表板](https://github.com/orgs/vllm-project/projects/20)

- 如果你的失败 **已经列在仪表板中**，它很可能与你的 PR 无关。  
  欢迎任何人都来协助修复问题！
    - 在评论中留下更多失败实例的链接。
    - 使用 👍 表情来表明受影响的人数。

- 如果你的失败 **未在仪表板中列出**，你应 **提交一个 Issue**。

## 提交 CI 测试失败 Issue

- **提交一个 bug 报告：**  
    👉 [新 CI 失败报告](https://github.com/vllm-project/vllm/issues/new?template=450-ci-failure.yml)

- **使用以下标题格式：**

    ```text
    [CI Failure]: failing-test-job - regex/matching/failing:test
    ```

- **对于环境字段：**

    ```text
    Still failing on main as of commit abcdef123
    ```

- **在描述中包含失败的测试：**

    ```text
    FAILED failing/test.py:failing_test1 - Failure description
    FAILED failing/test.py:failing_test2 - Failure description
    https://github.com/orgs/vllm-project/projects/20
    https://github.com/vllm-project/vllm/issues/new?template=400-bug-report.yml
    FAILED failing/test.py:failing_test3 - Failure description
    ```

- **附加日志**（可折叠部分示例）：
    <details>
    <summary>Logs:</summary>

    ```text
    ERROR 05-20 03:26:38 [dump_input.py:68] Dumping input data
    --- Logging error ---  
    Traceback (most recent call last):  
      File "/usr/local/lib/python3.12/dist-packages/vllm/v1/engine/core.py", line 203, in execute_model  
        return self.model_executor.execute_model(scheduler_output)
    ...
    FAILED failing/test.py:failing_test1 - Failure description
    FAILED failing/test.py:failing_test2 - Failure description
    FAILED failing/test.py:failing_test3 - Failure description
    ```

    </details>

## 日志处理

从 Buildkite 本地下载完整的日志文件。

去除时间戳和颜色化：

[.buildkite/scripts/ci-clean-log.sh](../../../.buildkite/scripts/ci-clean-log.sh)

```bash
./ci-clean-log.sh ci.log
```

使用工具 [wl-clipboard](https://github.com/bugaevc/wl-copy) 快速复制粘贴：

```bash
tail -525 ci_build.log | wl-copy
```

## 调查 CI 测试失败

1. 进入 👉 [Buildkite main 分支](https://buildkite.com/vllm/ci/builds?branch=main)
2. 二分查找以定位首次出现该问题的构建。  
3. 将你的发现添加到 GitHub Issue 中。  
4. 如果你找到了一个强相关的 PR，请在 Issue 中提及并@相关人员。

## 重现失败

CI 测试失败可能是偶发的。使用 bash 循环重复运行：

[.buildkite/scripts/rerun-test.sh](../../../.buildkite/scripts/rerun-test.sh)

```bash
./rerun-test.sh tests/v1/engine/test_engine_core_client.py::test_kv_cache_events[True-tcp]
```

## 提交 PR

如果你提交一个 PR 来修复 CI 失败：

- 将 PR 关联到 Issue：
  在 PR 描述中添加 `Closes #12345`。
- 添加 `ci-failure` 标签：
  这有助于在 [CI 失败 GitHub 项目](https://github.com/orgs/vllm-project/projects/20) 中跟踪。

## 其他资源

- 🔍 [main 分支上的测试可靠性](https://buildkite.com/organizations/vllm/analytics/suites/ci-1/tests?branch=main&order=ASC&sort_by=reliability)
- 🧪 [最新的 Buildkite CI 运行](https://buildkite.com/vllm/ci/builds?branch=main)

## 日常排查

使用 [Buildkite 分析（2 天视图）](https://buildkite.com/organizations/vllm/analytics/suites/ci-1/tests?branch=main&period=2days) 来：

- 识别 **main** 上的近期测试失败。
- 排除 PR 上的合法测试失败。
- （可选）忽略可靠性为 0% 的测试。

与 [CI 失败仪表板](https://github.com/orgs/vllm-project/projects/20) 进行比较。