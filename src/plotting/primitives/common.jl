"""
    _configure_distribution_plot_kwargs!(kw::Dict{Symbol,Any}, plot_kwargs::Dict{Symbol,Any}, prefix::String, plot_idx::Int, width::Float64, label::Union{String,Nothing}=nothing)

Configure kwargs for distribution plots by extracting plot-specific parameters and handling color/alpha.
Modifies kw in place.
"""
function _configure_distribution_plot_kwargs!(
    kw::Dict{Symbol,Any},
    plot_kwargs::Dict{Symbol,Any},
    prefix::String,
    plot_idx::Int,
    width::Float64,
    label::Union{String,Nothing} = nothing,
)
    # Extract plot-specific kwargs (already filters internal config keys)
    plot_specific_kw = _extract_kwargs(plot_kwargs, prefix)
    merge!(kw, plot_specific_kw)

    # Set width if not already specified
    kw[:width] = get(kw, :width, width)

    # Set label if provided
    if !isnothing(label)
        kw[:label] = label
    end

    # Handle color and alpha
    group_color = _get_group_color(plot_kwargs, plot_idx)
    _handle_distribution_alpha!(kw, group_color)
end

"""
    _handle_individual_data!(
        plot_spec::PlotPanelSpec,
        setup,
        main_plot,
        individual_data::Symbol,
        facet_ctx,
        y_level,
        plot_idx::Int,
        group_data;
        spacing = nothing,
    )

Handle adding individual data points and connecting lines for any plot type.
Links their visibility to the main plot.

# Arguments
- `spacing`: Optional spacing override. If nothing, uses `setup.bar_width` (for distribution plots).
"""
function _handle_individual_data!(
    plot_spec::PlotPanelSpec,
    setup,
    main_plot,
    individual_data::Symbol,
    facet_ctx,
    y_level,
    plot_idx::Int,
    group_data;
    spacing = nothing,
)
    # Check if individual data should be added
    if !_can_plot_individual_data(
           individual_data,
           setup.raw_data,
           setup.id_col,
           setup.dv,
       ) ||
       isnothing(main_plot) ||
       isempty(group_data)
        return nothing
    end

    # Use provided spacing or default to bar_width (for distribution plots)
    spacing_to_use = isnothing(spacing) ? setup.bar_width : spacing

    # Add individual points
    subject_points, point_plot = _add_points!(
        plot_spec,
        facet_ctx.col_levels,
        facet_ctx.row_levels,
        facet_ctx.col_factors,
        facet_ctx.row_factors,
        group_data,
        setup.x_unique,
        setup.n_dodge_groups,
        spacing_to_use,
        plot_idx,
        y_level,
    )

    # Link point visibility to main plot
    if !isnothing(point_plot)
        _link_visibility!(main_plot, point_plot)
    end

    # Add connecting lines if requested
    if individual_data == :connected_points &&
       !isnothing(subject_points) &&
       !isempty(subject_points)
        line_plots = _add_connected_points!(plot_spec, subject_points, plot_idx)
        # Link all connecting line visibility to main plot
        for line_plot in line_plots
            _link_visibility!(main_plot, line_plot)
        end
    end

    return subject_points
end

"""
    _handle_individual_data_for_distribution_plot!(
        plot_spec::PlotPanelSpec,
        setup,
        main_plot,
        individual_data::Symbol,
        facet_ctx,
        y_level,
        plot_idx::Int,
    )

Handle adding individual data points and connecting lines for distribution plots.
Links their visibility to the main plot.
"""
function _handle_individual_data_for_distribution_plot!(
    plot_spec::PlotPanelSpec,
    setup,
    main_plot,
    individual_data::Symbol,
    facet_ctx,
    y_level,
    plot_idx::Int,
)
    # Get group data for positioning (with fallback for mixed designs)
    group_data = _get_group_data_with_fallback(
        setup.emmeans_data,
        setup.effect_factors,
        setup.x_indices,
        setup.y_indices,
        y_level,
    )

    _handle_individual_data!(
        plot_spec,
        setup,
        main_plot,
        individual_data,
        facet_ctx,
        y_level,
        plot_idx,
        group_data,
    )
end

"""
    _link_visibility!(source_plot, target_plot, properties::Vector{Symbol}=[:visible])

Link the visibility of target_plot to source_plot.
When source_plot visibility changes, target_plot properties follow.
Can link multiple properties (e.g., [:visible, :whisker_visible]).
"""
function _link_visibility!(
    source_plot,
    target_plot,
    properties::Vector{Symbol} = [:visible],
)
    for prop in properties
        if hasproperty(target_plot, prop)
            on(source_plot.visible) do val
                setproperty!(target_plot, prop, val)
            end
        end
    end
end

# Convenience method for single property (backward compatibility)
_link_visibility!(source_plot, target_plot, property::Symbol) =
    _link_visibility!(source_plot, target_plot, [property])

"""
    _link_errorbar_visibility!(main_plot, errorbar_plot)

Link errorbar visibility (including whiskers if present) to main plot visibility.
"""
function _link_errorbar_visibility!(main_plot, errorbar_plot)
    props =
        hasproperty(errorbar_plot, :whisker_visible) ? [:visible, :whisker_visible] :
        [:visible]
    _link_visibility!(main_plot, errorbar_plot, props)
end

"""
    _iterate_distribution_y_levels(setup, y_faceting, plot_func)

Iterate over y_levels for distribution plots, calling plot_func for each level.
Handles both grouped and non-grouped cases.
"""
function _iterate_distribution_y_levels(setup, y_faceting::Bool, plot_func::Function)
    if !isnothing(setup.y_unique)
        for (idx, y_level) in enumerate(setup.y_unique)
            plot_idx = y_faceting ? 1 : idx
            plot_func(y_level, plot_idx, string(y_level))
        end
    else
        # No y-grouping case
        plot_func(nothing, 1, nothing)
    end
end

"""
    _get_group_data_with_fallback(emmeans_data, effect_factors, x_indices, y_indices, y_level)

Get group data with fallback logic for mixed designs where y_level filtering might fail.
Returns group_data filtered by y_level, or if empty, attempts fallback by filtering all groups.
"""
function _get_group_data_with_fallback(
    emmeans_data,
    effect_factors,
    x_indices,
    y_indices,
    y_level,
)
    group_data =
        _group_emmeans_data(emmeans_data, effect_factors, x_indices, y_indices, y_level)

    # Fallback for mixed designs where y_level format might not match exactly
    if isempty(group_data) && !isnothing(y_level) && !isempty(emmeans_data)
        group_data_all =
            _group_emmeans_data(emmeans_data, effect_factors, x_indices, y_indices, nothing)
        if !isempty(group_data_all)
            group_data = []
            for g in group_data_all
                level_parts = strip.(split(g.row.Level, ", "))
                if length(level_parts) >= length(effect_factors)
                    _, y_val = _extract_xy_levels(level_parts, x_indices, y_indices)
                    if !isnothing(y_val) && y_val == string(y_level)
                        push!(group_data, g)
                    end
                end
            end
        end
    end

    return group_data
end

"""
    _plot_errorbars!(ax, x_positions, y_values, distances, plot_kwargs, errorbars; color=nothing, link_to=nothing)

Plot error bars with consistent styling and optional visibility linking.
Returns the errorbar plot (or nothing if errorbars == :none).
"""
function _plot_errorbars!(
    ax,
    x_positions::Union{Vector{Float64},Float64},
    y_values::Union{Vector{Float64},Float64},
    distances::Union{Vector{Float64},Float64},
    plot_kwargs,
    errorbars::Symbol;
    color = nothing,
    link_to = nothing,
)
    errorbars == :none && return nothing

    # Ensure vectors
    x_vec = x_positions isa Vector ? x_positions : [x_positions]
    y_vec = y_values isa Vector ? y_values : [y_values]
    dist_vec = distances isa Vector ? distances : [distances]

    # Extract errorbar kwargs
    errorbar_kw = _extract_kwargs(plot_kwargs, "errorbar_")
    if !isnothing(color)
        errorbar_kw[:color] = color
    end

    # Plot error bars (symmetrical: distances for both directions)
    errorbar_plot = errorbars!(ax, x_vec, y_vec, dist_vec, dist_vec; errorbar_kw...)

    # Link visibility if requested
    if !isnothing(link_to)
        _link_errorbar_visibility!(link_to, errorbar_plot)
    end

    return errorbar_plot
end

"""
    _filter_group_data_by_x_level(group_data, x_level)

Filter group data to only include entries matching the specified x_level.
"""
function _filter_group_data_by_x_level(group_data, x_level)
    x_level_str = string(x_level)
    return filter(g -> string(g.x_level) == x_level_str, group_data)
end

# Collect distribution data for violin/boxplot/raincloud plots
function _collect_distribution_data(
    setup,
    col_factors::Union{Nothing,Vector{Symbol}},
    row_factors::Union{Nothing,Vector{Symbol}},
    col_level,
    row_level,
    y_level,
    plot_idx::Int;
    collect_subjects::Bool = false,
)
    xs = Float64[]
    ys = Float64[]
    subjects = collect_subjects ? Any[] : nothing

    # Get group data (with fallback for mixed designs)
    group_data = _get_group_data_with_fallback(
        setup.emmeans_data,
        setup.effect_factors,
        setup.x_indices,
        setup.y_indices,
        y_level,
    )

    for g in group_data
        dist_data = _filter_raw_data(
            setup.raw_data,
            setup.x_factors,
            setup.y_factors,
            col_factors,
            row_factors,
            g.x_level,
            y_level,  # Still filter by y_level in raw data
            col_level,
            row_level,
        )
        isempty(dist_data) && continue

        x_pos = _get_x_position(g.x_level, setup.x_unique)
        x_offset = _calculate_dodge_offset(plot_idx, setup.n_dodge_groups, setup.bar_width)
        n = nrow(dist_data)
        x_val = x_pos + x_offset

        append!(xs, fill(x_val, n))
        append!(ys, collect(dist_data[!, setup.dv]))
        if collect_subjects
            append!(subjects, collect(dist_data[!, setup.id_col]))
        end
    end

    return collect_subjects ? (xs, ys, subjects) : (xs, ys)
end

# Collect distribution data filtered by x_level (for raincloud_custom when pairing x-levels)
function _collect_distribution_data_for_x_level(
    setup,
    col_factors::Union{Nothing,Vector{Symbol}},
    row_factors::Union{Nothing,Vector{Symbol}},
    col_level,
    row_level,
    x_level,
)
    xs = Float64[]
    ys = Float64[]

    # Get all group data (no y_level filter)
    group_data = _group_emmeans_data(
        setup.emmeans_data,
        setup.effect_factors,
        setup.x_indices,
        setup.y_indices,
        nothing,  # No y_level filter
    )

    # Filter to only the specified x_level
    group_data = _filter_group_data_by_x_level(group_data, x_level)

    for g in group_data
        dist_data = _filter_raw_data(
            setup.raw_data,
            setup.x_factors,
            setup.y_factors,
            col_factors,
            row_factors,
            g.x_level,
            nothing,  # No y_level filter
            col_level,
            row_level,
        )
        if isempty(dist_data)
            continue
        end

        x_pos = _get_x_position(g.x_level, setup.x_unique)
        if isnothing(x_pos)
            @minimal_warning "raincloud_custom: Could not find x_position for x_level='$(g.x_level)' in x_unique=$(setup.x_unique)"
            continue
        end
        # No dodge offset when using x-levels as pair
        x_val = Float64(x_pos)
        n = nrow(dist_data)

        append!(xs, fill(x_val, n))
        append!(ys, collect(dist_data[!, setup.dv]))
    end

    return (xs, ys)
end

# Add individual data points to a panel
function _add_points!(
    plot_spec::PlotPanelSpec,
    col_level,
    row_level,
    col_factors::Union{Nothing,Vector{Symbol}},
    row_factors::Union{Nothing,Vector{Symbol}},
    group_data::Vector,
    x_levels::Vector,
    n_dodge_groups::Int,
    bar_width::Float64,
    plot_idx::Int,
    y_level::Union{String,Nothing},
)
    ax = plot_spec.ax
    raw_data = plot_spec.raw_data
    x_factors = plot_spec.x_factors
    y_factors = plot_spec.y_factors
    plot_kwargs = plot_spec.plot_kwargs
    dv = plot_spec.dv
    id_col = plot_spec.id_col

    points_x = Float64[]
    points_y = Float64[]
    subject_points = Dict{Any,Vector{Tuple{Float64,Float64}}}()

    for g in group_data
        points_data = _filter_raw_data(
            raw_data,
            x_factors,
            y_factors,
            col_factors,
            row_factors,
            g.x_level,
            y_level,
            col_level,
            row_level,
        )

        if !isempty(points_data)
            x_pos = _get_x_position(g.x_level, x_levels)

            # Calculate dodge offset (returns 0.0 if no dodging)
            spacing = bar_width  # bar_width already represents spacing for distribution plots
            x_offset = _calculate_dodge_offset(plot_idx, n_dodge_groups, spacing)
            x_pos_base = x_pos + x_offset

            # When there's no y_grouping, aggregate to subject level to avoid duplicates
            # This ensures one point per subject per x-level
            if isnothing(y_level) && !isempty(points_data)
                # Group by subject and compute mean for each subject
                # This handles cases where raw data has multiple rows per subject per x-level
                # (e.g., when other factors vary but aren't part of the effect being plotted)
                grouped = groupby(points_data, id_col)
                points_data = combine(grouped, dv => mean => dv)
                # id_col is automatically preserved by combine when using groupby
            end

            # Collect all values for this x-level to compute smart positions
            x_values_for_level = Float64[]
            y_values_for_level = Float64[]
            subjects_for_level = Any[]

            for row in eachrow(points_data)
                push!(x_values_for_level, x_pos_base)
                push!(y_values_for_level, row[dv])
                push!(subjects_for_level, row[id_col])
            end

            # Use random jitter for :points
            # Always ensure some minimum jitter to prevent overlapping points
            calculated_jitter =
                n_dodge_groups > 1 ? bar_width * plot_kwargs[:jitter_dodged_mult] :
                plot_kwargs[:jitter_single_width]
            # Ensure minimum jitter of 0.05 to always have visible separation
            jitter_width = max(calculated_jitter, 0.05)
            x_finals = [x + (rand() - 0.5) * jitter_width for x in x_values_for_level]

            # Store points and subject info
            for (i, subject_id) in enumerate(subjects_for_level)
                x_final = x_finals[i]
                value = y_values_for_level[i]

                push!(points_x, x_final)
                push!(points_y, value)

                # Store for connecting lines
                if !haskey(subject_points, subject_id)
                    subject_points[subject_id] = []
                end
                push!(subject_points[subject_id], (x_final, value))
            end
        end
    end

    # Plot all points
    if !isempty(points_x)
        point_kw = _extract_kwargs(plot_spec.plot_kwargs, "individual_data_")
        # Remove label to prevent legend entry
        delete!(point_kw, :label)
        # Remove line-specific keys (these are for connecting lines, not points)
        delete!(point_kw, :linewidth)
        delete!(point_kw, :line_alpha)

        # Determine point color based on individual_data_color_mode
        _determine_individual_data_color!(point_kw, plot_spec.plot_kwargs, plot_idx)

        point_plot = scatter!(ax, points_x, points_y; point_kw...)
        return (subject_points, point_plot)
    end

    return (subject_points, nothing)
end

# Add connecting lines between individual data points
function _add_connected_points!(
    plot_spec::PlotPanelSpec,
    subject_points::Dict{Any,Vector{Tuple{Float64,Float64}}},
    plot_idx::Int,
)
    ax = plot_spec.ax
    plot_kwargs = plot_spec.plot_kwargs
    # Don't set color - let Makie handle it via theme cycle

    if !isempty(subject_points)
        connect_kw = _extract_kwargs(plot_kwargs, "individual_data_")
        # Remove label to prevent legend entry
        delete!(connect_kw, :label)
        # Remove point-specific keys (these are for points, not connecting lines)
        delete!(connect_kw, :markersize)
        delete!(connect_kw, :alpha)  # Remove point alpha, we'll use line_alpha instead

        # Map line_alpha (from individual_data_line_alpha) to alpha for Makie
        if haskey(connect_kw, :line_alpha)
            connect_kw[:alpha] = pop!(connect_kw, :line_alpha)
        end

        # Determine line color based on individual_data_color_mode (same as points)
        _determine_individual_data_color!(connect_kw, plot_kwargs, plot_idx)

        line_plots = []
        for (subject_id, coords) in subject_points
            if length(coords) > 1
                sort!(coords, by = c -> c[1])
                x_coords = [c[1] for c in coords]
                y_coords = [c[2] for c in coords]
                line_plot = lines!(ax, x_coords, y_coords; connect_kw...)
                push!(line_plots, line_plot)
            end
        end
        return line_plots
    end
    return []
end

# Add legend to an axis
function _add_legend(ax, y_unique, y_factors, plot_kwargs)

    # legend not requested or needed
    plot_kwargs[:legend] === false && return nothing
    (isnothing(y_unique) || length(y_unique) <= 1) && return nothing

    # Check if axis actually has any plots - can happen if data filtering results in empty datasets
    if isempty(ax.scene.plots)
        return nothing
    end

    # Check if any plots have labels - required for legend creation
    has_labeled_plots =
        any(p -> haskey(p.attributes, :label) && !isnothing(p.label[]), ax.scene.plots)
    if !has_labeled_plots
        return nothing
    end

    # Determine legend title (use provided or compute default)
    legend_title = plot_kwargs[:legend_title]
    if isnothing(legend_title)
        legend_title = join(string.(y_factors), " × ")
    end

    # Extract legend kwargs and add legend
    legend_kw = _extract_legend_kwargs(plot_kwargs, exclude_positioning = true)
    axislegend(ax, legend_title; legend_kw...)
end
