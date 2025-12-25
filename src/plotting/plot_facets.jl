"""
Faceting functions for plot_anova.

This file contains functions for:
- Creating and managing facet specifications
- Filtering data for individual facet panels
- Creating facet grids with proper axis configuration
- Calculating global y-limits across facets
"""


"""
Create a FacetSpec from user inputs.
"""
function _create_facet_spec(
    facet_cols::Union{Nothing,Symbol,Vector{Symbol}},
    facet_rows::Union{Nothing,Symbol,Vector{Symbol}},
    effect_factors::Vector{Symbol},
    emmeans_data::DataFrame,
)
    # Convert to vectors
    col_factors =
        isnothing(facet_cols) ? nothing :
        (facet_cols isa Symbol ? [facet_cols] : collect(facet_cols))
    row_factors =
        isnothing(facet_rows) ? nothing :
        (facet_rows isa Symbol ? [facet_rows] : collect(facet_rows))

    # Find indices
    col_indices =
        isnothing(col_factors) ? Int[] :
        [findfirst(==(f), effect_factors) for f in col_factors]
    row_indices =
        isnothing(row_factors) ? Int[] :
        [findfirst(==(f), effect_factors) for f in row_factors]

    # Get unique levels
    col_levels =
        isnothing(col_factors) ? nothing :
        _extract_levels_for_effect(emmeans_data, col_indices, effect_factors)
    row_levels =
        isnothing(row_factors) ? nothing :
        _extract_levels_for_effect(emmeans_data, row_indices, effect_factors)

    # Convert to string format if needed (for multi-factor combinations)
    if !isnothing(col_levels) && col_levels isa Vector{Vector{String}}
        col_levels = [join(c, " × ") for c in col_levels]
    end
    if !isnothing(row_levels) && row_levels isa Vector{Vector{String}}
        row_levels = [join(r, " × ") for r in row_levels]
    end

    # Normalize to [nothing] if no facets (so we can always iterate)
    col_levels = isnothing(col_levels) ? [nothing] : col_levels
    row_levels = isnothing(row_levels) ? [nothing] : row_levels

    return FacetSpec(
        col_factors,
        row_factors,
        col_levels,
        row_levels,
        col_indices,
        row_indices,
    )
end

"""
Filter data for a specific facet panel.
Works for both emmeans data (with "Level" column) and raw data (with factor columns).
"""
function _filter_for_facet(
    data::DataFrame,
    spec::FacetSpec,
    row_idx::Int,
    col_idx::Int,
    effect_factors::Vector{Symbol},
)
    row_level = spec.row_levels[row_idx]
    col_level = spec.col_levels[col_idx]

    # Check if this is emmeans data (has "Level" column) or raw data (has factor columns)
    if hasproperty(data, :Level)
        # This is emmeans data - filter by parsing the Level column
        return filter(
            row -> begin
                level_parts = strip.(split(row.Level, ", "))
                if length(level_parts) < length(effect_factors)
                    return false
                end

                # Check column facets
                if !isnothing(col_level) && !isnothing(spec.col_factors)
                    if length(spec.col_indices) > 1
                        col_combo = [level_parts[i] for i in spec.col_indices]
                        if join(col_combo, " × ") != string(col_level)
                            return false
                        end
                    else
                        if level_parts[spec.col_indices[1]] != string(col_level)
                            return false
                        end
                    end
                end

                # Check row facets
                if !isnothing(row_level) && !isnothing(spec.row_factors)
                    if length(spec.row_indices) > 1
                        row_combo = [level_parts[i] for i in spec.row_indices]
                        if join(row_combo, " × ") != string(row_level)
                            return false
                        end
                    else
                        if level_parts[spec.row_indices[1]] != string(row_level)
                            return false
                        end
                    end
                end

                return true
            end,
            data,
        )
    else
        # This is raw data - filter by factor columns directly
        col_factors = isnothing(spec.col_factors) ? Symbol[] : spec.col_factors
        row_factors = isnothing(spec.row_factors) ? Symbol[] : spec.row_factors

        return _filter_by_facets(data, col_factors, row_factors, col_level, row_level)
    end
end

"""
    _prepare_axis_kwargs_for_panel(axis_kw, show_x_axis, show_y_axis, xlabel_val, ylabel_val)

Prepare axis kwargs for a single panel with appropriate visibility settings.
"""
function _prepare_axis_kwargs_for_panel(
    axis_kw,
    show_x_axis::Bool,
    show_y_axis::Bool,
    xlabel_val,
    ylabel_val,
)
    axis_kw_panel = copy(axis_kw)
    axis_kw_panel[:xlabel] = show_x_axis ? xlabel_val : ""
    axis_kw_panel[:ylabel] = show_y_axis ? ylabel_val : ""
    axis_kw_panel[:xlabelvisible] = show_x_axis
    axis_kw_panel[:ylabelvisible] = show_y_axis
    axis_kw_panel[:xticksvisible] = show_x_axis
    axis_kw_panel[:yticksvisible] = show_y_axis
    axis_kw_panel[:xticklabelsvisible] = show_x_axis
    axis_kw_panel[:yticklabelsvisible] = show_y_axis
    axis_kw_panel[:bottomspinevisible] = true  # Always show bottom spine
    return axis_kw_panel
end

"""
    _create_facet_axes!(fig, axes, spec, axis_kw, xlabel_val, ylabel_val, xlim_val, ylim_val, x_unique, max_offset, plot_theme, plot_kwargs)

Create all axes for the facet grid.
Mutates the axes matrix in place.
"""
function _create_facet_axes!(
    fig,
    axes::Matrix{Axis},
    spec::FacetSpec,
    axis_kw,
    xlabel_val,
    ylabel_val,
    xlim_val,
    ylim_val,
    x_unique::Vector{String},
    max_offset::Float64,
    plot_theme,
    plot_kwargs::Dict{Symbol,Any},
)
    n_rows, n_cols = size(axes)
    has_row_facets = !isnothing(spec.row_factors) && !isempty(spec.row_factors)

    with_theme(plot_theme) do
        for row_idx = 1:n_rows
            for col_idx = 1:n_cols
                # Determine visibility
                show_y_axis = col_idx == 1
                show_x_axis = row_idx == n_rows

                # Prepare axis kwargs
                axis_kw_panel = _prepare_axis_kwargs_for_panel(
                    axis_kw,
                    show_x_axis,
                    show_y_axis,
                    xlabel_val,
                    ylabel_val,
                )

                # Create axis
                ax = Axis(fig[row_idx, col_idx]; axis_kw_panel...)

                # Set x-axis limits early to prevent auto-scaling
                if isnothing(xlim_val)
                    xlims!(ax, (0.5 - max_offset, length(x_unique) + 0.5 + max_offset))
                else
                    xlims!(ax, xlim_val)
                end

                # Set y-axis limits if provided (will be overridden by global_ylim later if set)
                if !isnothing(ylim_val)
                    ylims!(ax, ylim_val)
                end

                axes[row_idx, col_idx] = ax

                # Add column facet title (only in first row to avoid repetition)
                if !isnothing(spec.col_factors) && row_idx == 1
                    col_level = spec.col_levels[col_idx]
                    ax.title = "$(join(string.(spec.col_factors), " × ")) = $col_level"
                end

                # Add row facet label on the right side (only in the rightmost column)
                if has_row_facets && col_idx == n_cols
                    row_level = spec.row_levels[row_idx]
                    row_label = "$(join(string.(spec.row_factors), " × ")) = $row_level"
                    Label(
                        fig[row_idx, n_cols+1],
                        row_label,
                        rotation = 3 * pi / 2,  # 270 degrees (vertical)
                        halign = :left,
                        valign = :center,
                        padding = plot_kwargs[:layout_axis_label_padding],
                        font = ax.titlefont,
                        fontsize = ax.titlesize,
                    )
                end
            end
        end
    end
end

"""
Create a FacetGrid with properly configured axes.
This handles the figure creation, axis setup, and layout for faceted plots.
"""
function _create_facet_grid(
    spec::FacetSpec,
    plot_kwargs::Dict{Symbol,Any},
    x_factors::Vector{Symbol},
    x_unique::Vector{String},
    y_unique,
    y_faceting::Bool,
    plot_theme,
)
    # Extract figure kwargs
    figure_kw = _extract_kwargs(plot_kwargs, "figure_")

    # Add extra column for row facet labels if needed (they go on the right)
    has_row_facets = !isnothing(spec.row_factors) && !isempty(spec.row_factors)
    # extra_col_width = has_row_facets ? 100 : 0
    n_cols = length(spec.col_levels)
    n_rows = length(spec.row_levels)

    # Set default size if not specified
    # Check for figure_size in plot_kwargs first (convenience key that doesn't have the "figure_" prefix)
    if haskey(plot_kwargs, :figure_size) && !isnothing(plot_kwargs[:figure_size])
        figure_kw[:size] = plot_kwargs[:figure_size]
    elseif haskey(figure_kw, :size) && !isnothing(figure_kw[:size])
        # Use the size from figure_kw (extracted from figure_size or other figure_* keys)
        # Already set, do nothing
    else
        # Default: 800x600 per panel, scaled by number of columns/rows
        # figure_kw[:size] = (800 * n_cols + extra_col_width, 600 * n_rows)
        figure_kw[:size] = (
            plot_kwargs[:layout_panel_width] * n_cols,
            plot_kwargs[:layout_panel_height] * n_rows,
        )
    end

    # Create figure with theme applied
    fig = with_theme(plot_theme) do
        Figure(; figure_kw...)
    end

    # Add spacing between rows and columns
    # Grid spacing - larger gap between facet rows for visual separation
    row_gap =
        has_row_facets ? plot_kwargs[:layout_row_gap_with_facets] :
        plot_kwargs[:layout_row_gap]
    col_gap = plot_kwargs[:layout_col_gap]
    rowgap!(fig.layout, row_gap)
    colgap!(fig.layout, col_gap)

    # Pre-compute values that are the same for all panels
    axis_kw = _extract_kwargs(plot_kwargs, "axis_")
    xlabel_default =
        length(x_factors) == 1 ? string(x_factors[1]) : join(string.(x_factors), " × ")
    xlabel_val =
        isnothing(get(axis_kw, :xlabel, nothing)) ? xlabel_default : axis_kw[:xlabel]
    ylabel_val = get(axis_kw, :ylabel, "Mean")
    xlim_val = get(axis_kw, :xlim, nothing)
    ylim_val = get(axis_kw, :ylim, nothing)
    delete!(axis_kw, :xlim)
    delete!(axis_kw, :ylim)
    dodge_width = plot_kwargs[:dodge_width]
    n_dodge = !isnothing(y_unique) && !y_faceting ? length(y_unique) : 1
    max_offset = n_dodge > 1 ? (dodge_width / n_dodge) / 2 : 0.0

    # Create axes matrix
    axes = Matrix{Axis}(undef, n_rows, n_cols)

    # Create axes for each facet
    _create_facet_axes!(
        fig,
        axes,
        spec,
        axis_kw,
        xlabel_val,
        ylabel_val,
        xlim_val,
        ylim_val,
        x_unique,
        max_offset,
        plot_theme,
        plot_kwargs,
    )

    # Link axes (x and y limits should be linked)
    linkaxes!.(Ref(axes[1, 1]), axes)

    return FacetGrid(fig, axes, spec)
end

# Constants for y-limit calculation
# Constants for distribution plot y-limit calculations moved to plot_config.jl

# Helper to add KDE extent estimates to y_values
function _add_kde_extent!(y_values, raw_vals::AbstractVector, plot_kwargs)
    length(raw_vals) <= 1 && return
    μ = mean(raw_vals)
    σ = std(raw_vals)
    kde_extent = plot_kwargs[:ylim_kde_std_multiplier] * σ
    push!(y_values, μ - kde_extent, μ + kde_extent)
end

# Helper to add boxplot whisker extents to y_values
function _add_whisker_extents!(y_values, raw_vals::AbstractVector, plot_kwargs)
    length(raw_vals) <= 1 && return
    q1, q3 = quantile(raw_vals, [0.25, 0.75])
    iqr = q3 - q1
    whisker_mult = plot_kwargs[:ylim_whisker_iqr_multiplier]
    whisker_low = q1 - whisker_mult * iqr
    whisker_high = q3 + whisker_mult * iqr
    raw_min, raw_max = extrema(raw_vals)
    whisker_low < raw_min && push!(y_values, whisker_low)
    whisker_high > raw_max && push!(y_values, whisker_high)
end

# Calculate global y-axis limits from all data across all facets
function _calculate_global_ylimits(
    plot_data,
    facet_spec,
    plot_type::Symbol,
    errorbars::Symbol,
    individual_data::Symbol,
    plot_kwargs,
)

    # Collect y values from all facets
    y_values = Float64[]
    for row_idx in eachindex(facet_spec.row_levels)
        for col_idx in eachindex(facet_spec.col_levels)
            # Get emmeans data for this facet
            facet_emmeans = _filter_for_facet(
                plot_data.interaction_data,
                facet_spec,
                row_idx,
                col_idx,
                plot_data.effect_factors,
            )

            # Add mean values (and errorbars if plotted)
            append!(y_values, facet_emmeans.Mean)
            if errorbars != :none
                # Compute Lower/Upper from error for y-axis limits
                for row in eachrow(facet_emmeans)
                    error_dist = _get_error_distance(row, errorbars)
                    if error_dist > 0.0
                        push!(y_values, row.Mean - error_dist, row.Mean + error_dist)
                    end
                end
            end

            # Add raw data for distribution plots OR when individual data points are shown
            include_raw_data =
                plot_type in
                [:violin, :boxplot, :raincloud, :raincloud_custom, :raincloud_custom_2x2] ||
                individual_data ∈ [:points, :connected_points]

            if include_raw_data
                facet_raw = _filter_for_facet(
                    plot_data.raw_data,
                    facet_spec,
                    row_idx,
                    col_idx,
                    plot_data.effect_factors,
                )
                raw_vals = facet_raw[!, plot_data.dv]
                append!(y_values, raw_vals)

                # Add KDE extent/whisker estimates for violin/boxplot-like plots
                plot_type in [:violin, :raincloud_custom, :raincloud_custom_2x2] &&
                    _add_kde_extent!(y_values, raw_vals, plot_kwargs)
                plot_type in [:boxplot, :raincloud] &&
                    _add_whisker_extents!(y_values, raw_vals, plot_kwargs)
            end
        end
    end

    # Calculate limits with padding
    y_min, y_max = extrema(y_values)
    y_range = y_max - y_min
    padding = plot_kwargs[:ylim_padding]

    return (y_min - padding * y_range, y_max + padding * y_range)
end
