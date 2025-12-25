"""
Violin plot implementation.

This file contains:
- `_plot_violin!`: Violin plot with optional individual data points
"""

function _plot_violin!(
    plot_spec::PlotPanelSpec,
    facet_ctx::FacetContext,
    individual_data::Symbol = :none,
)
    _plot_distribution_base!(
        plot_spec,
        facet_ctx,
        :violin,
        individual_data,
        (ax, x, y; kw...) -> violin!(ax, x, y; kw...),
    )
end
