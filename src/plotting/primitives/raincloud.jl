"""
Raincloud plot implementations.

This file contains:
- `_plot_raincloud!`: Standard raincloud using Makie built-in
- `_plot_raincloud_custom!`: Custom paired raincloud (2 levels)
- `_plot_raincloud_custom_2x2!`: Custom 2x2 raincloud plot
"""

"""
    _calculate_jitter(violin_width, plot_kwargs)

Calculate jitter width for raincloud points, ensuring minimum jitter of 0.05.
"""
function _calculate_jitter(violin_width, plot_kwargs)
    jitter = violin_width * plot_kwargs[:raincloud_jitter_mult]
    return max(jitter, 0.05)  # Ensure minimum jitter to prevent overplotting
end

# Component order for raincloud plots based on side
const COMPONENT_ORDER =
    Dict(:left => [:violin, :boxplot, :points], :right => [:points, :boxplot, :violin])

"""
    _assign_label(show_violin, show_boxplot, label)

Assign label to the first visible component (violin > boxplot priority).
Returns (violin_label, boxplot_label) tuple.
"""
function _assign_label(show_violin, show_boxplot, label)
    violin_label = show_violin ? label : nothing
    boxplot_label = (!show_violin && show_boxplot) ? label : nothing
    return (violin_label, boxplot_label)
end

"""
    _extract_and_apply_alpha!(kw_dict, color, default_alpha)

Extract alpha from kwargs dictionary and apply it to color.
Returns the extracted alpha value (or default if not found).
Modifies kw_dict in place by removing :alpha and setting :color and :transparency.
"""
function _extract_and_apply_alpha!(kw_dict, color, default_alpha = 0.3)
    point_alpha = default_alpha
    if haskey(kw_dict, :alpha)
        alpha = pop!(kw_dict, :alpha)
        point_alpha = alpha isa Number ? Float32(alpha) : default_alpha
        if alpha isa Number && !isnothing(color)
            kw_dict[:color] = _apply_alpha_to_color(color, Float32(alpha))
            kw_dict[:transparency] = true
        end
    elseif !isnothing(color)
        kw_dict[:color] = color
    end
    return point_alpha
end

"""
    _build_subject_point_map(subject_data, points_x, points_y, id_col, dv)

Build a dictionary mapping subject IDs to their point coordinates.
Finds the closest matching point in points_y for each subject's y value.
"""
function _build_subject_point_map(subject_data, points_x, points_y, id_col, dv)
    map = Dict{Any,Tuple{Float64,Float64}}()
    if !isempty(subject_data) && !isempty(points_y) && length(points_x) == length(points_y)
        for row in eachrow(subject_data)
            subject_id = row[id_col]
            y_val = row[dv]
            closest_idx = argmin([abs(y - y_val) for y in points_y])
            map[subject_id] = (points_x[closest_idx], points_y[closest_idx])
        end
    end
    return map
end

"""
    _plot_raincloud_violin!(ax, x_pos, y_data, color, alpha, width, side, base_kwargs)

Plot a violin plot component for raincloud plots.
"""
function _plot_raincloud_violin!(
    ax,
    x_pos,
    y_data,
    color,
    alpha,
    width,
    side,
    base_kwargs;
    label = nothing,
)
    isempty(y_data) && return nothing
    violin_x = fill(x_pos, length(y_data))
    violin_kw = copy(base_kwargs)
    violin_kw[:width] = width
    violin_kw[:side] = side
    if !haskey(violin_kw, :color) && !isnothing(color)
        violin_kw[:color] = _apply_alpha_to_color(color, alpha)
    end
    if alpha < 1.0
        violin_kw[:transparency] = true
    end
    if !isnothing(label)
        violin_kw[:label] = label
    end
    return violin!(ax, violin_x, y_data; violin_kw...)
end

"""
    _plot_raincloud_boxplot!(ax, x_pos, y_data, color, width, base_kwargs)

Plot a boxplot component for raincloud plots.
"""
function _plot_raincloud_boxplot!(
    ax,
    x_pos,
    y_data,
    color,
    width,
    base_kwargs;
    label = nothing,
)
    isempty(y_data) && return nothing
    box_x = fill(x_pos, length(y_data))
    box_kw = copy(base_kwargs)
    box_kw[:width] = width
    if !isnothing(color)
        box_kw[:color] = color
    end
    if !isnothing(label)
        box_kw[:label] = label
    end
    return boxplot!(ax, box_x, y_data; box_kw...)
end

"""
    _plot_raincloud_points!(ax, x_pos, y_data, color, alpha, jitter_width, plot_kwargs, markersize)

Plot individual data points for raincloud plots with jitter.
Returns (points_x, points_y, scatter_plot) tuple.
"""
function _plot_raincloud_points!(
    ax,
    x_pos,
    y_data,
    color,
    alpha,
    jitter_width,
    plot_kwargs,
    markersize = plot_kwargs[:raincloud_markersize],
)
    isempty(y_data) && return (Float64[], Float64[], nothing)
    points_x = Float64[]
    points_y = Float64[]
    for y_val in y_data
        point_x = x_pos + (rand() - 0.5) * jitter_width
        push!(points_x, point_x)
        push!(points_y, y_val)
    end
    point_color = !isnothing(color) ? color : :black
    point_color = _apply_alpha_to_color(point_color, alpha)
    scatter_plot =
        scatter!(ax, points_x, points_y; color = point_color, markersize = markersize)
    return (points_x, points_y, scatter_plot)
end

"""
    _plot_raincloud_side!(ax, y_data, positions, color, alpha, violin_width, violin_kw, boxplot_kw, individual_data, side, plot_kwargs)

Plot one side (left or right) of a raincloud plot with all components.
Returns named tuple with point coordinates and plot elements for visibility syncing.

NOTE: This is a compatibility wrapper that delegates to _render_raincloud_components!
"""
function _plot_raincloud_side!(
    ax,
    y_data,
    positions,
    color,
    alpha,
    violin_width,
    violin_kw,
    boxplot_kw,
    individual_data,
    side,
    plot_kwargs;
    label = nothing,
)
    spec = RaincloudComponentSpec(
        ax,
        y_data isa Vector{Float64} ? y_data : collect(Float64, y_data),
        positions,
        color,
        Float64(alpha),
        Float64(violin_width),
        side,
        individual_data,
        label,
    )

    points_x, points_y, elements =
        _render_raincloud_components!(spec, plot_kwargs, violin_kw, boxplot_kw)
    return (points_x = points_x, points_y = points_y, elements = elements)
end

"""
    _plot_raincloud_errorbars!(ax, left_x, right_x, left_group_data, right_group_data, left_color, right_color, plot_kwargs, errorbars)

Plot error bars for left and right sides independently.
"""
function _plot_raincloud_errorbars!(
    ax,
    left_x,
    right_x,
    left_group_data,
    right_group_data,
    left_color,
    right_color,
    plot_kwargs,
    errorbars,
)
    if errorbars == :none
        return nothing
    end

    # Plot left error bar
    if !isempty(left_group_data)
        left_mean = left_group_data[1].row.Mean
        left_distance = _get_error_distance(left_group_data[1].row, errorbars)
        _plot_errorbars!(
            ax,
            left_x,
            left_mean,
            left_distance,
            plot_kwargs,
            errorbars;
            color = left_color,
        )
    end

    # Plot right error bar
    if !isempty(right_group_data)
        right_mean = right_group_data[1].row.Mean
        right_distance = _get_error_distance(right_group_data[1].row, errorbars)
        _plot_errorbars!(
            ax,
            right_x,
            right_mean,
            right_distance,
            plot_kwargs,
            errorbars;
            color = right_color,
        )
    end

    return nothing
end

"""
    _plot_connecting_lines!(ax, map_1, map_2, plot_kwargs; color=:gray, linewidth=1)

Plot connecting lines between matching subjects in two point maps.
Each map should be Dict{Any, Tuple{Float64, Float64}} mapping subject IDs to (x, y) coordinates.
Returns a vector of line plots for visibility syncing.
"""
function _plot_connecting_lines!(
    ax,
    map_1,
    map_2,
    plot_kwargs;
    color = :gray,
    linewidth = 1,
)
    line_alpha = plot_kwargs[:raincloud_line_alpha]
    line_plots = Any[]

    for subject_id in keys(map_1)
        if haskey(map_2, subject_id)
            pt_1 = map_1[subject_id]
            pt_2 = map_2[subject_id]
            line_plot = lines!(
                ax,
                [pt_1[1], pt_2[1]],
                [pt_1[2], pt_2[2]];
                color = color,
                linewidth = linewidth,
                alpha = line_alpha,
            )
            push!(line_plots, line_plot)
        end
    end

    return line_plots
end

"""
    _calculate_raincloud_positions(center, plot_kwargs)

Calculate x positions for all raincloud components (violin, box, points) for left and right sides
centered around `center`. Components are positioned to straddle the tick mark symmetrically,
with the visual center at the tick mark.

Uses explicit offset parameters for each component:
- `raincloud_violin_offset`: distance from center to violin (outer component)
- `raincloud_box_offset`: half-distance from center to boxplot
- `raincloud_points_offset`: half-distance from center to points

Layout:
- Left: Violin (outer left), Box (left of tick), Points (right of tick - crossing center)
- Right: Points (left of tick - crossing center), Box (right of tick), Violin (outer right)
"""
function _calculate_raincloud_positions(center, plot_kwargs)
    violin_offset = plot_kwargs[:raincloud_violin_offset]
    box_offset = plot_kwargs[:raincloud_box_offset]
    points_offset = plot_kwargs[:raincloud_points_offset]

    # Position components to straddle the center symmetrically
    # Violin is outermost, box and points both on same side closer to center
    # Left side: Violin far left, Box left-of-center, Points left-of-center (closer to tick)
    # Right side: Points right-of-center (closer to tick), Box right-of-center, Violin far right
    return (
        left = (
            violin_x = center - violin_offset,
            box_x = center - box_offset / 2,
            points_x = center - points_offset / 2,
        ),
        right = (
            violin_x = center + violin_offset,
            box_x = center + box_offset / 2,
            points_x = center + points_offset / 2,
        ),
    )
end

"""
    _collect_group_data(setup, col_factors, row_factors, col_level, row_level, x_level, y_level)

Collect raw data and y-values for a specific group defined by factor levels.
Returns a named tuple (data=DataFrame, y=Vector{Float64}).
"""
function _collect_group_data(
    setup,
    col_factors,
    row_factors,
    col_level,
    row_level,
    x_level,
    y_level,
)
    data = _filter_raw_data(
        setup.raw_data,
        setup.x_factors,
        setup.y_factors,
        col_factors,
        row_factors,
        x_level,
        y_level,
        col_level,
        row_level,
    )
    y = isempty(data) ? Float64[] : collect(data[!, setup.dv])
    return (data = data, y = y)
end

"""
    _plot_raincloud_pair!(
        ax, left_y, right_y, positions, left_color, right_color, alpha, violin_width,
        violin_kw_left, violin_kw_right, boxplot_kw_left, boxplot_kw_right, individual_data, plot_kwargs;
        left_label = nothing, right_label = nothing
    )

Plot a complete raincloud pair (left and right sides) at the given positions.
Returns point coordinates and elements for both sides.

Labels are used for legend creation when pairing by y-levels.
"""
function _plot_raincloud_pair!(
    ax,
    left_y,
    right_y,
    positions,
    left_color,
    right_color,
    alpha,
    violin_width,
    violin_kw_left,
    violin_kw_right,
    boxplot_kw_left,
    boxplot_kw_right,
    individual_data,
    plot_kwargs;
    left_label = nothing,
    right_label = nothing,
)
    # Plot left side
    left_result = _plot_raincloud_side!(
        ax,
        left_y,
        positions.left,
        left_color,
        alpha,
        violin_width,
        violin_kw_left,
        boxplot_kw_left,
        individual_data,
        :left,
        plot_kwargs;
        label = left_label,
    )

    # Plot right side
    right_result = _plot_raincloud_side!(
        ax,
        right_y,
        positions.right,
        right_color,
        alpha,
        violin_width,
        violin_kw_right,
        boxplot_kw_right,
        individual_data,
        :right,
        plot_kwargs;
        label = right_label,
    )

    return (
        left_points_x = left_result.points_x,
        left_points_y = left_result.points_y,
        right_points_x = right_result.points_x,
        right_points_y = right_result.points_y,
        left_elements = left_result.elements,
        right_elements = right_result.elements,
    )
end

"""
    _plot_mean_with_errorbars!(ax, x_positions, means, distances, color, plot_kwargs, errorbars; label=nothing)

Plot a mean line connecting positions with error bars.
Returns the main line plot for legend/visibility syncing.
"""
function _plot_mean_with_errorbars!(
    ax,
    x_positions::Vector{Float64},
    means::Vector{Float64},
    distances::Vector{Float64},
    color,
    plot_kwargs,
    errorbars::Symbol;
    label = nothing,
)
    # Plot mean line
    line_kw = _extract_kwargs(plot_kwargs, "line_")
    if !isnothing(color)
        line_kw[:color] = color
    end
    if !isnothing(label)
        line_kw[:label] = label
    end
    main_plot = lines!(ax, x_positions, means; line_kw...)

    # Plot error bars using consolidated helper
    errorbar_plot = _plot_errorbars!(
        ax,
        x_positions,
        means,
        distances,
        plot_kwargs,
        errorbars;
        color = color,
    )

    return (main_plot = main_plot, errorbar_plot = errorbar_plot)
end


"""
    _sync_element_visibility!(main_plot, elements)

Sync visibility of all elements to a main plot's visibility.
When the main plot is toggled in the legend, all elements follow.
"""
function _sync_element_visibility!(main_plot, elements)
    for elem in elements
        _link_visibility!(main_plot, elem)
    end
end

"""
    _plot_2x2_group_components!(ax, y_data, positions, color, alpha, violin_width, 
                                violin_kw, boxplot_kw, plot_kwargs, individual_data, side)

Plot violin, boxplot, and scatter points for a single group in a 2x2 raincloud layout.
`positions` should be a named tuple with `violin_x`, `box_x`, and `points_x`.
Returns (points_x_list, points_y_list, elements).

NOTE: This is a compatibility wrapper that delegates to _render_raincloud_components!
"""
function _plot_2x2_group_components!(
    ax,
    y_data,
    positions,
    color,
    alpha,
    violin_width,
    violin_kw,
    boxplot_kw,
    plot_kwargs,
    individual_data,
    side::Symbol;
    label = nothing,
)
    spec = RaincloudComponentSpec(
        ax,
        y_data isa Vector{Float64} ? y_data : collect(Float64, y_data),
        positions,
        color,
        Float64(alpha),
        Float64(violin_width),
        side,
        individual_data,
        label,
    )

    return _render_raincloud_components!(spec, plot_kwargs, violin_kw, boxplot_kw)
end

"""
    _calculate_2x2_positions(pre_center, post_center, plot_kwargs)

Calculate all x positions for a 2x2 raincloud layout. Components straddle their centers
symmetrically, with the visual center at the tick mark.

Uses 2x2-specific offset parameters:
- `raincloud_2x2_violin_offset`: distance from center to violin (outer component)
- `raincloud_2x2_box_offset`: half-distance from center to boxplot
- `raincloud_2x2_points_offset`: half-distance from center to points
- `raincloud_2x2_box_dodge`: dodge offset to separate boxplots of the two groups
- `raincloud_2x2_points_dodge`: dodge offset to separate individual points and means of the two groups

Returns a named tuple with positions for each group at each time point.
"""
function _calculate_2x2_positions(pre_center, post_center, plot_kwargs)
    # Use 2x2-specific parameters
    violin_offset = plot_kwargs[:raincloud_2x2_violin_offset]
    box_offset = plot_kwargs[:raincloud_2x2_box_offset]
    points_offset = plot_kwargs[:raincloud_2x2_points_offset]
    box_dodge = plot_kwargs[:raincloud_2x2_box_dodge]
    points_dodge = plot_kwargs[:raincloud_2x2_points_dodge]

    # Pre side: violins on left (facing right), components straddle center
    # Group 1 is upper/first y-level, Group 2 is lower/second y-level
    # Groups are separated by pair_gap (half_gap on each side of center line)
    # Boxplots are dodged by box_dodge to prevent overlap
    # Points are dodged by points_dodge to prevent overlap
    pre_group1 = (
        violin_x = pre_center - violin_offset,
        box_x = pre_center - box_offset / 2 - box_dodge,
        points_x = pre_center + points_offset / 2 - points_dodge,
    )
    pre_group2 = (
        violin_x = pre_center - violin_offset,
        box_x = pre_center - box_offset / 2 + box_dodge,
        points_x = pre_center + points_offset / 2 + points_dodge,
    )

    # Post side: violins on right (facing left), components straddle center
    # Boxplots are dodged by box_dodge to prevent overlap
    # Points are dodged by points_dodge to prevent overlap
    post_group1 = (
        violin_x = post_center + violin_offset,
        box_x = post_center + box_offset / 2 - box_dodge,
        points_x = post_center - points_offset / 2 - points_dodge,
    )
    post_group2 = (
        violin_x = post_center + violin_offset,
        box_x = post_center + box_offset / 2 + box_dodge,
        points_x = post_center - points_offset / 2 + points_dodge,
    )

    return (
        pre_group1 = pre_group1,
        pre_group2 = pre_group2,
        post_group1 = post_group1,
        post_group2 = post_group2,
    )
end

"""
    _finalize_2x2_group!(ax, setup, group_data, y_level, x_level_pre, x_level_post, 
                         pre_points_x, post_points_x, color, errorbars, elements, 
                         connecting_lines)

Add mean line with errorbars for a group and sync visibility of all its elements.
"""
function _finalize_2x2_group!(
    ax,
    setup,
    y_level,
    x_level_pre,
    x_level_post,
    pre_points_x,
    post_points_x,
    color,
    errorbars,
    elements,
    connecting_lines,
)
    # Get emmeans data for this group at both time points
    group_pre_data = _filter_group_data_by_x_level(
        _group_emmeans_data(
            setup.emmeans_data,
            setup.effect_factors,
            setup.x_indices,
            setup.y_indices,
            y_level,
        ),
        x_level_pre,
    )
    group_post_data = _filter_group_data_by_x_level(
        _group_emmeans_data(
            setup.emmeans_data,
            setup.effect_factors,
            setup.x_indices,
            setup.y_indices,
            y_level,
        ),
        x_level_post,
    )

    (isempty(group_pre_data) || isempty(group_post_data)) && return nothing

    # Check if mean line should be shown
    show_mean = get(setup.plot_kwargs, :raincloud_show_mean, true)

    if show_mean
        pre_mean = group_pre_data[1].row.Mean
        post_mean = group_post_data[1].row.Mean
        pre_distance = _get_error_distance(group_pre_data[1].row, errorbars)
        post_distance = _get_error_distance(group_post_data[1].row, errorbars)

        # Plot mean line (no label - violin/boxplot carries the label)
        result = _plot_mean_with_errorbars!(
            ax,
            [pre_points_x, post_points_x],
            [pre_mean, post_mean],
            [pre_distance, post_distance],
            color,
            setup.plot_kwargs,
            errorbars,
        )

        # Sync all elements to main plot visibility
        _sync_element_visibility!(result.main_plot, elements)
        _sync_element_visibility!(result.main_plot, connecting_lines)

        # Sync errorbar if present
        !isnothing(result.errorbar_plot) &&
            _link_errorbar_visibility!(result.main_plot, result.errorbar_plot)

        return result.main_plot
    end

    return nothing
end

function _plot_raincloud!(plot_spec::PlotPanelSpec, facet_ctx::FacetContext)
    _plot_distribution_base!(
        plot_spec,
        facet_ctx,
        :raincloud,
        :none,  # Raincloud doesn't support individual_data parameter
        function (ax, x, y; kw...)
            kw_dict = Dict{Symbol,Any}(kw...)
            # Remove keys that Makie's rainclouds! doesn't support
            delete!(kw_dict, :transparency)
            delete!(kw_dict, :width)
            # Remove AnovaFun internal config keys that leak through from distribution setup
            for key in (
                :violin_width_mult, :point_alpha, :jitter_mult, :boxplot_width_mult,
                :violin_offset, :box_offset, :points_offset, :pair_gap,
                :line_alpha, :show_violin, :show_boxplot, :show_mean,
                Symbol("2x2_violin_offset"), Symbol("2x2_box_offset"),
                Symbol("2x2_points_offset"), Symbol("2x2_box_dodge"),
                Symbol("2x2_points_dodge"),
            )
                delete!(kw_dict, key)
            end

            # Handle alpha specially for rainclouds
            if haskey(kw_dict, :alpha) && haskey(kw_dict, :color)
                alpha = pop!(kw_dict, :alpha)
                if alpha isa Number
                    kw_dict[:color] =
                        _apply_alpha_to_color(kw_dict[:color], Float32(alpha))
                end
            end

            rainclouds!(ax, x, y; kw_dict...)
        end,
    )
end

"""
    _plot_raincloud_custom_simple!(plot_spec, facet_ctx, errorbars, individual_data)

Simple raincloud layout: one centered raincloud per x-position.
Used when there's only 1 group per x-position (main effect only, or y used for faceting).
"""
function _plot_raincloud_custom_simple!(
    plot_spec::PlotPanelSpec,
    facet_ctx::FacetContext,
    errorbars::Symbol,
    individual_data::Symbol = :none,
)
    setup = _extract_plot_setup(plot_spec, facet_ctx.y_faceting)

    # Determine if plots should face each other (when exactly 2 x-levels)
    n_x_levels = length(setup.x_unique)
    facing_mode = n_x_levels == 2

    # Get color - use color from y-level if faceting by y, otherwise default
    y_level_for_color =
        facet_ctx.y_faceting &&
        !isnothing(plot_spec.y_levels) &&
        !isempty(plot_spec.y_levels) ? plot_spec.y_levels[1] : nothing
    color_idx =
        if facet_ctx.y_faceting &&
           !isnothing(plot_spec.y_factors) &&
           !isempty(plot_spec.y_factors)
            # Find which y-level this facet corresponds to
            findfirst(==(y_level_for_color), plot_spec.y_levels)
        else
            1
        end
    color_idx = isnothing(color_idx) ? 1 : color_idx
    group_color = _get_group_color(plot_spec.plot_kwargs, color_idx)

    # Determine label for legend (only on first x-position)
    y_label =
        if facet_ctx.y_faceting &&
           !isnothing(plot_spec.y_levels) &&
           !isempty(plot_spec.y_levels)
            string(plot_spec.y_levels[1])
        else
            nothing
        end

    # Extract kwargs
    violin_kw = _extract_kwargs(setup.plot_kwargs, "violin_")
    boxplot_kw = _extract_kwargs(setup.plot_kwargs, "boxplot_")

    violin_width = get(
        violin_kw,
        :width,
        setup.bar_width * setup.plot_kwargs[:raincloud_violin_width_mult],
    )
    violin_kw[:width] = violin_width

    default_point_alpha = setup.plot_kwargs[:raincloud_point_alpha]
    point_alpha = _extract_and_apply_alpha!(violin_kw, group_color, default_point_alpha)

    # Track all points for connecting lines
    all_point_coords =
        Dict{Int,NamedTuple{(:x, :y),Tuple{Vector{Float64},Vector{Float64}}}}()

    # Plot a raincloud at each x-position
    for (x_idx, x_level) in enumerate(setup.x_unique)
        x_pos = Float64(x_idx)

        # Collect data for this x-position
        dist_x, dist_y = _collect_distribution_data(
            setup,
            facet_ctx.col_factors,
            facet_ctx.row_factors,
            facet_ctx.col_levels,
            facet_ctx.row_levels,
            nothing,  # no y-level filter
            1;
            collect_subjects = false,
        )

        # Filter to this x-position
        x_mask = [abs(x - x_pos) < 0.01 for x in dist_x]
        y_data = dist_y[x_mask]

        isempty(y_data) && continue

        # Determine side for this position
        # In facing mode: first x faces right, second x faces left (they face each other)
        # Otherwise: all face right
        side = facing_mode && x_idx == 2 ? :left : :right

        # Calculate positions using shared helper function
        positions = _calculate_raincloud_positions(x_pos, setup.plot_kwargs)
        # Determine which side the violin faces based on plot side
        violin_side = side == :right ? :left : :right
        # Use appropriate positions based on side
        side_positions = side == :right ? positions.right : positions.left

        # Plot raincloud (add label only on first x-position)
        label_for_plot = x_idx == 1 ? y_label : nothing
        result = _plot_raincloud_side!(
            setup.ax,
            y_data,
            side_positions,
            group_color,
            point_alpha,
            violin_width,
            violin_kw,
            boxplot_kw,
            individual_data,
            violin_side,
            setup.plot_kwargs;
            label = label_for_plot,
        )

        all_point_coords[x_idx] = (x = result.points_x, y = result.points_y)

        # Plot error bars (if mean is shown)
        show_mean = get(setup.plot_kwargs, :raincloud_show_mean, true)
        if errorbars != :none && show_mean
            group_data = _filter_group_data_by_x_level(
                _group_emmeans_data(
                    setup.emmeans_data,
                    setup.effect_factors,
                    setup.x_indices,
                    setup.y_indices,
                    nothing,
                ),
                x_level,
            )
            if !isempty(group_data)
                mean_val = group_data[1].row.Mean
                distance = _get_error_distance(group_data[1].row, errorbars)
                _plot_errorbars!(
                    setup.ax,
                    side_positions.points_x,
                    mean_val,
                    distance,
                    setup.plot_kwargs,
                    errorbars;
                    color = group_color,
                )
            end
        end
    end

    # Handle connecting lines between x-positions (for same subject across x-levels)
    if _can_plot_individual_data(individual_data, setup.raw_data, setup.id_col, setup.dv) &&
       individual_data == :connected_points &&
       length(setup.x_unique) == 2

        x_level_1, x_level_2 = setup.x_unique[1], setup.x_unique[2]

        subject_data_1 = _filter_raw_data(
            setup.raw_data,
            setup.x_factors,
            setup.y_factors,
            facet_ctx.col_factors,
            facet_ctx.row_factors,
            x_level_1,
            nothing,
            facet_ctx.col_levels,
            facet_ctx.row_levels,
        )
        subject_data_2 = _filter_raw_data(
            setup.raw_data,
            setup.x_factors,
            setup.y_factors,
            facet_ctx.col_factors,
            facet_ctx.row_factors,
            x_level_2,
            nothing,
            facet_ctx.col_levels,
            facet_ctx.row_levels,
        )

        if haskey(all_point_coords, 1) && haskey(all_point_coords, 2)
            map_1 = _build_subject_point_map(
                subject_data_1,
                all_point_coords[1].x,
                all_point_coords[1].y,
                setup.id_col,
                setup.dv,
            )
            map_2 = _build_subject_point_map(
                subject_data_2,
                all_point_coords[2].x,
                all_point_coords[2].y,
                setup.id_col,
                setup.dv,
            )
            _plot_connecting_lines!(setup.ax, map_1, map_2, setup.plot_kwargs)
        end
    end
end

function _plot_raincloud_custom!(
    plot_spec::PlotPanelSpec,
    facet_ctx::FacetContext,
    errorbars::Symbol,
    individual_data::Symbol = :none,
)
    setup = _extract_plot_setup(plot_spec, facet_ctx.y_faceting)

    # Determine layout mode:
    # - Split layout: 2 y-levels at same x-position (y_grouping exists AND not used for faceting)
    # - Simple layout: 1 group per x (main effect only, or y used for faceting)
    has_y_grouping = !isnothing(setup.y_unique) && !isempty(setup.y_unique)
    needs_split = has_y_grouping && !facet_ctx.y_faceting && length(setup.y_unique) == 2

    if !needs_split
        # Simple layout: one raincloud per x-position
        _plot_raincloud_custom_simple!(plot_spec, facet_ctx, errorbars, individual_data)
        return
    end

    # Split layout: 2 y-levels facing each other at each x-position
    if length(setup.y_unique) != 2
        error(
            "raincloud_custom split layout requires exactly 2 y-levels. Got $(length(setup.y_unique)): $(setup.y_unique)",
        )
    end

    y_level_left, y_level_right = setup.y_unique[1], setup.y_unique[2]

    # Collect data for both y-levels
    left_x, left_y = _collect_distribution_data(
        setup,
        facet_ctx.col_factors,
        facet_ctx.row_factors,
        facet_ctx.col_levels,
        facet_ctx.row_levels,
        y_level_left,
        1;
        collect_subjects = false,
    )
    right_x, right_y = _collect_distribution_data(
        setup,
        facet_ctx.col_factors,
        facet_ctx.row_factors,
        facet_ctx.col_levels,
        facet_ctx.row_levels,
        y_level_right,
        2;
        collect_subjects = false,
    )

    # Colors for each y-level
    color_left = _get_group_color(plot_spec.plot_kwargs, 1)
    color_right = _get_group_color(plot_spec.plot_kwargs, 2)

    # Extract kwargs
    violin_kw_left = _extract_kwargs(setup.plot_kwargs, "violin_")
    violin_kw_right = _extract_kwargs(setup.plot_kwargs, "violin_")
    boxplot_kw_left = _extract_kwargs(setup.plot_kwargs, "boxplot_")
    boxplot_kw_right = _extract_kwargs(setup.plot_kwargs, "boxplot_")

    # Set up violin widths
    violin_width = get(
        violin_kw_left,
        :width,
        setup.bar_width * setup.plot_kwargs[:raincloud_violin_width_mult],
    )
    violin_kw_left[:width] = violin_width
    violin_kw_right[:width] = violin_width

    # Handle alpha for violins and store for use in points
    default_point_alpha = setup.plot_kwargs[:raincloud_point_alpha]
    point_alpha = _extract_and_apply_alpha!(violin_kw_left, color_left, default_point_alpha)
    # Ensure consistency - use same alpha from right if present, otherwise keep left's alpha
    if haskey(violin_kw_right, :alpha)
        point_alpha =
            _extract_and_apply_alpha!(violin_kw_right, color_right, default_point_alpha)
    else
        _extract_and_apply_alpha!(violin_kw_right, color_right, point_alpha)
    end

    # Plot split layout: loop over x-levels, showing both y-levels at each x
    for (x_idx, x_level) in enumerate(setup.x_unique)
        x_pos = Float64(x_idx)

        # Filter data for this x position
        left_mask = [abs(x - x_pos) < 0.01 for x in left_x]
        right_mask = [abs(x - x_pos) < 0.01 for x in right_x]
        left_y_filtered = left_y[left_mask]
        right_y_filtered = right_y[right_mask]

        isempty(left_y_filtered) && isempty(right_y_filtered) && continue

        # Calculate positions centered at this x position
        positions = _calculate_raincloud_positions(x_pos, setup.plot_kwargs)

        # Only add labels on the first x-level to avoid duplicate legend entries
        left_label = x_idx == 1 ? string(y_level_left) : nothing
        right_label = x_idx == 1 ? string(y_level_right) : nothing

        # Plot the pair (with labels only on first iteration when pairing by y-levels)
        point_coords = _plot_raincloud_pair!(
            setup.ax,
            left_y_filtered,
            right_y_filtered,
            positions,
            color_left,
            color_right,
            point_alpha,
            violin_width,
            violin_kw_left,
            violin_kw_right,
            boxplot_kw_left,
            boxplot_kw_right,
            individual_data,
            setup.plot_kwargs;
            left_label = left_label,
            right_label = right_label,
        )

        # Get group data for error bars (if mean is shown)
        show_mean = get(setup.plot_kwargs, :raincloud_show_mean, true)
        if errorbars != :none && show_mean
            left_group_data = _filter_group_data_by_x_level(
                _group_emmeans_data(
                    setup.emmeans_data,
                    setup.effect_factors,
                    setup.x_indices,
                    setup.y_indices,
                    y_level_left,
                ),
                x_level,
            )
            right_group_data = _filter_group_data_by_x_level(
                _group_emmeans_data(
                    setup.emmeans_data,
                    setup.effect_factors,
                    setup.x_indices,
                    setup.y_indices,
                    y_level_right,
                ),
                x_level,
            )

            # In the new centered layout, positions are swapped:
            # - Left y-level (first, blue) plots at positions.right.points_x (left of center)
            # - Right y-level (second, orange) plots at positions.left.points_x (right of center)
            # So we need to swap BOTH positions AND data/colors to match
            _plot_raincloud_errorbars!(
                setup.ax,
                positions.right.points_x,  # Where left y-level's points are (left of center)
                positions.left.points_x,   # Where right y-level's points are (right of center)
                right_group_data,          # SWAPPED: right data to left position visually
                left_group_data,           # SWAPPED: left data to right position visually  
                color_right,               # SWAPPED: right color to left position visually
                color_left,                # SWAPPED: left color to right position visually
                setup.plot_kwargs,
                errorbars,
            )
        end

        # Note: Connecting lines between y-levels don't make sense conceptually
        # (connecting different factor levels is meaningless)
    end
end

# Plot a custom 2x2 raincloud plot to a single panel
# Requires both x_grouping (2 levels) and y_grouping (2 levels)
# Layout: Pre (left): Violin → Box → Points for each group
function _plot_raincloud_custom_2x2!(
    plot_spec::PlotPanelSpec,
    facet_ctx::FacetContext,
    errorbars::Symbol,
    individual_data::Symbol = :none,
)
    setup = _extract_plot_setup(plot_spec, facet_ctx.y_faceting)

    # Validate: require both x_grouping (2 levels) and y_grouping (2 levels)
    if length(setup.x_unique) != 2
        error(
            "raincloud_custom_2x2 requires x_grouping with exactly 2 levels. Current x_grouping has $(length(setup.x_unique)) levels: $(setup.x_unique)",
        )
    end
    if isnothing(setup.y_unique) || length(setup.y_unique) != 2
        error(
            "raincloud_custom_2x2 requires y_grouping with exactly 2 levels. Current y_grouping has $(length(setup.y_unique)) levels: $(setup.y_unique)",
        )
    end

    x_level_pre, x_level_post = setup.x_unique[1], setup.x_unique[2]
    y_level_1, y_level_2 = setup.y_unique[1], setup.y_unique[2]

    # Collect data for each group at each time point
    pre_g1 = _collect_group_data(
        setup,
        facet_ctx.col_factors,
        facet_ctx.row_factors,
        facet_ctx.col_levels,
        facet_ctx.row_levels,
        x_level_pre,
        y_level_1,
    )
    pre_g2 = _collect_group_data(
        setup,
        facet_ctx.col_factors,
        facet_ctx.row_factors,
        facet_ctx.col_levels,
        facet_ctx.row_levels,
        x_level_pre,
        y_level_2,
    )
    post_g1 = _collect_group_data(
        setup,
        facet_ctx.col_factors,
        facet_ctx.row_factors,
        facet_ctx.col_levels,
        facet_ctx.row_levels,
        x_level_post,
        y_level_1,
    )
    post_g2 = _collect_group_data(
        setup,
        facet_ctx.col_factors,
        facet_ctx.row_factors,
        facet_ctx.col_levels,
        facet_ctx.row_levels,
        x_level_post,
        y_level_2,
    )

    # Get colors for both groups
    color_group1 = _get_group_color(plot_spec.plot_kwargs, 1)
    color_group2 = _get_group_color(plot_spec.plot_kwargs, 2)

    # Extract kwargs and set up dimensions
    violin_kw = _extract_kwargs(setup.plot_kwargs, "violin_")
    boxplot_kw = _extract_kwargs(setup.plot_kwargs, "boxplot_")
    violin_width = get(
        violin_kw,
        :width,
        setup.bar_width * setup.plot_kwargs[:raincloud_violin_width_mult],
    )

    default_point_alpha = setup.plot_kwargs[:raincloud_point_alpha]
    point_alpha = _extract_and_apply_alpha!(violin_kw, nothing, default_point_alpha)

    # Calculate positions for all groups
    positions = _calculate_2x2_positions(1.0, 2.0, setup.plot_kwargs)

    # Plot all four group/time combinations using helper
    # Labels only on pre (first x-position) to avoid duplicate legend entries
    pre_g1_result = _plot_2x2_group_components!(
        setup.ax,
        pre_g1.y,
        positions.pre_group1,
        color_group1,
        point_alpha,
        violin_width,
        violin_kw,
        boxplot_kw,
        setup.plot_kwargs,
        individual_data,
        :left;
        label = string(y_level_1),
    )
    pre_g2_result = _plot_2x2_group_components!(
        setup.ax,
        pre_g2.y,
        positions.pre_group2,
        color_group2,
        point_alpha,
        violin_width,
        violin_kw,
        boxplot_kw,
        setup.plot_kwargs,
        individual_data,
        :left;
        label = string(y_level_2),
    )
    post_g1_result = _plot_2x2_group_components!(
        setup.ax,
        post_g1.y,
        positions.post_group1,
        color_group1,
        point_alpha,
        violin_width,
        violin_kw,
        boxplot_kw,
        setup.plot_kwargs,
        individual_data,
        :right,
    )
    post_g2_result = _plot_2x2_group_components!(
        setup.ax,
        post_g2.y,
        positions.post_group2,
        color_group2,
        point_alpha,
        violin_width,
        violin_kw,
        boxplot_kw,
        setup.plot_kwargs,
        individual_data,
        :right,
    )

    # Combine elements for each group
    group1_elements = vcat(pre_g1_result[3], post_g1_result[3])
    group2_elements = vcat(pre_g2_result[3], post_g2_result[3])

    # Plot connecting lines between Pre and Post for each group
    group1_connecting_lines = Any[]
    group2_connecting_lines = Any[]

    if _can_plot_individual_data(individual_data, setup.raw_data, setup.id_col, setup.dv) &&
       individual_data == :connected_points
        # Group 1 connecting lines
        group1_pre_map = _build_subject_point_map(
            pre_g1.data,
            pre_g1_result[1],
            pre_g1_result[2],
            setup.id_col,
            setup.dv,
        )
        group1_post_map = _build_subject_point_map(
            post_g1.data,
            post_g1_result[1],
            post_g1_result[2],
            setup.id_col,
            setup.dv,
        )
        group1_connecting_lines = _plot_connecting_lines!(
            setup.ax,
            group1_pre_map,
            group1_post_map,
            setup.plot_kwargs;
            color = color_group1,
        )

        # Group 2 connecting lines
        group2_pre_map = _build_subject_point_map(
            pre_g2.data,
            pre_g2_result[1],
            pre_g2_result[2],
            setup.id_col,
            setup.dv,
        )
        group2_post_map = _build_subject_point_map(
            post_g2.data,
            post_g2_result[1],
            post_g2_result[2],
            setup.id_col,
            setup.dv,
        )
        group2_connecting_lines = _plot_connecting_lines!(
            setup.ax,
            group2_pre_map,
            group2_post_map,
            setup.plot_kwargs;
            color = color_group2,
        )
    end

    # Finalize each group: mean lines, errorbars, and visibility syncing
    _finalize_2x2_group!(
        setup.ax,
        setup,
        y_level_1,
        x_level_pre,
        x_level_post,
        positions.pre_group1.points_x,
        positions.post_group1.points_x,
        color_group1,
        errorbars,
        group1_elements,
        group1_connecting_lines,
    )
    _finalize_2x2_group!(
        setup.ax,
        setup,
        y_level_2,
        x_level_pre,
        x_level_post,
        positions.pre_group2.points_x,
        positions.post_group2.points_x,
        color_group2,
        errorbars,
        group2_elements,
        group2_connecting_lines,
    )
end
