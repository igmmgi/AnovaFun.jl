"""
Plot utility functions for AnovaFun plotting system.

This file contains generic helper functions used throughout the plotting code.
"""

# Generic function to extract all kwargs with a given prefix
# Strips the prefix from the keys (e.g., "violin_color" -> :color)
# Automatically filters out internal config keys that shouldn't be passed to Makie
function _extract_kwargs(plot_kwargs::Dict{Symbol,Any}, prefix::String)
    kw = Dict{Symbol,Any}()
    prefix_len = length(prefix)
    for (key, value) in plot_kwargs
        key_str = string(key)
        if startswith(key_str, prefix) && length(key_str) > prefix_len
            # Strip prefix and convert back to symbol
            stripped_key = Symbol(key_str[(prefix_len+1):end])
            # Skip internal config keys (these shouldn't be passed to Makie)
            if !(stripped_key in INTERNAL_CONFIG_KEYS) && !isnothing(value)
                kw[stripped_key] = value
            end
        end
    end
    return kw
end

function _extract_legend_kwargs(
    plot_kwargs::Dict{Symbol,Any};
    exclude_positioning::Bool = false,
)
    legend_kwargs = _extract_kwargs(plot_kwargs, "legend_")
    # Remove positioning attributes if requested (these are not direct legend kwargs)
    if exclude_positioning
        for attr in [:halign, :valign, :alignmode]
            pop!(legend_kwargs, attr, nothing)
        end
    end
    return legend_kwargs
end

# Helper to match factor levels in a row
_match_factor_level(row, factors, level) =
    isnothing(level) || isempty(factors) ? true :
    (
        length(factors) == 1 ? string(row[factors[1]]) == string(level) :
        join([string(row[f]) for f in factors], " × ") == string(level)
    )

# Reorder levels - dispatches based on order type
_reorder(levels, ::Nothing) = levels

function _reorder(levels, indices::AbstractVector{<:Integer})
    valid = [i for i in indices if 1 <= i <= length(levels)]
    return length(valid) == length(levels) ? levels[valid] : levels
end

function _reorder(levels, names::AbstractVector{<:Union{AbstractString,Symbol}})
    isempty(levels) && return levels
    # Convert name to match the type of levels (typically String)
    level_type = typeof(levels[1])
    order = Int[]
    for name in names
        name_converted = level_type === String ? string(name) : name
        idx = findfirst(x -> x == name_converted, levels)
        !isnothing(idx) && push!(order, idx)
    end
    # deal with cases of partial order 
    if length(order) < length(levels)
        for i = 1:length(levels)
            i ∉ order && push!(order, i)
        end
    end
    return levels[order]
end

"""
    _is_y_faceting(y_factors, col_factors, row_factors)

Check if y-grouping factors are being used for faceting (column or row facets).
Returns true if y_factors match either col_factors or row_factors exactly.

This is used to determine whether a legend is needed - when y-factors are used
for faceting, the facet labels already distinguish the groups, making a legend
redundant (unless explicitly requested via legend_when_faceting).
"""
function _is_y_faceting(y_factors, col_factors, row_factors)
    isempty(y_factors) && return false
    (!isempty(col_factors) && Set(y_factors) == Set(col_factors)) ||
        (!isempty(row_factors) && Set(y_factors) == Set(row_factors))
end

"""
    _calculate_spacing(setup, plot_type)

Calculate spacing between dodged groups for positioning.
Returns spacing value (0.0 if no dodging).
"""
function _calculate_spacing(setup, plot_type::Union{Symbol,Nothing} = nothing)
    if setup.n_dodge_groups <= 1
        return 0.0
    end

    # For bar plots, spacing comes from dodge_width
    # For other plots, bar_width already represents spacing
    if plot_type == :bar
        return setup.dodge_width / setup.n_dodge_groups
    else
        return setup.bar_width
    end
end

"""
    _prepare_plot_kwargs(plot_kwargs, prefix, plot_idx, label, color)

Extract kwargs with prefix, set color and label if provided.
Returns prepared kwargs dictionary ready for plotting.
"""
function _prepare_plot_kwargs(
    plot_kwargs::Dict{Symbol,Any},
    prefix::String,
    plot_idx::Int,
    label::Union{String,Nothing} = nothing,
    color = nothing,
)
    kw = _extract_kwargs(plot_kwargs, prefix)

    # Set label if provided
    if !isnothing(label)
        kw[:label] = label
    end

    # Set color if provided (use group color if color is nothing)
    if isnothing(color)
        color = _get_group_color(plot_kwargs, plot_idx)
    end
    if !isnothing(color)
        kw[:color] = color
    end

    return kw
end

"""
    _calculate_dodge_offset(plot_idx, n_dodge_groups, spacing)

Calculate x-offset for dodged groups.
Returns 0.0 if no dodging (n_dodge_groups <= 1).
"""
function _calculate_dodge_offset(plot_idx::Int, n_dodge_groups::Int, spacing::Float64)
    if n_dodge_groups <= 1
        return 0.0
    end
    return (plot_idx - (n_dodge_groups + 1) / 2) * spacing
end

"""
    _auto_calculate_dodge_width(plot_type, element_width, n_dodge_groups)

Auto-calculate dodge_width to ensure plot elements don't overlap.
Returns (dodge_width, bar_width) tuple.
For bar plots: bar_width stays as element_width.
For other plots: bar_width = dodge_width / n_dodge_groups (spacing).
"""
function _auto_calculate_dodge_width(
    plot_type::Symbol,
    element_width::Float64,
    n_dodge_groups::Int,
)
    dodge_width = max(element_width * n_dodge_groups, element_width)

    if plot_type == :bar
        # bar_width stays as actual bar width
        return (dodge_width, element_width)
    else
        # bar_width represents spacing between dodged elements
        bar_width = dodge_width / n_dodge_groups
        return (dodge_width, bar_width)
    end
end

# Normalize factor input to Vector{Symbol}
"""
    _to_factor_vector(factor)

Convert various factor input types to a standardized Vector{Symbol} format.
Handles Symbol, Vector{Symbol}, tuples, and other iterables.
"""
_to_factor_vector(factor::Symbol) = [factor]
_to_factor_vector(factor::Vector{Symbol}) = factor
_to_factor_vector(factor) = [Symbol(f) for f in factor]  # For tuples or other iterables
_to_factor_vector(::Nothing) = Symbol[]

"""
    _get_x_position(level, x_levels::Vector)

Get the numeric position index for a given level from the x_levels vector.
Returns the 1-based index where the level appears in x_levels.
"""
_get_x_position(level, x_levels::Vector) = findfirst(x -> x == level, x_levels)

"""
    _get_group_color(plot_kwargs::Dict{Symbol,Any}, plot_idx::Int)

Extract group color from theme palette at the specified plot index.
Uses modulo arithmetic to cycle through available colors.
Returns nothing if no theme or palette is available.
"""
function _get_group_color(plot_kwargs::Dict{Symbol,Any}, plot_idx::Int)
    theme = get(plot_kwargs, :_internal_theme, nothing)
    isnothing(theme) && return nothing

    palette = hasproperty(theme, :palette) ? theme.palette : nothing
    isnothing(palette) && return nothing
    !hasproperty(palette, :color) && return nothing

    color_value = palette.color
    color_array = color_value isa Makie.Observable ? color_value[] : color_value
    color_idx = ((plot_idx - 1) % length(color_array)) + 1
    return color_array[color_idx]
end

"""
    _iterate_y_levels(y_unique, y_faceting::Bool, f::Function)

Helper to iterate over y_levels with proper handling of both grouped and non-grouped cases.
Calls function f(y_level, idx, plot_idx) for each y-level.
Handles both !isnothing(y_unique) and isnothing(y_unique) cases.
"""
function _iterate_y_levels(y_unique, y_faceting::Bool, f::Function)
    if !isnothing(y_unique)
        for (idx, y_level) in enumerate(y_unique)
            plot_idx = y_faceting ? 1 : idx
            f(y_level, idx, plot_idx)
        end
    else
        f(nothing, 1, 1)
    end
end

"""
    _get_error_distance(row, errorbars::Symbol)

Extract error bar distance from a row, handling different property names.
Returns 0.0 if errorbars is :none or no error property is found.
"""
function _get_error_distance(row, errorbars::Symbol)
    if errorbars == :none
        return 0.0
    elseif hasproperty(row, :error)
        return row.error
    elseif hasproperty(row, :Distance)
        return row.Distance
    else
        return 0.0
    end
end

"""
    _apply_alpha_to_color(color, alpha)

Apply alpha transparency to a color, returning an RGBAf color.
Returns the original color if alpha >= 1.0 or color is nothing.
Handles any color type that Makie.to_color can convert.
"""
function _apply_alpha_to_color(color, alpha)
    if alpha < 1.0 && !isnothing(color)
        base_color = Makie.to_color(color)
        return Makie.RGBAf(base_color.r, base_color.g, base_color.b, Float32(alpha))
    end
    return color
end

"""
    _get_muted_color(color)

Create a muted (lighter) version of a color by mixing with white.
Uses 70% original color + 30% white.
"""
function _get_muted_color(color)
    base = Makie.to_color(color)
    return Makie.RGBAf(
        base.r * 0.7 + 0.3,
        base.g * 0.7 + 0.3,
        base.b * 0.7 + 0.3,
        base.alpha,
    )
end

"""
    _get_muted_group_color(plot_kwargs::Dict{Symbol,Any}, plot_idx::Int)

Get a muted version of the group color from theme palette.
Returns nothing if no theme or palette is available.
"""
function _get_muted_group_color(plot_kwargs::Dict{Symbol,Any}, plot_idx::Int)
    group_color = _get_group_color(plot_kwargs, plot_idx)
    isnothing(group_color) && return nothing
    return _get_muted_color(group_color)
end

"""
    _handle_distribution_alpha!(kw::Dict{Symbol,Any}, group_color, alpha_key::Symbol=:alpha)

Handle alpha/transparency for distribution plots (violin, boxplot, raincloud).
Modifies `kw` in place to set transparency and apply alpha to color.

- If alpha is a Bool: sets transparency mode
- If alpha is a Number: enables transparency and applies alpha to group_color
"""
function _handle_distribution_alpha!(
    kw::Dict{Symbol,Any},
    group_color,
    alpha_key::Symbol = :alpha,
)
    if haskey(kw, alpha_key)
        transparency_val = pop!(kw, alpha_key)
        if transparency_val isa Bool
            kw[:transparency] = transparency_val
        elseif transparency_val isa Number
            kw[:transparency] = true
            if !isnothing(group_color)
                kw[:color] = _apply_alpha_to_color(group_color, transparency_val)
            end
        end
    elseif !isnothing(group_color)
        # Set color from theme even when alpha is not provided
        kw[:color] = group_color
    end
end

"""
    _determine_individual_data_color!(kw::Dict{Symbol,Any}, plot_kwargs::Dict{Symbol,Any}, plot_idx::Int)

Determine and set color for individual data points/lines based on individual_data_color_mode.
Modifies `kw` in place by setting the :color key.
"""
function _determine_individual_data_color!(
    kw::Dict{Symbol,Any},
    plot_kwargs::Dict{Symbol,Any},
    plot_idx::Int,
)
    point_color_mode = plot_kwargs[:individual_data_color_mode]
    explicit_point_color = plot_kwargs[:individual_data_color]

    # If explicit color is provided, use it (overrides mode)
    if !isnothing(explicit_point_color)
        kw[:color] = explicit_point_color
    elseif point_color_mode == :match
        group_color = _get_group_color(plot_kwargs, plot_idx)
        !isnothing(group_color) && (kw[:color] = group_color)
    elseif point_color_mode == :muted
        muted_color = _get_muted_group_color(plot_kwargs, plot_idx)
        !isnothing(muted_color) && (kw[:color] = muted_color)
    end
    # If :fixed mode and no explicit color, let Makie handle it (will use next cycle color)
end

# Internal configuration keys that should be filtered out before passing to Makie
# These are AnovaFun-specific configuration parameters, not Makie plot attributes
# Include both prefixed versions (e.g., :raincloud_*) and stripped versions (e.g., :2x2_*)
# because some code paths strip the prefix before filtering
const INTERNAL_CONFIG_KEYS = [
    :raincloud_violin_width_mult,
    :raincloud_point_alpha,
    :raincloud_jitter_mult,
    :raincloud_boxplot_width_mult,
    :raincloud_violin_offset,
    :raincloud_box_offset,
    :raincloud_points_offset,
    :raincloud_2x2_violin_offset,
    :raincloud_2x2_box_offset,
    :raincloud_2x2_points_offset,
    :raincloud_2x2_box_dodge,
    :raincloud_2x2_points_dodge,
    # Stripped versions (without raincloud_ prefix)
    Symbol("2x2_violin_offset"),
    Symbol("2x2_box_offset"),
    Symbol("2x2_points_offset"),
    Symbol("2x2_box_dodge"),
    Symbol("2x2_points_dodge"),
    :raincloud_line_alpha,
    :raincloud_show_violin,
    :raincloud_show_boxplot,
    :raincloud_show_mean,
    # Stripped versions (after prefix extraction in _configure_distribution_plot_kwargs!)
    :violin_width_mult,
    :point_alpha,
    :jitter_mult,
    :boxplot_width_mult,
    :violin_offset,
    :box_offset,
    :points_offset,
    :pair_gap,
    :line_alpha,
    :show_violin,
    :show_boxplot,
    :show_mean,
    :jitter_dodged_mult,
    :jitter_single_width,
    :ylim_kde_std_multiplier,
    :ylim_whisker_iqr_multiplier,
    :ylim_padding,
    :layout_panel_width,
    :layout_panel_height,
    :layout_row_gap,
    :layout_row_gap_with_facets,
    :layout_col_gap,
    :layout_axis_label_padding,
    :dodge_width,
    :individual_data_color_mode,
    # Stripped version (after prefix extraction with "individual_data_")
    :color_mode,
]

"""
    _can_plot_individual_data(individual_data::Symbol, raw_data, id_col, dv)

Check if individual data (points or connected points) can be plotted.
Returns true if individual_data is :points or :connected_points and all required data is available.
"""
function _can_plot_individual_data(individual_data::Symbol, raw_data, id_col, dv)
    individual_data ∈ [:points, :connected_points] &&
        !isempty(raw_data) &&
        !isnothing(id_col) &&
        !isnothing(dv)
end


"""
Validation functions for plot_anova parameters.

This file contains functions to validate plot parameters before plotting.
"""

"""
    _validate_plot_parameters(plot_type, errorbars, individual_data)

Validate plot_type, errorbars, and individual_data parameters.
Throws ArgumentError if any parameter is invalid.
"""
function _validate_plot_parameters(
    plot_type::Symbol,
    errorbars::Symbol,
    individual_data::Symbol,
)
    allowed_plot_types = [
        :line,
        :bar,
        :violin,
        :boxplot,
        :raincloud,
        :raincloud_custom,
        :raincloud_custom_2x2,
    ]
    plot_type ∉ allowed_plot_types &&
        throw(ArgumentError("plot_type must be one of: $(allowed_plot_types)"))

    allowed_errorbars = [:none, :SD, :SE, :CI, :withinSE, :withinCI]
    errorbars ∉ allowed_errorbars &&
        throw(ArgumentError("errorbars must be one of: $(allowed_errorbars)"))

    allowed_individual_data = [:none, :points, :connected_points]
    individual_data ∉ allowed_individual_data &&
        throw(ArgumentError("individual_data must be one of: $(allowed_individual_data)"))
end
