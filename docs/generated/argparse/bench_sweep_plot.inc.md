#### `--fig-dir`

:   The directory to save the figures, relative to `OUTPUT_DIR`. By default, the same directory is used.

:   Default: `""`

#### `--fig-by`

:   A comma-separated list of variables, such that a separate figure is created for each combination of these variables.

:   Default: `""`

#### `--row-by`

:   A comma-separated list of variables, such that a separate row is created for each combination of these variables.

:   Default: `""`

#### `--col-by`

:   A comma-separated list of variables, such that a separate column is created for each combination of these variables.

:   Default: `""`

#### `--curve-by`

:   A comma-separated list of variables, such that a separate curve is created for each combination of these variables.

#### `--var-x`

:   The variable for the x-axis.

:   Default: `request_throughput`

#### `--var-y`

:   The variable for the y-axis

:   Default: `p99_e2el_ms`

#### `--filter-by`

:   A comma-separated list of statements indicating values to filter by. This is useful to remove outliers. Example: `max_concurrency<1000,max_num_batched_tokens<=4096` means plot only the points where `max_concurrency` is less than 1000 and `max_num_batched_tokens` is no greater than 4096.

:   Default: `""`

#### `--bin-by`

:   A comma-separated list of statements indicating values to bin by. This is useful to avoid plotting points that are too close together. Example: `request_throughput%%1` means use a bin size of 1 for the `request_throughput` variable.

:   Default: `""`

#### `--scale-x`

:   The scale to use for the x-axis. Currently only accepts string values such as 'log' and 'sqrt'. See also: https://seaborn.pydata.org/generated/seaborn.objects.Plot.scale.html

#### `--scale-y`

:   The scale to use for the y-axis. Currently only accepts string values such as 'log' and 'sqrt'. See also: https://seaborn.pydata.org/generated/seaborn.objects.Plot.scale.html

#### `--fig-name`

:   Name prefix for the output figure file. Group data is always appended when present. Default: 'FIGURE'. Example: --fig-name my_performance_plot

:   Default: `FIGURE`

#### `--no-error-bars`

:   If set, disables error bars on the plot. By default, error bars are shown.

:   Default: `False`

#### `--fig-height`

:   Height of each subplot in inches. Default: 6.4

:   Default: `6.4`

#### `--fig-dpi`

:   Resolution of the output figure in dots per inch. Default: 300

:   Default: `300`

#### `--dry-run`

:   If set, prints the information about each figure to plot, then exits without drawing them.

:   Default: `False`

