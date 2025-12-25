
"""
    plot_anova(result; x_grouping, y_grouping=nothing, ...)

Plot interaction effects with flexible x-axis, y-axis grouping, and faceting by rows and columns.

# Arguments
- `result`: An `AnovaResult` or `EmmeansResult` object. If `AnovaResult` is provided, `emmeans()` is called internally.
- `x_grouping`: Factor(s) for x-axis. Can be a `Symbol` or `Vector{Symbol}`/`Tuple` for nested grouping
- `y_grouping`: Optional factor(s) for grouping/coloring lines. Can be a `Symbol` or `Vector{Symbol}`/`Tuple` (default: `nothing`)
- `facet_cols`: Optional factor(s) for column facets. Can be a `Symbol` or `Vector{Symbol}`/`Tuple` (default: `nothing`)
- `facet_rows`: Optional factor(s) for row facets. Can be a `Symbol` or `Vector{Symbol}`/`Tuple` (default: `nothing`)
- `plot_type`: Type of plot to create. Options: `:line` (default), `:bar`, `:violin`, `:boxplot`, or `:raincloud`. Note: `:violin`, `:boxplot`, and `:raincloud` require raw data in `result.data`. A raincloud plot combines a violin plot, boxplot, and individual data points (individual points are always shown in raincloud plots via Makie's built-in `rainclouds!`).
- `errorbars`: Type of error bars. Options: `:none` (no error bars), `:emmeans` (default, uses emmeans confidence intervals), or `:within` (Cousineau-Morey method for within-subjects designs). `:within` requires raw data in `result.data`.
- `individual_data`: How to display individual data points. Options: `:none` (default, no individual data), `:points` (show individual data points with random jitter), or `:connected_points` (show points and connect them with lines). `:points` and `:connected_points` require raw data in `result.data`. Lines connect points from the same subject across x-axis positions.

# Plotting Customization

Any parameter from `PLOT_KWARGS` can be passed as a keyword argument to customize the plot.
Common examples include:
- `linewidth`, `linestyle`, `marker`, `markersize`: Line plot customization (or set via theme palette)
- `boxplot_color`, `boxplot_strokecolor`, `boxplot_strokewidth`: Boxplot customization
- `violin_color`, `violin_alpha`: Violin plot customization
- `individual_data_color`, `individual_data_markersize`, `individual_data_alpha`: Individual data point customization
- `axis_xlabel`, `axis_ylabel`, `axis_xlim`, `axis_ylim`: Axis customization (functional settings)
- `figure_size`: Figure size customization
- `theme`: Theme customization (font sizes, grid colors/visibility, etc.). See `_default_plot_theme()` for defaults.

See `PLOT_KWARGS` for the complete list of customizable parameters.

# Returns
A Makie figure object

# Examples
```julia
result = anova(data, :dv, :id, within=[:time, :condition, :group])

# Can use AnovaResult directly (emmeans called internally)
plot_anova(result, x_grouping=:time, y_grouping=:condition)

# Or use EmmeansResult explicitly
em = emmeans(result)
plot_anova(em, x_grouping=:time, y_grouping=:condition)

# Custom colors (via theme palette)
plot_anova(em, x_grouping=:time, y_grouping=:condition, 
                theme = Theme(palette = (color = [:red, :blue, :green],)))

# Custom line styles (via theme palette)
plot_anova(em, x_grouping=:time, y_grouping=:condition,
                theme = Theme(palette = (linestyle = [:solid, :dash, :dot], linewidth = [3.0],)))

# Custom boxplot
plot_anova(em, x_grouping=:time, y_grouping=:condition, plot_type=:boxplot,
                boxplot_strokecolor=:blue, boxplot_strokewidth=2.0)

# Custom error bars
plot_anova(em, x_grouping=:time, y_grouping=:condition,
                errorbar_color=:gray, errorbar_linewidth=2.0)
```
"""
# Method for AnovaResult - calls emmeans internally
function plot_anova(
    result::AnovaResult;
    x_grouping,
    y_grouping = nothing,
    facet_cols = nothing,
    facet_rows = nothing,
    plot_type::Symbol = :line,
    errorbars::Symbol = :SE,
    individual_data::Symbol = :none,
    emmeans_level::Float64 = 0.95,
    emmeans_adjust::Symbol = :none,
    kwargs...,
)
    em_result = emmeans(result; level = emmeans_level, adjust = emmeans_adjust)
    return plot_anova(
        em_result;
        x_grouping = x_grouping,
        y_grouping = y_grouping,
        facet_cols = facet_cols,
        facet_rows = facet_rows,
        plot_type = plot_type,
        errorbars = errorbars,
        individual_data = individual_data,
        kwargs...,
    )
end

function plot_anova(
    result::EmmeansResult;
    x_grouping,
    y_grouping = nothing,
    facet_cols = nothing,
    facet_rows = nothing,
    plot_type::Symbol = :line,
    errorbars::Symbol = :SE,
    individual_data::Symbol = :none,
    kwargs...,
)

    _validate_plot_parameters(plot_type, errorbars, individual_data)
    errorbar_limits!(result, errorbars)
    plot_kwargs = _prepare_plot_kwargs(kwargs)
    plot_theme = _prepare_plot_theme(plot_kwargs)
    plot_data = _prepare_plot_data(result, x_grouping, y_grouping, facet_cols, facet_rows)

    # Create facet specification
    facet_spec = _create_facet_spec(
        facet_cols,
        facet_rows,
        plot_data.effect_factors,
        plot_data.interaction_data,
    )

    # Determine y-grouping usage and plot_data_y_unique
    y_faceting =
        _is_y_faceting(plot_data.y_factors, plot_data.col_factors, plot_data.row_factors)
    y_unique = _prepare_y_unique(plot_data, y_faceting, plot_kwargs)

    # facet grid
    grid = _create_facet_grid(
        facet_spec,
        plot_kwargs,
        plot_data.x_factors,
        plot_data.x_unique,
        y_unique,
        y_faceting,
        plot_theme,
    )

    # panel parameters
    plot_kwargs = _add_theme_to_kwargs(plot_kwargs, plot_theme)
    panel_params =
        _prepare_panel_spec_parameters(plot_data, y_faceting, plot_kwargs, y_unique)

    # all panels
    with_theme(plot_theme) do
        _plot_all_panels!(
            grid,
            plot_data,
            facet_spec,
            plot_type,
            errorbars,
            individual_data,
            plot_kwargs,
            panel_params,
        )
    end

    # post-processing
    _apply_global_ylimits!(
        grid,
        plot_data,
        facet_spec,
        plot_type,
        errorbars,
        individual_data,
        plot_kwargs,
    )
    _add_legends_to_grid!(grid, y_unique, plot_data.y_factors, plot_kwargs)
    _apply_layout_adjustments!(grid, facet_spec)

    return grid.fig
end

"""
Plot to a single panel (faceted or not).
This is the main dispatcher that calls the appropriate plot function.
"""
function _plot_to_panel!(
    plot_spec::PlotPanelSpec,
    plot_type::Symbol,
    errorbars::Symbol,
    individual_data::Symbol,
    col_level::Any,
    row_level::Any,
    y_faceting::Bool,
    col_factors::Union{Nothing,Vector{Symbol}},
    row_factors::Union{Nothing,Vector{Symbol}},
)
    # Bundle facet-related arguments into FacetContext to reduce parameter repetition
    facet_ctx = FacetContext(col_factors, col_level, row_factors, row_level, y_faceting)

    # Dispatch to appropriate plot function
    if plot_type ∈ [:line, :bar]
        _plot_emmeans_based!(plot_spec, plot_type, errorbars, facet_ctx, individual_data)
    elseif plot_type == :violin
        _plot_violin!(plot_spec, facet_ctx, individual_data)
    elseif plot_type == :boxplot
        _plot_boxplot!(plot_spec, facet_ctx, individual_data)
    elseif plot_type == :raincloud
        _plot_raincloud!(plot_spec, facet_ctx)
    elseif plot_type == :raincloud_custom
        _plot_raincloud_custom!(plot_spec, facet_ctx, errorbars, individual_data)
    elseif plot_type == :raincloud_custom_2x2
        _plot_raincloud_custom_2x2!(plot_spec, facet_ctx, errorbars, individual_data)
    else
        error("Unknown plot type: $plot_type")
    end
end
