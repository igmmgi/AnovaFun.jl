"""
Plot configuration constants and default theme for AnovaFun plotting system.

This file contains:
- _default_plot_theme(): Function creating the default Makie theme
- _VALID_*_ATTRS: Allowlists for forwarding kwargs to Makie constructors

Note: Default kwarg values are now defined in the typed structs in plot_kwargs_types.jl.
"""

# Valid Makie block attributes - used as allowlists when forwarding kwargs to constructors.
# Only attributes in these sets are passed through; custom AnovaFun keys (e.g. axis_xticklabels,
# axis_xlim) are automatically excluded without needing a manual blocklist.
const _VALID_AXIS_ATTRS = Set(propertynames(Makie.Axis))
const _VALID_FIGURE_ATTRS = Set(propertynames(Makie.Figure))
const _VALID_LEGEND_ATTRS = Set(propertynames(Makie.Legend))

"""
Create the default theme for AnovaFun plots.

This theme sets default styling for axis labels, tick labels, grids, and other visual elements.
Users can override this by passing a custom theme via the `theme` keyword argument.

Defaults:
- Font sizes: xlabelsize=22, ylabelsize=22, xticklabelsize=18, yticklabelsize=18
- Grids: xgridvisible=true, ygridvisible=true, xminorgridvisible=true, yminorgridvisible=true
- Colors: Uses Makie's Set1_4 colormap

To override, pass a theme like:
```julia
plot(..., theme = Theme(Axis = (xlabelsize = 30, ygridcolor = :red)))
```

For full documentation, see: https://docs.makie.org/stable/explanations/theming/
"""
function _default_plot_theme()
    return Theme(
        Axis = (
            xlabelsize = 22,
            ylabelsize = 22,
            xticklabelsize = 18,
            yticklabelsize = 18,
            xgridvisible = true,
            ygridvisible = true,
            xminorgridvisible = true,
            yminorgridvisible = true,
        ),
        palette = (
            color = Makie.to_colormap(:Set1_4),
            linewidth = [2.0],
            linestyle = [:solid],
            marker = [:circle],
            markersize = [20],
        ),
        Lines = (
            cycle = Cycle(
                [:color, :linewidth, :linestyle, :marker, :markersize],
                covary = true,
            ),
        ),
        Scatter = (cycle = Cycle([:color, :marker, :markersize], covary = true),),
    )
end
