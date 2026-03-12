"""
Data preparation functions for plot_anova.

This file contains functions for:
- Filtering and preparing raw data
- Extracting factor levels from emmeans data
- Grouping and positioning data for plotting
"""


"""
    _apply_xorder!(x_unique, config)

Reorder `x_unique` in-place based on `config.axis.xorder`.
`xorder` should be a vector of level values in the desired display order.
"""
function _apply_xorder!(x_unique::Vector, config::PlotConfig)
    xorder = config.axis.xorder
    isnothing(xorder) && return

    order_strs = string.(xorder)
    existing_strs = string.(x_unique)

    # Validate all specified levels exist
    for level in order_strs
        if level ∉ existing_strs
            throw(ArgumentError(
                "axis_xorder contains unknown level \"$level\". " *
                "Available levels: $(existing_strs)"
            ))
        end
    end

    if length(order_strs) != length(existing_strs)
        throw(ArgumentError(
            "axis_xorder has $(length(order_strs)) levels but there are " *
            "$(length(existing_strs)) x categories. " *
            "Expected all of: $(existing_strs)"
        ))
    end

    # Reorder in-place
    new_order = [x_unique[findfirst(==(s), existing_strs)] for s in order_strs]
    copy!(x_unique, new_order)
end

# filter raw data to rows matching all specified factor levels
function _filter_raw_data(
    raw_data,
    x_factors,
    y_factors,
    col_factors,
    row_factors,
    x_level,
    y_level,
    col_level,
    row_level,
)
    x_level_str = string(x_level)
    filter(
        row -> begin
            x_match =
                length(x_factors) == 1 ? string(row[x_factors[1]]) == x_level_str :
                join([string(row[f]) for f in x_factors], " × ") == x_level_str
            x_match &&
                _match_factor_level(row, y_factors, y_level) &&
                _match_factor_level(row, col_factors, col_level) &&
                _match_factor_level(row, row_factors, row_level)
        end,
        raw_data,
    )
end

function _filter_by_facets(data, col_factors, row_factors, col_level, row_level)
    result = data
    !isnothing(col_level) &&
        (result = filter(row -> _match_factor_level(row, col_factors, col_level), result))
    !isnothing(row_level) &&
        (result = filter(row -> _match_factor_level(row, row_factors, row_level), result))
    return result
end


# extract unique levels for a set of factor indices 
function _extract_levels_for_effect(
    data::DataFrame,
    factor_indices,
    effect_factors::Vector{Symbol},
)
    isempty(factor_indices) && return nothing

    levels_list = [String[] for _ in factor_indices]
    for row in eachrow(data)
        level_parts = strip.(split(row.Level, ", "))
        if length(level_parts) >= length(effect_factors)
            for (i, idx) in enumerate(factor_indices)
                push!(levels_list[i], level_parts[idx])
            end
        end
    end

    unique_levels = [unique(levels_list[i]) for i = 1:length(factor_indices)]

    # For multiple factors, create combinations using Base.Iterators.product
    if length(factor_indices) == 1
        return unique_levels[1]
    else
        # Generate all combinations using Base.Iterators.product
        combinations = Vector{String}[]
        for combo in Base.Iterators.product(unique_levels...)
            push!(combinations, collect(combo))
        end
        return combinations
    end
end


"""
    _find_matching_effect(result, factors_needed)

Find the effect in emmeans result that matches the requested factors.
Returns the effect name and throws ArgumentError if no match or multiple matches.
"""
function _find_matching_effect(result::EmmeansResult, factors_needed::Vector{Symbol})
    needed_set = Set(factors_needed)

    # find effect name matches
    effect_names = filter(!=("Grand Mean"), unique(result.means.Effect))
    matching_effects = filter(effect_names) do name
        effect_factors = _parse_effect_name(name)
        Set(effect_factors) == needed_set
    end

    if isempty(matching_effects)
        throw(
            ArgumentError(
                "No effect found matching requested factors: $(join(string.(factors_needed), ", ")).\n" *
                "Available effects in emmeans result: $(join(effect_names, ", "))\n" *
                "Requested factors: $(factors_needed)",
            ),
        )
    elseif length(matching_effects) > 1
        throw(
            ArgumentError(
                "Multiple effects match requested factors $(join(string.(factors_needed), ", ")):\n" *
                "  $(join(matching_effects, "\n  "))\n" *
                "This should not occur. Please report this as a bug.",
            ),
        )
    end

    return matching_effects[1]
end

# Prepare plot data: find interaction, extract factors, levels, etc.
function _prepare_plot_data(
    result::EmmeansResult,
    x_grouping,
    y_grouping,
    facet_cols,
    facet_rows,
)

    # inputs to vectors of Symbols
    x_grouping = _to_factor_vector(x_grouping)
    y_grouping = _to_factor_vector(y_grouping)
    facet_cols = _to_factor_vector(facet_cols)
    facet_rows = _to_factor_vector(facet_rows)

    # factors needed
    factors_needed = vcat(x_grouping, y_grouping, facet_cols, facet_rows)

    # Find matching effect
    interaction_name = _find_matching_effect(result, factors_needed)
    interaction_data = filter(row -> row.Effect == interaction_name, result.means)

    # Get factor positions from the chosen effect
    effect_factors = _parse_effect_name(interaction_name)
    x_indices = [findfirst(==(f), effect_factors) for f in x_grouping]
    y_indices = [findfirst(==(f), effect_factors) for f in y_grouping]
    col_indices = [findfirst(==(f), effect_factors) for f in facet_cols]
    row_indices = [findfirst(==(f), effect_factors) for f in facet_rows]

    # Extract levels for x and y using the shared helper
    x_levels = _extract_levels_for_effect(interaction_data, x_indices, effect_factors)
    y_levels = _extract_levels_for_effect(interaction_data, y_indices, effect_factors)

    # Convert to string format
    _format_levels(levels::Vector{Vector{String}}) = [join(x, " × ") for x in levels]
    _format_levels(levels) = levels  # Returns input unchanged (handles nothing and other types)

    x_unique = _format_levels(x_levels)
    y_unique = _format_levels(y_levels)

    return (
        interaction_data = interaction_data,
        interaction_name = interaction_name,
        effect_factors = effect_factors,
        x_factors = x_grouping,
        y_factors = y_grouping,
        col_factors = facet_cols,
        row_factors = facet_rows,
        x_indices = x_indices,
        y_indices = y_indices,
        col_indices = col_indices,
        row_indices = row_indices,
        x_unique = x_unique,
        y_unique = y_unique,
        raw_data = result.anova.data,
        dv = result.anova.dv,
        id_col = result.anova.id,
    )
end


# Extract x and y level values from a parsed level string
function _extract_xy_levels(
    level_parts::Vector{SubString{String}},
    x_indices::Vector{Int},
    y_indices::Vector{Int},
)
    if length(level_parts) < max(
        isempty(x_indices) ? 0 : maximum(x_indices),
        isempty(y_indices) ? 0 : maximum(y_indices),
    )
        return nothing, nothing
    end

    x_val =
        length(x_indices) == 1 ? level_parts[x_indices[1]] :
        join([level_parts[i] for i in x_indices], " × ")

    y_val =
        isempty(y_indices) ? nothing :
        (
            length(y_indices) == 1 ? level_parts[y_indices[1]] :
            join([level_parts[i] for i in y_indices], " × ")
        )

    return x_val, y_val
end

"""
    _group_emmeans_data(emmeans_data, effect_factors, x_indices, y_indices, y_level_filter=nothing)

Group emmeans data rows by their x and y factor levels.

# Arguments
- `emmeans_data::DataFrame`: DataFrame containing emmeans results with a "Level" column.
- `effect_factors::Vector{Symbol}`: Vector of factor symbols in the effect.
- `x_indices::Vector{Int}`: Indices of x-axis factors within effect_factors.
- `y_indices::Vector{Int}`: Indices of y-grouping factors within effect_factors.
- `y_level_filter::Union{String,Nothing}`: Optional filter to select only rows matching this y-level.

# Returns
Vector of named tuples `(x_level, row)` where `row` is the original DataFrame row.
"""
function _group_emmeans_data(
    emmeans_data::DataFrame,
    effect_factors::Vector{Symbol},
    x_indices::Vector{Int},
    y_indices::Vector{Int},
    y_level_filter::Union{String,Nothing} = nothing,
)
    group_data = @NamedTuple{x_level::Any, row::DataFrameRow}[]
    for row in eachrow(emmeans_data)
        level_parts = strip.(split(row.Level, ", "))
        if length(level_parts) >= length(effect_factors)
            x_val, y_val = _extract_xy_levels(level_parts, x_indices, y_indices)
            if !isnothing(x_val)
                if isnothing(y_level_filter) || y_val == y_level_filter
                    push!(group_data, (x_level = x_val, row = row))
                end
            end
        end
    end
    return group_data
end


"""
    _calculate_x_positions(group_data, x_levels, plot_idx, n_dodge_groups, spacing)

Calculate x-axis plot positions for grouped data with optional dodge offset.

# Arguments
- `group_data::Vector`: Vector of named tuples with `x_level` field.
- `x_levels::Vector`: Ordered unique x-axis levels.
- `plot_idx::Int`: Index of current plot group (for dodge offset calculation).
- `n_dodge_groups::Int`: Total number of groups to dodge.
- `spacing::Float64`: Spacing between dodged groups (typically dodge_width / n_dodge_groups).

# Returns
Tuple of `(x_plot_positions, means)` where positions are Float64 vectors.
"""
function _calculate_x_positions(
    group_data::Vector,
    x_levels::Vector,
    plot_idx::Int,
    n_dodge_groups::Int,
    spacing::Float64,
)
    sort!(group_data, by = g -> _get_x_position(g.x_level, x_levels))
    x_numeric = [_get_x_position(g.x_level, x_levels) for g in group_data]

    x_offset = _calculate_dodge_offset(plot_idx, n_dodge_groups, spacing)
    x_plot_positions = Float64.(x_numeric) .+ x_offset

    return x_plot_positions, [g.row.Mean for g in group_data]
end

"""
    _extract_plot_setup(plot_spec, y_faceting, plot_type=nothing)

Extract common setup variables from a PlotPanelSpec for use in panel plotting functions.

# Arguments
- `plot_spec::PlotPanelSpec`: The plot panel specification containing all plot data.
- `y_faceting::Bool`: Whether y-grouping factors are used for faceting.
- `plot_type::Union{Symbol,Nothing}`: Optional plot type. If `:bar` or `:boxplot`, auto-calculates `dodge_width` to ensure plots don't overlap.

# Returns
NamedTuple containing: ax, emmeans_data, raw_data, x_factors, y_factors, effect_factors,
x_unique, y_unique, config, dv, id_col, x_indices, y_indices, n_dodge_groups,
dodge_width, bar_width.
"""
function _extract_plot_setup(
    plot_spec::PlotPanelSpec,
    y_faceting::Bool,
    plot_type::Union{Symbol,Nothing} = nothing,
)
    config = plot_spec.config

    # Get indices
    x_indices = [findfirst(==(f), plot_spec.effect_factors) for f in plot_spec.x_factors]
    y_indices =
        isempty(plot_spec.y_factors) ? Int[] :
        [findfirst(==(f), plot_spec.effect_factors) for f in plot_spec.y_factors]

    # Calculate dodge groups
    n_dodge_groups =
        y_faceting ? 1 : (!isnothing(plot_spec.y_levels) ? length(plot_spec.y_levels) : 1)

    # Auto-calculate dodge_width for bar and boxplot to ensure they don't overlap
    # For other plots, use dodge_width from config
    if plot_type == :bar
        element_width = config.bar.width
        dodge_width, bar_width =
            _auto_calculate_dodge_width(:bar, element_width, n_dodge_groups)
    elseif plot_type == :boxplot
        element_width = config.boxplot.width
        dodge_width, bar_width =
            _auto_calculate_dodge_width(:boxplot, element_width, n_dodge_groups)
    else
        dodge_width = config.dodge_width
        bar_width = dodge_width / n_dodge_groups
    end

    return (
        ax = plot_spec.ax,
        emmeans_data = plot_spec.emmeans_data,
        raw_data = plot_spec.raw_data,
        x_factors = plot_spec.x_factors,
        y_factors = plot_spec.y_factors,
        effect_factors = plot_spec.effect_factors,
        x_unique = plot_spec.x_levels,
        y_unique = plot_spec.y_levels,
        config = config,
        dv = plot_spec.dv,
        id_col = plot_spec.id_col,
        x_indices = x_indices,
        y_indices = y_indices,
        n_dodge_groups = n_dodge_groups,
        dodge_width = dodge_width,
        bar_width = bar_width,
    )
end
