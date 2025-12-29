"""
Post-processing functions for plot_anova.

This file contains functions to apply final touches to plots after all panels are drawn.
"""

"""
    _apply_global_ylimits!(grid, plot_data, facet_spec, plot_type, errorbars, individual_data, plot_kwargs)

Apply global y-axis limits to all panels in the grid.
"""
function _apply_global_ylimits!(
    grid::FacetGrid,
    plot_data,
    facet_spec::FacetSpec,
    plot_type::Symbol,
    errorbars::Symbol,
    individual_data::Symbol,
    plot_kwargs::Dict{Symbol,Any},
)
    global_ylim = something(
        plot_kwargs[:axis_ylim],
        _calculate_global_ylimits(
            plot_data,
            facet_spec,
            plot_type,
            errorbars,
            individual_data,
            plot_kwargs,
        ),
    )
    !isnothing(global_ylim) && ylims!.(grid.axes, Ref(global_ylim))
end

"""
    _apply_layout_adjustments!(grid, facet_spec)

Apply final layout adjustments to ensure equal column/row sizes.
"""
function _apply_layout_adjustments!(grid::FacetGrid, facet_spec::FacetSpec)
    n_cols = length(facet_spec.col_levels)
    n_rows = length(facet_spec.row_levels)
    n_cols > 1 && colsize!.(Ref(grid.fig.layout), 1:n_cols, Ref(Relative(1.0 / n_cols)))
    n_rows > 1 && rowsize!.(Ref(grid.fig.layout), 1:n_rows, Ref(Relative(1.0 / n_rows)))
end

"""
    _add_legends_to_grid!(grid, y_unique, y_factors, plot_kwargs)

Add legends to the appropriate axes in the grid based on legend_when_faceting setting.
If legend_when_faceting is true, adds legend to all panels. Otherwise, only to first panel.
"""
function _add_legends_to_grid!(grid::FacetGrid, y_unique, y_factors, plot_kwargs)
    if plot_kwargs[:legend_when_faceting] # legend on each facet
        _add_legend.(grid.axes, Ref(y_unique), Ref(y_factors), Ref(plot_kwargs))
    else # legend only on first facet
        _add_legend(grid.axes[1, 1], y_unique, y_factors, plot_kwargs)
    end
end
