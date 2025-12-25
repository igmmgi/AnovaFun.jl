"""
Line and bar plot implementations.

This file contains:
- `_plot_emmeans_based!`: Core function for line/bar plots with means and error bars
- `_plot_line!`: Line plot wrapper
- `_plot_bar!`: Bar plot wrapper
"""

"""
    _plot_single_group!(
        setup, plot_type, errorbars, y_level, plot_idx,
        facet_ctx, plot_spec, individual_data
    )

Plot a single group (y-level) for line/bar plots.
Handles main plot element, error bars, and individual data points.
"""
function _plot_single_group!(
    setup,
    plot_type::Symbol,
    errorbars::Symbol,
    y_level,
    plot_idx::Int,
    facet_ctx::FacetContext,
    plot_spec::PlotPanelSpec,
    individual_data::Symbol,
)
    group_data = _group_emmeans_data(
        setup.emmeans_data,
        setup.effect_factors,
        setup.x_indices,
        setup.y_indices,
        y_level,
    )
    isempty(group_data) && return nothing

    # When no y_grouping, use simpler positioning
    if isnothing(y_level)
        x_plot_positions, means =
            _calculate_x_positions(group_data, setup.x_unique, 1, 1, 0.0)
    else
        spacing = _calculate_spacing(setup, plot_type)
        x_plot_positions, means = _calculate_x_positions(
            group_data,
            setup.x_unique,
            plot_idx,
            setup.n_dodge_groups,
            spacing,
        )
    end
    # Create main plot element with label (this will be the legend entry)
    label = !isnothing(y_level) ? string(y_level) : nothing

    if plot_type == :line
        line_kw = _prepare_plot_kwargs(setup.plot_kwargs, "line_", plot_idx, label)
        main_plot = lines!(setup.ax, x_plot_positions, means; line_kw...)

        # Scatter points: no label, but sync visibility with main plot
        scatter_kw = _prepare_plot_kwargs(setup.plot_kwargs, "line_", plot_idx, nothing)
        scatter_plot = scatter!(setup.ax, x_plot_positions, means; scatter_kw...)
        # Sync scatter visibility with line visibility
        _link_visibility!(main_plot, scatter_plot)
    else  # :bar
        bar_kw = _prepare_plot_kwargs(setup.plot_kwargs, "bar_", plot_idx, label)
        # Set width: use user-provided bar_width if available, otherwise use calculated bar_width
        # When no y_grouping, use the full dodge_width (or user-provided bar_width)
        if !haskey(bar_kw, :width)
            bar_kw[:width] = isnothing(y_level) ? setup.dodge_width : setup.bar_width
        end
        main_plot = barplot!(setup.ax, x_plot_positions, means; bar_kw...)
    end

    # Error bars: no label, but sync visibility with main plot
    if errorbars != :none
        distances = [_get_error_distance(g.row, errorbars) for g in group_data]
        _plot_errorbars!(
            setup.ax,
            x_plot_positions,
            means,
            distances,
            setup.plot_kwargs,
            errorbars;
            link_to = main_plot,
        )
    end

    # Points and connecting lines
    spacing = _calculate_spacing(setup, plot_type)
    subject_points = _handle_individual_data!(
        plot_spec,
        setup,
        main_plot,
        individual_data,
        facet_ctx,
        y_level,
        plot_idx,
        group_data;
        spacing = spacing,
    )
    return subject_points
end

function _plot_emmeans_based!(
    plot_spec::PlotPanelSpec,
    plot_type::Symbol,
    errorbars::Symbol,
    facet_ctx::FacetContext,
    individual_data::Symbol = :none,
)
    setup = _extract_plot_setup(plot_spec, facet_ctx.y_faceting, plot_type)

    # Use helper to iterate over y_levels (handles both !isnothing(y_unique) and isnothing(y_unique))
    _iterate_y_levels(
        setup.y_unique,
        facet_ctx.y_faceting,
        (y_level, idx, plot_idx) -> _plot_single_group!(
            setup,
            plot_type,
            errorbars,
            y_level,
            plot_idx,
            facet_ctx,
            plot_spec,
            individual_data,
        ),
    )
end
