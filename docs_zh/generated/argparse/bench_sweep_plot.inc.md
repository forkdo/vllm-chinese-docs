#### `--fig-dir`

:   保存图表的目录，相对于 `OUTPUT_DIR`。默认使用相同目录。

:   默认值：`""`

#### `--fig-by`

:   以逗号分隔的变量列表，为这些变量的每种组合创建单独的图表。

:   默认值：`""`

#### `--row-by`

:   以逗号分隔的变量列表，为这些变量的每种组合创建单独的行。

:   默认值：`""`

#### `--col-by`

:   以逗号分隔的变量列表，为这些变量的每种组合创建单独的列。

:   默认值：`""`

#### `--curve-by`

:   以逗号分隔的变量列表，为这些变量的每种组合创建单独的曲线。

#### `--var-x`

:   X 轴变量。

:   默认值：`request_throughput`

#### `--var-y`

:   Y 轴变量

:   默认值：`p99_e2el_ms`

#### `--filter-by`

:   以逗号分隔的语句列表，用于指定过滤条件。可用于去除异常值。例如：`max_concurrency<1000,max_num_batched_tokens<=4096` 表示仅绘制 `max_concurrency` 小于 1000 且 `max_num_batched_tokens` 不大于 4096 的数据点。

:   默认值：`""`

#### `--bin-by`

:   以逗号分隔的语句列表，用于指定分箱条件。可用于避免绘制过于密集的数据点。例如：`request_throughput%%1` 表示对 `request_throughput` 变量使用大小为 1 的分箱。

:   默认值：`""`

#### `--scale-x`

:   X 轴使用的比例尺。目前仅接受字符串值，如 'log' 和 'sqrt'。另请参阅：https://seaborn.pydata.org/generated/seaborn.objects.Plot.scale.html

#### `--scale-y`

:   Y 轴使用的比例尺。目前仅接受字符串值，如 'log' 和 'sqrt'。另请参阅：https://seaborn.pydata.org/generated/seaborn.objects.Plot.scale.html

#### `--fig-name`

:   输出图表文件名的前缀。当存在分组数据时，始终会附加分组信息。默认值：'FIGURE'。例如：--fig-name my_performance_plot

:   默认值：`FIGURE`

#### `--no-error-bars`

:   如果设置，则禁用图表上的误差条。默认情况下会显示误差条。

:   默认值：`False`

#### `--fig-height`

:   每个子图的高度（英寸）。默认值：6.4

:   默认值：`6.4`

#### `--fig-dpi`

:   输出图表的分辨率（每英寸点数）。默认值：300

:   默认值：`300`

#### `--dry-run`

:   如果设置，则打印每个待绘制图表的信息，然后退出而不实际绘制。

:   默认值：`False`