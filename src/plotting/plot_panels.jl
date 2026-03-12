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
    _create_panel_spec(ax, plot_data, facet_spec, row_idx, col_idx, panel_params, config)

Create a PlotPanelSpec for a single panel.
"""
function _create_panel_spec(
    ax,
    plot_data,
    facet_spec::FacetSpec,
    row_idx::Int,
    col_idx::Int,
    panel_params,
    config::PlotConfig,
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
        config,
        plot_data.x_factors,
        panel_params.y_factors_for_spec,
        plot_data.effect_factors,
        plot_data.dv,
        plot_data.id_col,
    )
end

"""
    _set_panel_xticks(ax, x_unique, config)

Set x-axis ticks for a panel. Uses custom labels from `axis_xticklabels` if provided.
"""
function _set_panel_xticks(ax, x_unique::Vector, config::PlotConfig)
    custom_labels = config.axis.xticklabels
    labels = if !isnothing(custom_labels)
        n_labels = length(custom_labels)
        n_levels = length(x_unique)
        if n_labels != n_levels
            throw(ArgumentError(
                "axis_xticklabels has $n_labels labels but there are $n_levels x categories. " *
                "Expected labels for: $(x_unique)"
            ))
        end
        [string(v) for v in custom_labels]
    else
        [string(v) for v in x_unique]
    end
    ax.xticks = (1:length(x_unique), labels)
end

"""
    _plot_all_panels!(grid, plot_data, facet_spec, plot_type, errorbars, individual_data, 
                      config, panel_params)

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
    config::PlotConfig,
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
                config,
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
            _set_panel_xticks(ax, plot_data.x_unique, config)

            # Set y-axis ticks if specified
            _set_panel_yticks!(ax, config)
        end
    end
end

"""
    _set_panel_yticks!(ax, config)

Set y-axis ticks for a panel if `axis_yticks` is provided.
Accepts any value valid for Makie's `yticks` attribute (e.g., a range, vector, or tuple of (positions, labels)).
"""
function _set_panel_yticks!(ax, config::PlotConfig)
    custom_yticks = config.axis.yticks
    if !isnothing(custom_yticks)
        ax.yticks = custom_yticks
    end
end
