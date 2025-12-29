"""
Panel plotting functions for plot_anova.

This file contains functions to plot individual panels in a faceted plot.
"""

"""
    _filter_raw_data_for_facet(plot_data, facet_spec, row_idx, col_idx)

Filter raw data for a specific facet panel.
Returns an empty DataFrame if no raw data is available.
"""
function _filter_raw_data_for_facet(
    plot_data,
    facet_spec::FacetSpec,
    row_idx::Int,
    col_idx::Int,
)
    if isempty(plot_data.raw_data)
        return DataFrame()
    else
        return _filter_for_facet(
            plot_data.raw_data,
            facet_spec,
            row_idx,
            col_idx,
            plot_data.effect_factors,
        )
    end
end

"""
    _create_panel_spec(ax, plot_data, facet_spec, row_idx, col_idx, panel_params, plot_kwargs_with_theme)

Create a PlotPanelSpec for a single panel.
"""
function _create_panel_spec(
    ax,
    plot_data,
    facet_spec::FacetSpec,
    row_idx::Int,
    col_idx::Int,
    panel_params,
    plot_kwargs_with_theme::Dict{Symbol,Any},
)
    facet_emmeans = _filter_for_facet(
        plot_data.interaction_data,
        facet_spec,
        row_idx,
        col_idx,
        plot_data.effect_factors,
    )
    facet_raw = _filter_raw_data_for_facet(plot_data, facet_spec, row_idx, col_idx)

    return PlotPanelSpec(
        ax,
        facet_raw,
        facet_emmeans,
        plot_data.x_unique,
        panel_params.y_levels_for_spec,
        plot_kwargs_with_theme,
        plot_data.x_factors,
        panel_params.y_factors_for_spec,
        plot_data.effect_factors,
        plot_data.dv,
        plot_data.id_col,
    )
end

"""
    _set_panel_xticks(ax, x_unique)

Set x-axis ticks for a panel.
"""
function _set_panel_xticks(ax, x_unique::Vector)
    ax.xticks = (1:length(x_unique), [string(v) for v in x_unique])
end

"""
    _plot_all_panels!(grid, plot_data, facet_spec, plot_type, errorbars, individual_data, 
                      plot_kwargs_with_theme, panel_params)

Plot all panels in the facet grid.
Mutates the grid axes in place.
"""
function _plot_all_panels!(
    grid::FacetGrid,
    plot_data,
    facet_spec::FacetSpec,
    plot_type::Symbol,
    errorbars::Symbol,
    individual_data::Symbol,
    plot_kwargs_with_theme::Dict{Symbol,Any},
    panel_params,
)
    for (row_idx, row_level) in enumerate(facet_spec.row_levels)
        for (col_idx, col_level) in enumerate(facet_spec.col_levels)
            ax = grid.axes[row_idx, col_idx]

            # Create plot specification for this panel
            plot_spec = _create_panel_spec(
                ax,
                plot_data,
                facet_spec,
                row_idx,
                col_idx,
                panel_params,
                plot_kwargs_with_theme,
            )

            # Plot to panel
            _plot_to_panel!(
                plot_spec,
                plot_type,
                errorbars,
                individual_data,
                col_level,
                row_level,
                panel_params.y_faceting,
                panel_params.col_factors_for_spec,
                panel_params.row_factors_for_spec,
            )

            # Set x-axis ticks
            _set_panel_xticks(ax, plot_data.x_unique)
        end
    end
end
