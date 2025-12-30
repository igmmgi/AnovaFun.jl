"""
    emmeans(result::AnovaResult; by=nothing, level=0.95, adjust=:none)

Compute estimated marginal means from an ANOVA result.
This method uses the data stored in the result object.

# Arguments
- `result::AnovaResult`: An `AnovaResult` object from `anova()`
- `by::Union{Vector{Symbol}, Nothing}`: Effect(s) to compute marginal means for. 
  - `nothing` (default): Compute marginal means for all effects (all factors and their interactions)
  - `Vector{Symbol}`: Compute marginal means for an interaction (e.g., `[:time, :condition]`)
- `level::Float64`: Confidence level for confidence intervals (default: 0.95 for 95% CI)
- `adjust::Symbol`: Method for confidence interval adjustment. Options: `:none` (default), `:bonferroni`, or `:sidak`

# Returns
An `EmmeansResult` object containing:
- `means::DataFrame`: Marginal means table with columns Effect, Level, N, Mean, SD, SE, Lower, Upper
- `anova::AnovaResult`: The original ANOVA result object
- `level::Float64`: Confidence level used for intervals

Note: The original data can be accessed via `result.anova.data`.

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
em = emmeans(result)                               # all effects
em = emmeans(result, by=:time)                     # single factor
em = emmeans(result, by=[:time, :condition])       # interaction
em = emmeans(result, by=:time, adjust=:bonferroni) # with correction
```
"""
function emmeans(
    result::AnovaResult;
    by::Union{Vector{Symbol},Nothing} = nothing,
    level::Float64 = 0.95,
    adjust::Symbol = :none,
)

    # validation
    adjustments = [:none, :bonferroni, :sidak]
    adjust ∉ adjustments &&
        throw(ArgumentError("adjust must be one of: $(join(adjustments, ", "))"))

    # factors
    all_factors_list = vcat(result.design.within_factors, result.design.between_factors)
    if !isnothing(by)
        for factor in by
            factor ∉ all_factors_list && throw(
                ArgumentError(
                    "Factor $factor not found in design. Available factors: $(join(all_factors_list, ", "))",
                ),
            )
        end
        # requested order
        requested_set = Set(by)
        remaining_factors = [f for f in all_factors_list if f ∉ requested_set]
        all_factors_list = vcat(by, remaining_factors)
    end

    # DataFrame for marginal means 
    means_data = DataFrame(
        Effect = String[],
        Level = String[],
        N = Int[],
        Mean = Float64[],
        SD = Float64[],
        SE = Float64[],
        Lower = Float64[],
        Upper = Float64[],
        error = Float64[],
    )

    # Only include grand mean if by is nothing (computing all effects)
    if isnothing(by)
        mean_row, _ = _grand_mean(result.data, result.dv, result.design.n_id, level)
        push!(means_data, mean_row)
    end

    # Marginal means: process only requested effect if by is specified, otherwise all effects
    effects_to_process = if isnothing(by)
        effect_list = Vector{Symbol}[]
        for n_factors = 1:length(all_factors_list)
            append!(effect_list, _combinations(all_factors_list, n_factors))
        end
        effect_list
    else # Process only requested effect(s) 
        [by]
    end

    all_factors_ordered = all_factors(result.design)
    for effect_factors in effects_to_process
        # Determine effect name: use user's order if by is specified, otherwise use design's order
        effect_name = if !isnothing(by)
            join(string.(by), " × ")
        else
            _effect_name(effect_factors, all_factors_ordered)
        end

        # Compute marginal means for each level combination
        grouped = groupby(result.data, effect_factors)
        n_levels = length(grouped)  # Number of levels for this effect

        # Determine factor order for Level string - must match Effect name order
        factor_order_for_level = if !isnothing(by)
            by  # User specified order
        else
            # Use same order as effect_name: all_factors_ordered order
            [f for f in all_factors_ordered if f in effect_factors]
        end

        # Sort groups by factor level order to match user-specified order
        # Get unique levels for each factor in order of first appearance
        level_orders = Dict{Symbol,Vector{Any}}()
        for factor in effect_factors
            unique_levels = unique(result.data[!, factor])
            level_orders[factor] = unique_levels
        end

        # Sort groups based on level order (lexicographic order across factors)
        sorted_groups = collect(grouped)
        if length(effect_factors) == 1
            # Single factor: sort by level order
            factor = effect_factors[1]
            level_order = level_orders[factor]
            sort!(sorted_groups, by = g -> findfirst(==(g[1, factor]), level_order))
        else
            # Multiple factors: sort lexicographically by factor order
            sort!(
                sorted_groups,
                by = g -> [findfirst(==(g[1, f]), level_orders[f]) for f in effect_factors],
            )
        end

        for group in sorted_groups
            level_parts = [string(group[1, f]) for f in factor_order_for_level]
            level_str = join(level_parts, ", ")

            # Aggregate to subject level - each subject contributes one mean value
            id_means = _aggregate_to_id_means(
                group,
                effect_factors,
                result.design,
                result.id,
                result.dv,
            )

            # Compute mean
            cell_mean = mean(id_means[!, result.dv])
            n_id = nrow(id_means)
            n_observations = nrow(group)

            # Compute SD (standard deviation of subject-level means)
            cell_sd = n_id > 1 ? std(id_means[!, result.dv]) : 0.0

            # Compute SE, df_error, and MSE
            se, df_error, _, _ =
                _emmeans_se(result.dv, effect_factors, result, id_means, n_observations)

            # Get df for CI calculation and adjustment 
            df_error = _get_df_for_ci(result, effect_factors, df_error)
            margin = _adjust_ci(se, df_error, adjust, n_levels, 1 - level)

            push!(
                means_data,
                (
                    Effect = effect_name,
                    Level = level_str,
                    N = n_id,
                    Mean = cell_mean,
                    SD = cell_sd,
                    SE = se,
                    Lower = cell_mean - margin,
                    Upper = cell_mean + margin,
                    error = se,
                ),
            )
        end
    end

    return EmmeansResult(means_data, result, level)
end

function _grand_mean(data::DataFrame, dv::Symbol, n_id::Int, level::Float64)

    grand_mean = mean(data[!, dv])
    grand_var = var(data[!, dv])
    grand_sd = sqrt(grand_var)
    grand_se = sqrt(grand_var / n_id)
    df_grand = n_id - 1

    # Grand mean has only 1 level, so no adjustment needed
    t_crit_grand = quantile(TDist(df_grand), (1 + level) / 2)
    margin_grand = t_crit_grand * grand_se

    # Create mean data row
    mean_row = (
        Effect = "Grand Mean",
        Level = "Overall",
        N = n_id,
        Mean = grand_mean,
        SD = grand_sd,
        SE = grand_se,
        Lower = grand_mean - margin_grand,
        Upper = grand_mean + margin_grand,
        error = grand_se,
    )

    # Create error term row
    error_row = (Effect = "Grand Mean", DFn = 1, DFd = df_grand, MSE = grand_var)

    return mean_row, error_row
end


function _get_df_for_ci(aov::AnovaResult, effect_factors::Vector{Symbol}, df_error::Int)
    if aov.design.type == :within
        return aov.design.n_id - 1
    elseif aov.design.type == :mixed
        # In a mixed design, individual effects can be pure between-subjects (e.g., just BF1)
        # or involve within-subjects factors (e.g., WF1 or BF1 × WF1)
        # Check if THIS SPECIFIC EFFECT has within factors
        has_within = any(f -> f ∈ aov.design.within_factors, effect_factors)
        if has_within
            intercept_info = _get_anova_row_info(aov, "Intercept")
            return intercept_info.dfd
        else
            return df_error
        end
    else # between-subjects design
        return df_error
    end
end


function _se_within_subjects_pure(group::AbstractDataFrame, dv::Symbol, n_id::Int)::Float64
    return sqrt(var(group[!, dv]) / n_id)
end

function _se_within_subjects_mixed(
    group::AbstractDataFrame,
    dv::Symbol,
    design::DesignInfo,
    n_id::Int,
)::Float64
    # Group by between-subjects factors to pool variance within each group
    groups = groupby(group, design.between_factors)
    ss_pooled = 0.0
    df_pooled = 0
    for g in groups
        vals = g[!, dv]
        m = mean(vals)
        ss_pooled += sum((vals .- m) .^ 2)
        df_pooled += length(vals) - 1
    end
    return sqrt((ss_pooled / df_pooled) / n_id)
end

# Compute standard error for estimated marginal means
# **Between-subjects factors** (pure between or between part of mixed):
#    - Uses pooled MSE from ANOVA model (homogeneity of variance)
#    - Formula: SE = √(MSE / n)
#    - Same SE for all levels within a factor
#
# **Within-subjects factors** (pure within or within part of mixed):
#    - Uses cell-specific variance (allows heterogeneity)
#    - Formula: SE = √(var(level) / n)
#    - Different SE possible for each level
function _emmeans_se(
    dv::Symbol,
    effect_factors::Vector{Symbol},
    anova_result::AnovaResult,
    group::AbstractDataFrame,
    n_observations::Int,
)

    n_observations <= 1 && return 0.0, 1, 0.0, 1
    n_id = nrow(group)

    # Check if effect involves within factors
    has_within = any(f -> f ∈ anova_result.design.within_factors, effect_factors)

    # Get error term info from ANOVA table 
    all_factors_ordered = all_factors(anova_result.design)
    effect_name = _effect_name(effect_factors, all_factors_ordered)
    anova_info = _get_anova_row_info(anova_result, effect_name)

    isnothing(anova_info) &&
        throw(ArgumentError("Effect '$effect_name' not found in ANOVA table."))

    # Calculate SE using appropriate method based on effect type
    se = if !has_within # Pure between-subjects effect: use pooled MSE
        sqrt(anova_info.mse / n_observations)
    elseif isempty(anova_result.design.between_factors) # Pure within-subjects design: use cell-specific variance
        _se_within_subjects_pure(group, dv, n_id)
    else # Mixed design with within-subjects component: pool variance excluding between-subjects variance
        _se_within_subjects_mixed(group, dv, anova_result.design, n_id)
    end

    return se, anova_info.dfd, anova_info.mse, anova_info.dfn
end


function _aggregate_to_id_means(
    group::AbstractDataFrame,
    effect_factors::Vector{Symbol},
    design::DesignInfo,
    id::Symbol,
    dv::Symbol,
)
    all_within_in_effect =
        isempty(design.within_factors) ||
        all(f -> f in effect_factors, design.within_factors)
    all_within_in_effect && return group

    group_by_cols = unique(vcat([id], design.between_factors))
    return combine(groupby(group, group_by_cols), dv => mean => dv)
end
