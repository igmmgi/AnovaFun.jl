"""
Base implementation for distribution plots (violin, boxplot, raincloud).

This file contains a common base function that handles the shared logic
across all distribution plot types.
"""

"""
    _plot_distribution_base!(
        plot_spec::PlotPanelSpec,
        facet_ctx::FacetContext,
        plot_type::Symbol,
        individual_data::Symbol,
        plot_func::Function,
    )

Base implementation for distribution plots that handles common logic.
plot_func should be a function that creates the specific plot element (e.g., violin!, boxplot!, rainclouds!).
"""
function _plot_distribution_base!(
    plot_spec::PlotPanelSpec,
    facet_ctx::FacetContext,
    plot_type::Symbol,
    individual_data::Symbol,
    plot_func::Function,
)
    # Get plot setup (pass plot_type so boxplots can auto-calculate spacing)
    setup = _extract_plot_setup(plot_spec, facet_ctx.y_faceting, plot_type)

    # Define the plotting function for each y-level
    function plot_for_level(y_level, plot_idx::Int, label::Union{String,Nothing})
        # Collect distribution data
        dist_x, dist_y = _collect_distribution_data(
            setup,
            facet_ctx.col_factors,
            facet_ctx.row_factors,
            facet_ctx.col_levels,
            facet_ctx.row_levels,
            y_level,
            plot_idx;
            collect_subjects = false,
        )

        # Skip if no data
        isempty(dist_x) && return

        # Create plot kwargs
        plot_kw = Dict{Symbol,Any}()
        _configure_distribution_plot_kwargs!(
            plot_kw,
            plot_spec.plot_kwargs,
            string(plot_type) * "_",
            plot_idx,
            setup.bar_width,
            label,
        )

        # Create the main plot element
        main_plot = plot_func(setup.ax, dist_x, dist_y; plot_kw...)

        # Handle individual data if requested
        _handle_individual_data_for_distribution_plot!(
            plot_spec,
            setup,
            main_plot,
            individual_data,
            facet_ctx,
            y_level,
            plot_idx,
        )

        # Handle special visibility linking for boxplots
        if plot_type == :boxplot && hasproperty(main_plot, :show_median)
            _link_boxplot_median_visibility!(main_plot)
        end
    end

    # Iterate over y-levels and plot
    _iterate_distribution_y_levels(setup, facet_ctx.y_faceting, plot_for_level)
end

"""
    _link_boxplot_median_visibility!(boxplot)

Link boxplot median line visibility to the overall boxplot visibility.
"""
function _link_boxplot_median_visibility!(boxplot)
    # Store original show_median value
    original_show_median = boxplot.show_median[]
    on(boxplot.visible) do val
        if val
            boxplot.show_median[] = original_show_median
        else
            boxplot.show_median[] = false
        end
    end
end
