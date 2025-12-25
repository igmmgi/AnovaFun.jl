"""
Unified component rendering for raincloud plots.

This file provides a single, reusable interface for rendering raincloud components
(violin, boxplot, points) that is shared across all raincloud variants.
"""

"""
Specification for rendering one side/group of a raincloud plot.
Bundles all parameters needed to render violin + boxplot + points.
"""
struct RaincloudComponentSpec
    ax::Axis
    y_data::Vector{Float64}
    positions::NamedTuple{(:violin_x, :box_x, :points_x),Tuple{Float64,Float64,Float64}}
    color::Any
    alpha::Float64
    violin_width::Float64
    side::Symbol                   # :left or :right (determines violin side and component order)
    individual_data::Symbol        # :none, :points, :connected_points
    label::Union{String,Nothing}   # Label for legend (applied to first visible component)
end

"""
    _render_raincloud_components!(spec::RaincloudComponentSpec, plot_kwargs, violin_kw, boxplot_kw)

Render raincloud components (violin, boxplot, points) for a single group.
Handles component ordering based on side (:left or :right) and visibility settings.

Returns (points_x::Vector{Float64}, points_y::Vector{Float64}, elements::Vector{Any}).
"""
function _render_raincloud_components!(
    spec::RaincloudComponentSpec,
    plot_kwargs::Dict{Symbol,Any},
    violin_kw::Dict{Symbol,Any},
    boxplot_kw::Dict{Symbol,Any},
)
    isempty(spec.y_data) && return (Float64[], Float64[], Any[])

    elements = Any[]
    points_x = Float64[]
    points_y = Float64[]

    # Get show/hide settings
    show_violin = get(plot_kwargs, :raincloud_show_violin, true)
    show_boxplot = get(plot_kwargs, :raincloud_show_boxplot, true)

    # Determine which component gets the label (first visible component)
    violin_label, boxplot_label = _assign_label(show_violin, show_boxplot, spec.label)

    # Determine violin side (matches component side)
    violin_side = spec.side

    # Component order: left = violin→box→points, right = points→box→violin
    order = COMPONENT_ORDER[spec.side]

    for component in order
        if component == :violin && show_violin
            violin_plot = _plot_raincloud_violin!(
                spec.ax,
                spec.positions.violin_x,
                spec.y_data,
                spec.color,
                spec.alpha,
                spec.violin_width,
                violin_side,
                violin_kw;
                label = violin_label,
            )
            !isnothing(violin_plot) && push!(elements, violin_plot)

        elseif component == :boxplot && show_boxplot
            box_width = spec.violin_width * plot_kwargs[:raincloud_boxplot_width_mult]
            box_plot = _plot_raincloud_boxplot!(
                spec.ax,
                spec.positions.box_x,
                spec.y_data,
                spec.color,
                box_width,
                boxplot_kw;
                label = boxplot_label,
            )
            !isnothing(box_plot) && push!(elements, box_plot)

        elseif component == :points && spec.individual_data ∈ [:points, :connected_points]
            jitter = _calculate_jitter(spec.violin_width, plot_kwargs)
            points_result = _plot_raincloud_points!(
                spec.ax,
                spec.positions.points_x,
                spec.y_data,
                spec.color,
                spec.alpha,
                jitter,
                plot_kwargs,
            )
            points_x, points_y = points_result[1], points_result[2]
            if length(points_result) >= 3 && !isnothing(points_result[3])
                push!(elements, points_result[3])
            end
        end
    end

    return (points_x, points_y, elements)
end
