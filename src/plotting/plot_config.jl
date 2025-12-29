"""
Plot configuration constants and default theme for AnovaFun plotting system.

This file contains:
- PLOT_KWARGS: Dictionary of all customizable plot parameters with defaults
- _default_plot_theme(): Function creating the default Makie theme
"""

const PLOT_KWARGS = Dict{Symbol,Tuple{Any,String}}(

    # Boxplot customization (for plot_type=:boxplot)
    :boxplot_color => (nothing, "Boxplot fill color (uses group color if nothing)"),
    :boxplot_strokecolor => (:grey, "Boxplot stroke color"),
    :boxplot_strokewidth => (1.0, "Boxplot stroke width"),
    :boxplot_show_median => (true, "Boxplot show median"),
    :boxplot_show_notch => (true, "Boxplot show notch"),
    :boxplot_width => (0.1, "Boxplot width"),
    :boxplot_alpha => (0.3, "Boxplot transparency (0.0-1.0)"),

    # Violin customization (for plot_type=:violin)
    :violin_color => (nothing, "Violin fill color (uses group color if nothing)"),
    :violin_strokecolor => (:grey, "Violin stroke color"),
    :violin_strokewidth => (1.0, "Violin stroke width"),
    :violin_width => (0.25, "Violin width"),
    :violin_alpha => (
        0.3,
        "Violin alpha/transparency: numeric (0.0-1.0) for alpha, or boolean for OIT",
    ),

    # Error bar customization
    :errorbar_color => (nothing, "Error bar color (uses group color if nothing)"),
    :errorbar_linewidth => (2, "Error bar line width"),
    :errorbar_whiskerwidth => (20, "Error bar whisker width"),

    # Individual data customization (for individual_data=:points or :connected_points)
    :individual_data_color => (
        nothing,
        "Individual data point color (overrides individual_data_color_mode if set)",
    ),
    :individual_data_color_mode => (
        :match,
        "How to color individual data points: :match (match group color), :fixed (use individual_data_color), or :muted (lighter version of group color)",
    ),
    :individual_data_markersize => (10, "Individual data point marker size"),
    :individual_data_alpha => (0.5, "Individual data point transparency (0.0-1.0)"),
    :individual_data_linewidth =>
        (1.0, "Individual data connecting line width (for :connected_points)"),
    :individual_data_line_alpha => (
        0.2,
        "Individual data connecting line transparency (0.0-1.0, for :connected_points)",
    ),

    # Raincloud customization (for plot_type=:raincloud)
    :raincloud_alpha => (0.3, "Raincloud alpha/transparency (applied to color alpha)"),
    :raincloud_show_median => (false, "Whether to show median in raincloud boxplots"),
    :raincloud_markersize => (10, "Raincloud point marker size"),
    :raincloud_violin_width_mult =>
        (0.3, "Raincloud violin width multiplier (relative to bar_width)"),
    :raincloud_point_alpha => (0.3, "Raincloud point transparency (0.0-1.0)"),
    :raincloud_jitter_mult =>
        (0.15, "Raincloud jitter multiplier (relative to violin width)"),
    :raincloud_boxplot_width_mult =>
        (0.3, "Raincloud boxplot width multiplier (relative to violin width)"),

    # Raincloud custom (paired) layout offsets
    :raincloud_violin_offset =>
        (0.15, "Distance from center to violin in raincloud_custom plots"),
    :raincloud_box_offset =>
        (0.2, "Distance from center to boxplot in raincloud_custom plots"),
    :raincloud_points_offset =>
        (0.075, "Distance from center to points in raincloud_custom plots"),

    # Raincloud custom_2x2 layout offsets (separate because 2x2 needs tighter spacing)
    :raincloud_2x2_violin_offset =>
        (0.075, "Distance from center to violin in raincloud_custom_2x2 plots"),
    :raincloud_2x2_box_offset =>
        (0.0, "Distance from center to boxplot in raincloud_custom_2x2 plots"),
    :raincloud_2x2_points_offset =>
        (0.3, "Distance from center to points in raincloud_custom_2x2 plots"),
    :raincloud_2x2_box_dodge => (
        0.035,
        "Dodge offset for boxplots in raincloud_custom_2x2 plots (separates the two groups' boxes)",
    ),
    :raincloud_2x2_points_dodge => (
        0.035,
        "Dodge offset for individual points and means in raincloud_custom_2x2 plots (separates the two groups' points)",
    ),

    # Raincloud visibility and styling
    :raincloud_line_alpha => (0.3, "Raincloud connecting line transparency (0.0-1.0)"),
    :raincloud_show_violin =>
        (true, "Show/hide violin (distribution) in custom raincloud plots"),
    :raincloud_show_boxplot => (true, "Show/hide boxplot in custom raincloud plots"),
    :raincloud_show_mean => (true, "Show/hide mean line in custom raincloud plots"),

    # Bar plot customization (for plot_type=:bar)
    :bar_width => (0.2, "Bar width"),
    :bar_alpha => (0.3, "Bar transparency (0.0-1.0)"),
    :bar_strokecolor => (:black, "Bar stroke color"),
    :bar_strokewidth => (2.0, "Bar stroke width"),

    # Group spacing/dodge customization (for non-bar plots)
    :dodge_width => (0, "Width dodging groups."),

    # Jitter customization
    :jitter_dodged_mult =>
        (0.6, "Jitter width multiplier for dodged groups (relative to bar_width)"),
    :jitter_single_width => (0.1, "Jitter width for single (non-dodged) groups"),

    # Y-axis limit calculation customization
    :ylim_kde_std_multiplier => (
        3.5,
        "Multiplier for standard deviation when estimating KDE extent for y-limits",
    ),
    :ylim_whisker_iqr_multiplier => (
        1.5,
        "Multiplier for IQR when calculating boxplot whisker positions for y-limits",
    ),
    :ylim_padding => (
        0.1,
        "Padding fraction added to y-axis limits (prevents data from touching edges)",
    ),

    # Layout and figure sizing customization
    :layout_panel_width => (800, "Default width of a single plot panel in pixels"),
    :layout_panel_height => (600, "Default height of a single plot panel in pixels"),
    :layout_row_gap => (10, "Gap between rows in faceted plots (when no row facets)"),
    :layout_row_gap_with_facets =>
        (50, "Gap between rows in faceted plots (when row facets present)"),
    :layout_col_gap => (10, "Gap between columns in faceted plots"),
    :layout_axis_label_padding => (
        (-10, 0, 0, 0),
        "Padding for axis labels (left, right, bottom, top) in pixels",
    ),

    # Axis customization 
    :axis_xlabel => (nothing, "X-axis label (auto if nothing)"),
    :axis_ylabel => ("Mean", "Y-axis label"),
    :axis_xlim => (
        nothing,
        "X-axis limits as (min, max) tuple. Note: For categorical x-axes (typical in ANOVA), this is rarely needed as limits are auto-calculated based on number of categories.",
    ),
    :axis_ylim => (
        nothing,
        "Y-axis limits as (min, max) tuple. Overrides automatic y-limit calculation.",
    ),
    # Add axis_ prefix for all Axis attributes
    [
        Symbol("axis_$(attr)") => (nothing, "Axis $(attr) parameter") for
        attr in propertynames(Makie.Axis)
    ]...,

    # Figure customization (common ones)
    :figure_size => (
        nothing,
        "Figure size as (width, height) tuple in pixels. If nothing, auto-calculated based on number of facets (800x600 per panel).",
    ),
    :theme => (
        nothing,
        "Makie theme to apply. If nothing, uses default theme (see `_default_plot_theme()`). Can be a predefined theme (e.g., :dark, :light) or a custom Theme object. User theme overrides default theme settings.",
    ),
    [
        Symbol("figure_$(attr)") => (nothing, "Figure $(attr) parameter") for
        attr in propertynames(Makie.Figure)
    ]...,

    # Legend customization
    :legend => (true, "Show legend (true/false)"),
    :legend_when_faceting =>
        (true, "Show legend even when y_grouping is used for faceting (true/false)"),

    # Add legend_ prefix for all Legend attributes
    :legend_title => (nothing, "Title for the legend (auto if nothing)"),
    :legend_position => (
        :rt,
        "Legend position (:lt, :rt, :lb, :rb, or tuple like (:left, :top), or (0.5, 0.5))",
    ),
    :legend_order => (
        nothing,
        "Order of legend entries. Can be a vector of level names (strings) or indices (integers) to specify the desired order. If nothing, uses the default order.",
    ),
    [
        Symbol("legend_$(attr)") => (nothing, "Legend $(attr) parameter") for
        attr in propertynames(Makie.Legend)
    ]...,
)

"""
Create the default theme for AnovaFun plots.

This theme sets default styling for axis labels, tick labels, grids, and other visual elements.
Users can override this by passing a custom theme via the `theme` keyword argument.

Defaults:
- Font sizes: xlabelsize=22, ylabelsize=22, xticklabelsize=18, yticklabelsize=18
- Grids: xgridvisible=true, ygridvisible=true, xminorgridvisible=true, yminorgridvisible=true
- Colors: Uses Makie's default colors

To override, pass a theme like:
```julia
plot(..., theme = Theme(Axis = (xlabelsize = 30, ygridcolor = :red)))
```

# What can be in a Theme?

Makie themes support styling properties, not functional parameters:

**Supported in themes:**
- `Axis`: All Axis styling properties (font sizes, colors, grid visibility/colors, etc.)
  - See all properties: `propertynames(Makie.Axis)` or `?Makie.Axis` in Julia REPL
  - Common ones: `xlabelsize`, `ylabelsize`, `xticklabelsize`, `yticklabelsize`, 
    `xgridvisible`, `ygridvisible`, `xgridcolor`, `ygridcolor`, etc.
- `Colors`: Plot element colors
- `Fonts`: Text styling

**NOT supported in themes (use kwargs instead):**
- `figure_size`: Pass as `figure_size = (800, 600)` kwarg (not in theme)
- `axis_xlabel`, `axis_ylabel`: Pass as kwargs (functional, not styling)
- `axis_xlim`, `axis_ylim`: Pass as kwargs (functional, not styling)

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
            # color = Makie.wong_colors(),  # Default color palette
            color = Makie.to_colormap(:Set1_4),  # Default color palette
            linewidth = [2.0],            # Default line width 
            linestyle = [:solid],         # Default line style 
            marker = [:circle],           # Default marker 
            markersize = [20],            # Default marker size 
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
