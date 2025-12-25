"""
Parameter preparation functions for plot_anova.

This file contains functions to prepare and merge plot parameters, themes, and specifications.
"""

"""
    _prepare_plot_kwargs(kwargs)

Merge user kwargs with defaults from PLOT_KWARGS.
Returns a Dict with all plot configuration parameters.
"""
function _prepare_plot_kwargs(kwargs)
    defaults = Dict(key => default_val for (key, (default_val, _)) in PLOT_KWARGS)
    return merge(defaults, kwargs)
end

"""
    _prepare_plot_theme(plot_kwargs)

Prepare the plot theme by merging user theme with defaults.
Returns the Theme object to use for plotting.
"""
function _prepare_plot_theme(plot_kwargs::Dict{Symbol,Any})
    if !isnothing(plot_kwargs[:theme])
        return merge(plot_kwargs[:theme], _default_plot_theme())
    else
        return _default_plot_theme()
    end
end

"""
    _prepare_y_unique(plot_data, y_faceting, plot_kwargs)

Determine the y_unique levels to use for plotting, considering faceting and legend settings.
Returns the y_unique vector (or nothing) to use for the plot.
"""
function _prepare_y_unique(plot_data, y_faceting::Bool, plot_kwargs::Dict{Symbol,Any})
    if isnothing(plot_data.y_unique)
        return nothing
    elseif y_faceting && !plot_kwargs[:legend_when_faceting]
        # Facets distinguish y-levels, no legend needed
        return nothing
    else
        return _reorder(plot_data.y_unique, plot_kwargs[:legend_order])
    end
end

"""
    _should_hide_y_in_legend(y_faceting, plot_kwargs)

Determine if y-grouping should be hidden from legend (when used for faceting).
"""
_should_hide_y_in_legend(y_faceting::Bool, plot_kwargs::Dict{Symbol,Any}) =
    y_faceting && !plot_kwargs[:legend_when_faceting]

"""
    _add_theme_to_kwargs(plot_kwargs, plot_theme)

Add theme to plot_kwargs dictionary as an internal parameter.
Returns a new dictionary with the theme added.
"""
function _add_theme_to_kwargs(plot_kwargs::Dict{Symbol,Any}, plot_theme)
    plot_kwargs_with_theme = copy(plot_kwargs)
    plot_kwargs_with_theme[:_internal_theme] = plot_theme
    return plot_kwargs_with_theme
end

"""
    _prepare_panel_spec_parameters(plot_data, y_faceting, plot_kwargs, y_unique)

Prepare parameters that are the same for all panels.

# Arguments
- `plot_data`: Prepared plot data from `_prepare_plot_data`
- `y_faceting`: Whether y-grouping factors are used for faceting
- `plot_kwargs`: Plot configuration dictionary
- `y_unique`: Prepared y_unique levels (or nothing)

# Returns
NamedTuple with y_factors_for_spec, y_levels_for_spec, col_factors_for_spec, row_factors_for_spec, y_faceting.
"""
function _prepare_panel_spec_parameters(
    plot_data,
    y_faceting::Bool,
    plot_kwargs::Dict{Symbol,Any},
    y_unique,
)
    hide_y = _should_hide_y_in_legend(y_faceting, plot_kwargs)

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
