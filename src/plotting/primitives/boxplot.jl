"""
Boxplot implementation.

This file contains:
- `_plot_boxplot!`: Boxplot with optional individual data points
"""

function _plot_boxplot!(
    plot_spec::PlotPanelSpec,
    facet_ctx::FacetContext,
    individual_data::Symbol = :none,
)
    _plot_distribution_base!(
        plot_spec,
        facet_ctx,
        :boxplot,
        individual_data,
        (ax, x, y; kw...) -> boxplot!(ax, x, y; kw...),
    )
end
