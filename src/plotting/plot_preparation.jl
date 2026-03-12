"""
Parameter preparation functions for plot_anova.

This file contains functions to prepare and merge plot parameters, themes, and specifications.
"""

"""
    _prepare_plot_kwargs(kwargs)

Construct a `PlotConfig` from user kwargs, validating all arguments.
Returns a `PlotConfig` with typed, validated parameters.

Throws `ArgumentError` for unrecognized kwargs (catches typos like `violin_colr`).
"""
function _prepare_plot_kwargs(kwargs)
    return PlotConfig(; kwargs...)
end

"""
    _prepare_plot_theme!(config::PlotConfig)

Prepare the plot theme by merging user theme with defaults.
Sets `config._resolved_theme` and returns the Theme object.
"""
function _prepare_plot_theme!(config::PlotConfig)
    if !isnothing(config.theme)
        config._resolved_theme = merge(config.theme, _default_plot_theme())
    else
        config._resolved_theme = _default_plot_theme()
    end
    return config._resolved_theme
end

"""
    _prepare_y_unique(plot_data, y_faceting, config)

Determine the y_unique levels to use for plotting, considering faceting and legend settings.
Returns the y_unique vector (or nothing) to use for the plot.
"""
function _prepare_y_unique(plot_data, y_faceting::Bool, config::PlotConfig)
    if isnothing(plot_data.y_unique)
        return nothing
    elseif y_faceting && !config.legend.when_faceting
        # Facets distinguish y-levels, no legend needed
        return nothing
    else
        return _reorder(plot_data.y_unique, config.legend.order)
    end
end

"""
    _should_hide_y_in_legend(y_faceting, config)

Determine if y-grouping should be hidden from legend (when used for faceting).
"""
_should_hide_y_in_legend(y_faceting::Bool, config::PlotConfig) =
    y_faceting && !config.legend.when_faceting

"""
    _prepare_panel_spec_parameters(plot_data, y_faceting, config, y_unique)

Prepare parameters that are the same for all panels.

# Arguments
- `plot_data`: Prepared plot data from `_prepare_plot_data`
- `y_faceting`: Whether y-grouping factors are used for faceting
- `config`: PlotConfig configuration
- `y_unique`: Prepared y_unique levels (or nothing)

# Returns
NamedTuple with y_factors_for_spec, y_levels_for_spec, col_factors_for_spec, row_factors_for_spec, y_faceting.
"""
function _prepare_panel_spec_parameters(
    plot_data,
    y_faceting::Bool,
    config::PlotConfig,
    y_unique,
)
    hide_y = _should_hide_y_in_legend(y_faceting, config)

    y_factors_for_spec = hide_y ? Symbol[] : plot_data.y_factors
    y_levels_for_spec = hide_y ? nothing : y_unique
    col_factors_for_spec = isempty(plot_data.col_factors) ? nothing : plot_data.col_factors
    row_factors_for_spec = isempty(plot_data.row_factors) ? nothing : plot_data.row_factors

    return (
        y_factors_for_spec = y_factors_for_spec,
        y_levels_for_spec = y_levels_for_spec,
        col_factors_for_spec = col_factors_for_spec,
        row_factors_for_spec = row_factors_for_spec,
        y_faceting = y_faceting,
    )
end
