"""
Typed keyword argument structs for AnovaFun plotting system.

Replaces the flat `Dict{Symbol,Any}` approach with typed `@kwdef` structs
bundled in a `PlotConfig`. The user-facing API is unchanged — users still
pass flat kwargs like `violin_color=:red, axis_ylabel="My Y"`.

This file contains:
- `@kwdef` struct definitions for each kwarg group
- `PlotConfig` bundle struct
- `PlotConfig(; kwargs...)` constructor (splits flat kwargs by prefix)
- `to_dict(::PlotConfig)` for backward compatibility with internal Dict-based code
"""

# ============================================================================
# Kwarg group structs
# ============================================================================

"""Violin plot customization (prefix: `violin_`)."""
Base.@kwdef struct ViolinKwargs
    color::Any = nothing
    strokecolor::Any = :grey
    strokewidth::Float64 = 1.0
    datalimits::Any = extrema
    width::Float64 = 0.25
    alpha::Union{Float64,Bool} = 0.3
end

"""Boxplot customization (prefix: `boxplot_`)."""
Base.@kwdef struct BoxplotKwargs
    color::Any = nothing
    strokecolor::Any = :grey
    strokewidth::Float64 = 1.0
    show_median::Bool = true
    show_notch::Bool = true
    show_outliers::Bool = false
    width::Float64 = 0.1
    alpha::Float64 = 0.3
end

"""Error bar customization (prefix: `errorbar_`)."""
Base.@kwdef struct ErrorbarKwargs
    color::Any = nothing
    linewidth::Real = 2
    whiskerwidth::Real = 20
end

"""Individual data point/line customization (prefix: `individual_data_`)."""
Base.@kwdef struct IndividualDataKwargs
    color::Any = nothing
    color_mode::Symbol = :match
    markersize::Real = 10
    alpha::Float64 = 0.5
    linewidth::Float64 = 1.0
    line_alpha::Float64 = 0.2
end

"""Bar plot customization (prefix: `bar_`)."""
Base.@kwdef struct BarKwargs
    width::Float64 = 0.2
    alpha::Float64 = 0.3
    strokecolor::Any = :black
    strokewidth::Float64 = 2.0
end

"""
Raincloud plot customization (prefix: `raincloud_`).
Fields prefixed with `x2x2_` map to user kwargs `raincloud_2x2_*`.
"""
Base.@kwdef struct RaincloudKwargs
    alpha::Float64 = 0.3
    show_median::Bool = false
    markersize::Real = 10
    violin_width_mult::Float64 = 0.3
    point_alpha::Float64 = 0.3
    jitter_mult::Float64 = 0.15
    boxplot_width_mult::Float64 = 0.3
    # Custom layout offsets
    violin_offset::Float64 = 0.15
    box_offset::Float64 = 0.2
    points_offset::Float64 = 0.075
    # 2x2 layout offsets (user kwarg prefix: raincloud_2x2_*)
    x2x2_violin_offset::Float64 = 0.075
    x2x2_box_offset::Float64 = 0.0
    x2x2_points_offset::Float64 = 0.3
    x2x2_box_dodge::Float64 = 0.035
    x2x2_points_dodge::Float64 = 0.035
    # Visibility and styling
    line_alpha::Float64 = 0.3
    show_violin::Bool = true
    show_boxplot::Bool = true
    show_mean::Bool = true
end

"""Layout and figure sizing (prefix: `layout_`)."""
Base.@kwdef struct LayoutKwargs
    panel_width::Int = 800
    panel_height::Int = 600
    row_gap::Int = 10
    row_gap_with_facets::Int = 50
    col_gap::Int = 10
    axis_label_padding::NTuple{4,Int} = (-10, 0, 0, 0)
end

"""Jitter customization (prefix: `jitter_`)."""
Base.@kwdef struct JitterKwargs
    dodged_mult::Float64 = 0.6
    single_width::Float64 = 0.1
end

"""Y-axis limit calculation (prefix: `ylim_`)."""
Base.@kwdef struct YLimKwargs
    kde_std_multiplier::Float64 = 3.5
    whisker_iqr_multiplier::Float64 = 1.5
    padding::Float64 = 0.1
end

"""
Axis customization (prefix: `axis_`).
Known custom fields are struct fields; all other `axis_*` kwargs go to `makie_attrs`
and are forwarded directly to `Makie.Axis()`.
"""
Base.@kwdef struct AxisKwargs
    xticklabels::Any = nothing
    xlabel::Any = nothing
    ylabel::Any = "Mean"
    xlim::Any = nothing
    ylim::Any = nothing
    title::Any = nothing
    makie_attrs::Dict{Symbol,Any} = Dict{Symbol,Any}()
end

"""
Figure customization (prefix: `figure_`).
Known custom fields are struct fields; all other `figure_*` kwargs go to `makie_attrs`.
"""
Base.@kwdef struct FigureKwargs
    size::Any = nothing
    makie_attrs::Dict{Symbol,Any} = Dict{Symbol,Any}()
end

"""
Legend customization (prefix: `legend_`).
Known custom fields are struct fields; all other `legend_*` kwargs go to `makie_attrs`.
The top-level `legend=false` kwarg maps to `show=false`.
"""
Base.@kwdef struct LegendKwargs
    show::Bool = true
    when_faceting::Bool = true
    title::Any = nothing
    position::Any = :rt
    order::Any = nothing
    makie_attrs::Dict{Symbol,Any} = Dict{Symbol,Any}()
end

# ============================================================================
# PlotConfig bundle
# ============================================================================

"""
    PlotConfig

Bundle of all typed kwarg structs for the AnovaFun plotting system.
Construct from flat kwargs via `PlotConfig(; violin_color=:red, axis_ylabel="Y", ...)`.
"""
mutable struct PlotConfig
    violin::ViolinKwargs
    boxplot::BoxplotKwargs
    errorbar::ErrorbarKwargs
    individual_data::IndividualDataKwargs
    bar::BarKwargs
    raincloud::RaincloudKwargs
    layout::LayoutKwargs
    jitter::JitterKwargs
    ylim::YLimKwargs
    axis::AxisKwargs
    figure::FigureKwargs
    legend::LegendKwargs
    dodge_width::Float64
    theme::Any
    _resolved_theme::Any  # Set after merging user theme with defaults
end

# ============================================================================
# Prefix routing table
# ============================================================================

# Order matters: longer/more-specific prefixes MUST come first.
const _PREFIX_TABLE = [
    ("individual_data_", :individual_data),
    ("raincloud_2x2_",   :raincloud_2x2),   # before "raincloud_"
    ("raincloud_",       :raincloud),
    ("boxplot_",         :boxplot),
    ("errorbar_",        :errorbar),
    ("violin_",          :violin),
    ("layout_",          :layout),
    ("figure_",          :figure),
    ("legend_",          :legend),
    ("jitter_",          :jitter),
    ("axis_",            :axis),
    ("ylim_",            :ylim),
    ("bar_",             :bar),
]

# Top-level (unprefixed) kwargs
const _TOPLEVEL_KWARGS = Set([:dodge_width, :theme, :title, :legend])

# ============================================================================
# Helper: split known struct fields from Makie passthrough
# ============================================================================

function _split_known_and_makie(d::Dict{Symbol,Any}, T::Type)
    known_fields = Set(fieldnames(T))
    delete!(known_fields, :makie_attrs)
    known = Dict{Symbol,Any}()
    makie = Dict{Symbol,Any}()
    for (k, v) in d
        if k ∈ known_fields
            known[k] = v
        else
            makie[k] = v
        end
    end
    return known, makie
end

# ============================================================================
# PlotConfig constructor from flat kwargs
# ============================================================================

"""
    PlotConfig(; kwargs...)

Construct a `PlotConfig` from flat keyword arguments.
Kwargs are routed to the appropriate struct by prefix (e.g., `violin_color` → `ViolinKwargs.color`).

Throws `ArgumentError` for unrecognized kwargs (catches typos like `violin_colr`).
"""
function PlotConfig(; kwargs...)
    # Collectors for each prefix group
    collectors = Dict{Symbol,Dict{Symbol,Any}}(
        :violin          => Dict{Symbol,Any}(),
        :boxplot         => Dict{Symbol,Any}(),
        :errorbar        => Dict{Symbol,Any}(),
        :individual_data => Dict{Symbol,Any}(),
        :bar             => Dict{Symbol,Any}(),
        :raincloud       => Dict{Symbol,Any}(),
        :layout          => Dict{Symbol,Any}(),
        :jitter          => Dict{Symbol,Any}(),
        :ylim            => Dict{Symbol,Any}(),
        :axis            => Dict{Symbol,Any}(),
        :figure          => Dict{Symbol,Any}(),
        :legend          => Dict{Symbol,Any}(),
    )

    # Top-level values
    dodge_width = 0.0
    theme_val = nothing
    title_val = nothing
    has_title = false
    legend_val = nothing
    has_legend_toplevel = false

    for (key, value) in kwargs
        key_str = string(key)
        matched = false

        # Check prefixes (order matters — longer first)
        for (prefix, target) in _PREFIX_TABLE
            if startswith(key_str, prefix)
                stripped = Symbol(key_str[length(prefix)+1:end])
                if target == :raincloud_2x2
                    # Map raincloud_2x2_X → struct field x2x2_X
                    collectors[:raincloud][Symbol("x2x2_" * string(stripped))] = value
                else
                    collectors[target][stripped] = value
                end
                matched = true
                break
            end
        end

        if !matched
            if key == :dodge_width
                dodge_width = Float64(value)
            elseif key == :theme
                theme_val = value
            elseif key == :title
                has_title = true
                title_val = value
            elseif key == :legend
                has_legend_toplevel = true
                legend_val = value
            else
                throw(ArgumentError(
                    "Unknown keyword argument: `$key`. " *
                    "See `?PlotConfig` for available options."
                ))
            end
        end
    end

    # Handle `title` → axis.title alias (don't override explicit axis_title)
    if has_title && !haskey(collectors[:axis], :title)
        collectors[:axis][:title] = title_val
    end

    # Handle `legend = false` → legend.show = false (don't override explicit legend_show)
    if has_legend_toplevel
        if !haskey(collectors[:legend], :show)
            collectors[:legend][:show] = legend_val
        end
    end

    # For axis/figure/legend: split known struct fields from Makie passthrough
    axis_known, axis_makie = _split_known_and_makie(collectors[:axis], AxisKwargs)
    axis_known[:makie_attrs] = axis_makie

    figure_known, figure_makie = _split_known_and_makie(collectors[:figure], FigureKwargs)
    figure_known[:makie_attrs] = figure_makie

    legend_known, legend_makie = _split_known_and_makie(collectors[:legend], LegendKwargs)
    legend_known[:makie_attrs] = legend_makie

    # Construct all structs, catching MethodError from invalid field names
    # and converting to ArgumentError for a consistent user experience.
    try
        return PlotConfig(
            ViolinKwargs(; collectors[:violin]...),
            BoxplotKwargs(; collectors[:boxplot]...),
            ErrorbarKwargs(; collectors[:errorbar]...),
            IndividualDataKwargs(; collectors[:individual_data]...),
            BarKwargs(; collectors[:bar]...),
            RaincloudKwargs(; collectors[:raincloud]...),
            LayoutKwargs(; collectors[:layout]...),
            JitterKwargs(; collectors[:jitter]...),
            YLimKwargs(; collectors[:ylim]...),
            AxisKwargs(; axis_known...),
            FigureKwargs(; figure_known...),
            LegendKwargs(; legend_known...),
            dodge_width,
            theme_val,
            nothing,  # _resolved_theme (set later)
        )
    catch e
        if e isa MethodError
            msg = sprint(showerror, e)
            # Extract just the first line for a cleaner message
            first_line = first(split(msg, '\n'))
            throw(ArgumentError(
                "Invalid keyword argument in plot configuration: $first_line. " *
                "See `?PlotConfig` for available options."
            ))
        else
            rethrow(e)
        end
    end
end

# ============================================================================
# to_fields_dict: Convert struct to Dict for Makie splatting
# ============================================================================

"""
    to_fields_dict(obj; exclude=Set{Symbol}())

Convert any kwarg struct to a `Dict{Symbol,Any}` for splatting into Makie calls.
Skips `nothing` values and the `makie_attrs` field. Use `exclude` to skip specific fields.
"""
function to_fields_dict(obj; exclude::Set{Symbol}=Set{Symbol}())
    d = Dict{Symbol,Any}()
    for field in fieldnames(typeof(obj))
        field ∈ exclude && continue
        field == :makie_attrs && continue
        val = getfield(obj, field)
        !isnothing(val) && (d[field] = val)
    end
    return d
end

"""
    to_makie_dict(a::AxisKwargs)

Convert AxisKwargs to a Dict containing only valid Makie.Axis attributes.
Custom fields (xticklabels, xlim, ylim) are excluded — they're handled separately.
"""
function to_makie_dict(a::AxisKwargs)
    d = copy(a.makie_attrs)
    !isnothing(a.xlabel) && (d[:xlabel] = a.xlabel)
    !isnothing(a.ylabel) && (d[:ylabel] = a.ylabel)
    !isnothing(a.title) && (d[:title] = a.title)
    return d
end

"""
    to_makie_dict(f::FigureKwargs)

Convert FigureKwargs to a Dict containing only valid Makie.Figure attributes.
"""
function to_makie_dict(f::FigureKwargs)
    d = copy(f.makie_attrs)
    !isnothing(f.size) && (d[:size] = f.size)
    return d
end

"""
    to_makie_dict(l::LegendKwargs; exclude_positioning=false)

Convert LegendKwargs to a Dict containing valid Makie.Legend attributes.
"""
function to_makie_dict(l::LegendKwargs; exclude_positioning::Bool=false)
    d = copy(l.makie_attrs)
    !isnothing(l.position) && (d[:position] = l.position)
    if exclude_positioning
        for attr in [:halign, :valign, :alignmode]
            pop!(d, attr, nothing)
        end
    end
    return d
end

# ============================================================================
# to_dict: Convert PlotConfig back to flat Dict{Symbol,Any}
# ============================================================================

"""
    to_dict(config::PlotConfig) → Dict{Symbol,Any}

Convert a `PlotConfig` back to the flat `Dict{Symbol,Any}` format expected by
internal plotting code. Used for backward compatibility during migration.
"""
function to_dict(config::PlotConfig)
    d = Dict{Symbol,Any}()

    # Simple prefixed structs
    _flatten!(d, config.violin, "violin_")
    _flatten!(d, config.boxplot, "boxplot_")
    _flatten!(d, config.errorbar, "errorbar_")
    _flatten!(d, config.individual_data, "individual_data_")
    _flatten!(d, config.bar, "bar_")
    _flatten!(d, config.layout, "layout_")
    _flatten!(d, config.jitter, "jitter_")
    _flatten!(d, config.ylim, "ylim_")

    # Raincloud: x2x2_ fields → raincloud_2x2_ keys
    _flatten_raincloud!(d, config.raincloud)

    # Makie-passthrough structs (axis, figure, legend)
    _flatten_with_makie!(d, config.axis, "axis_")
    _flatten_with_makie!(d, config.figure, "figure_")
    _flatten_with_makie!(d, config.legend, "legend_")

    # Top-level / standalone
    d[:dodge_width] = config.dodge_width
    d[:theme] = config.theme
    d[:title] = config.axis.title      # convenience alias
    d[:legend] = config.legend.show     # convenience alias
    d[:figure_size] = config.figure.size  # convenience alias (also in figure_size from prefix)

    return d
end

# --- Flatten helpers ---

function _flatten!(d::Dict{Symbol,Any}, obj, prefix::String)
    for field in fieldnames(typeof(obj))
        d[Symbol(prefix * string(field))] = getfield(obj, field)
    end
end

function _flatten_raincloud!(d::Dict{Symbol,Any}, rc::RaincloudKwargs)
    for field in fieldnames(RaincloudKwargs)
        val = getfield(rc, field)
        key_str = string(field)
        if startswith(key_str, "x2x2_")
            # x2x2_violin_offset → raincloud_2x2_violin_offset
            d[Symbol("raincloud_2x2_" * key_str[6:end])] = val
        else
            d[Symbol("raincloud_" * key_str)] = val
        end
    end
end

function _flatten_with_makie!(d::Dict{Symbol,Any}, obj, prefix::String)
    for field in fieldnames(typeof(obj))
        if field == :makie_attrs
            for (k, v) in getfield(obj, field)
                d[Symbol(prefix * string(k))] = v
            end
        else
            d[Symbol(prefix * string(field))] = getfield(obj, field)
        end
    end
end
