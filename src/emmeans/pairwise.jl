"""
    pairwise(emmeans_result::EmmeansResult; by=nothing, adjust=:none)

Compute pairwise comparisons from an emmeans result.
Matches R's `pairs()` function from the emmeans package.

# Arguments
- `emmeans_result::EmmeansResult`: `EmmeansResult` object from `emmeans()`
- `by::Union{Symbol, Nothing}`: Effect to compute pairwise comparisons for (default: `nothing`, computes for all effects)
- `adjust::Symbol`: Method for p-value and confidence interval adjustment. Options: `:none` (default), `:bonferroni`, or `:sidak`

# Returns
A `PairwiseResult` object containing:
- `table::DataFrame`: Pairwise comparison results with columns:
- `Effect`: Name of the effect being compared
- `Contrast`: Description of the comparison (e.g., "Level1 - Level2")
- `Estimate`: Mean difference
- `SE`: Standard error of the difference
- `df`: Degrees of freedom
- `t`: t-statistic
- `p`: Unadjusted p-value
- `p_adj`: Adjusted p-value (if adjustment method specified)
- `Lower`: Lower bound of confidence interval
- `Upper`: Upper bound of confidence interval

The confidence level is taken from `emmeans_result.level`.

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
em = emmeans(result)
pw = pairwise(em)                     # all pairwise comparisons
pw = pairwise(em, by=:time)           # wpecific effect only
pw = pairwise(em, adjust=:bonferroni) # with correction 
```
"""
function pairwise(
    em::EmmeansResult;
    by::Union{Symbol,Nothing} = nothing,
    adjust::Symbol = :none,
)
    table = _pairs(em.means, em.anova, by, adjust, em.level)
    return PairwiseResult(table)
end

# Compute pairwise comparisons from emmeans result
function _pairs(
    means::DataFrame,
    anova::AnovaResult,
    by::Union{Symbol,Nothing},
    adjust::Symbol,
    level::Float64,
)

    adjustments = [:none, :bonferroni, :sidak]
    adjust ∉ adjustments &&
        throw(ArgumentError("adjust must be one of: $(join(adjustments, ", "))"))

    results = DataFrame(
        Effect = String[],
        Contrast = String[],
        Estimate = Float64[],
        SE = Float64[],
        df = Int[],
        t = Float64[],
        p = Float64[],
        p_adj = Float64[],
        Lower = Float64[],
        Upper = Float64[],
    )

    errors = select(anova.table, [:Effect, :DFn, :DFd, :MSE])
    effects_to_process = _determine_effects_to_process(means, by)
    for effect in effects_to_process
        _process_effect_for_pairwise!(results, effect, means, errors, anova, adjust, level)
    end

    return results
end

function _adjust_pvalues(p_values::Vector{Float64}, method::Symbol, n_comparisons::Int)
    method == :none && return copy(p_values)
    method == :bonferroni && return min.(p_values .* n_comparisons, 1.0)
    method == :sidak && return min.(1.0 .- (1.0 .- p_values) .^ n_comparisons, 1.0)
end

function _determine_effects_to_process(means::DataFrame, by::Union{Symbol,Nothing})

    unique_effects = filter(e -> e != "Grand Mean", unique(means.Effect))
    isnothing(by) && return unique_effects

    # Convert symbol to string for comparison
    by_str = string(by)
    by_str ∈ unique_effects && return [by_str]

    throw(
        ArgumentError(
            "Effect '$by' not found in emmeans result. Available: $(join(unique_effects, ", "))",
        ),
    )
end

function _get_anova_error_info(
    errors::DataFrame,
    effect::String,
    design::DesignInfo = nothing,
)
    effect_factors = _parse_effect_name(effect)
    if !isnothing(design) && !isempty(effect_factors)
        all_factors_ordered = all_factors(design)
        effect = _effect_name(effect_factors, all_factors_ordered)
    end

    anova_info = _get_anova_row_info(errors, effect)
    isnothing(anova_info) && throw(
        ArgumentError(
            "Effect '$effect' not found in errors table. Available: $(join(errors.Effect, ", "))",
        ),
    )

    df_error_anova = Int(anova_info.dfd)
    mse = anova_info.mse

    # For mixed designs: get between-subjects df from Intercept
    intercept_info =
        !isnothing(design) && design.type == :mixed ?
        _get_anova_row_info(errors, "Intercept") : nothing
    between_df = !isnothing(intercept_info) ? intercept_info.dfd : nothing

    return (df_error_anova = df_error_anova, mse = mse, between_df = between_df)
end

function _generate_pairwise_comparisons(
    effect_data::DataFrame,
    effect::String,
    anova::AnovaResult,
    error_info,
)
    comparisons = []
    n_levels = nrow(effect_data)

    for i = 1:n_levels
        for j = (i+1):n_levels
            comp = _single_comparison(
                effect_data[i, :],
                effect_data[j, :],
                effect,
                anova,
                error_info,
            )
            push!(comparisons, comp)
        end
    end

    return comparisons
end

function _add_comparison_results!(
    results::DataFrame,
    comparisons::Vector,
    adjust::Symbol,
    level::Float64,
)
    isempty(comparisons) && return

    alpha = 1 - level
    n_comparisons = length(comparisons)
    p_values = [c.p for c in comparisons]
    p_adjusted = _adjust_pvalues(p_values, adjust, n_comparisons)

    for (i, comp) in enumerate(comparisons)
        margin = _adjust_ci(comp.se, comp.df, adjust, n_comparisons, alpha)
        push!(
            results,
            (
                Effect = comp.effect,
                Contrast = comp.contrast,
                Estimate = comp.estimate,
                SE = comp.se,
                df = comp.df,
                t = comp.t,
                p = comp.p,
                p_adj = p_adjusted[i],
                Lower = comp.estimate - margin,
                Upper = comp.estimate + margin,
            ),
        )
    end
end

function _process_effect_for_pairwise!(
    results::DataFrame,
    effect::String,
    means::DataFrame,
    errors::DataFrame,
    anova::AnovaResult,
    adjust::Symbol,
    level::Float64,
)

    effect_data = filter(row -> row.Effect == effect, means)
    nrow(effect_data) < 2 && return

    # Get ANOVA error information
    error_info = _get_anova_error_info(errors, effect, anova.design)

    # Generate all pairwise comparisons
    comparisons = _generate_pairwise_comparisons(effect_data, effect, anova, error_info)

    # Add results with adjustments
    _add_comparison_results!(results, comparisons, adjust, level)
end

function _get_effect_design_info(effect_factors::Vector{Symbol}, design::DesignInfo)
    has_within = any(f -> f ∈ design.within_factors, effect_factors)
    has_between = any(f -> f ∈ design.between_factors, effect_factors)
    is_pure_within = design.type == :within || (has_within && !has_between)
    is_mixed = design.type == :mixed

    return (
        has_within = has_within,
        has_between = has_between,
        is_pure_within = is_pure_within,
        is_mixed = is_mixed,
    )
end

function _calculate_se_for_comparison(
    level_i,
    level_j,
    design_info,
    data,
    dv,
    id,
    effect,
    mse,
)
    if design_info.is_pure_within && !isnothing(data) && !isnothing(id) && !isnothing(dv)
        # Pure within-subjects: calculate SE from difference scores
        return _se_from_difference_scores(level_i, level_j, data, dv, id, effect)
    elseif design_info.is_mixed &&
           design_info.has_within &&
           hasproperty(level_i, :SE) &&
           hasproperty(level_j, :SE) &&
           level_i.SE > 0 &&
           level_j.SE > 0
        # Mixed design with within-subjects effect: use individual SE values
        return _se_from_individual_values(level_i, level_j)
    else
        # Between-subjects or fallback: use MSE-based formula
        return _se_from_mse(mse, level_i.N, level_j.N)
    end
end

function _calculate_df_for_comparison(
    design_info,
    effect::String,
    level_i,
    level_j,
    df_error_anova::Int,
    between_df::Union{Int,Nothing},
    design::DesignInfo,
)
    if design_info.is_pure_within
        return design.n_id - 1
    elseif design_info.is_mixed && design_info.has_within
        # Mixed design with within-subjects effect: R's emmeans uses between-subjects error df
        return something(between_df, df_error_anova)
    elseif design_info.is_mixed && !isnothing(between_df) && occursin(" × ", effect)
        # Mixed design interaction: check if comparing across between-subjects levels
        level_i_parts = split(level_i.Level, ", ")
        level_j_parts = split(level_j.Level, ", ")
        if length(level_i_parts) > 1 && length(level_j_parts) > 1
            between_i = level_i_parts[end]
            between_j = level_j_parts[end]
            return between_i != between_j ? between_df : df_error_anova
        end
    end
    # Default: use ANOVA error df
    return df_error_anova
end

function _single_comparison(
    level_i,
    level_j,
    effect::String,
    anova::AnovaResult,
    error_info,
)
    # Compute design info for this effect
    effect_factors = Symbol.(strip.(split(effect, " × ")))
    design_info = _get_effect_design_info(effect_factors, anova.design)

    estimate = level_i.Mean - level_j.Mean
    se_diff = _calculate_se_for_comparison(
        level_i,
        level_j,
        design_info,
        anova.data,
        anova.dv,
        anova.id,
        effect,
        error_info.mse,
    )
    df_for_comparison = _calculate_df_for_comparison(
        design_info,
        effect,
        level_i,
        level_j,
        error_info.df_error_anova,
        error_info.between_df,
        anova.design,
    )

    t_stat = estimate / se_diff
    p = 2 * cdf(TDist(df_for_comparison), -abs(t_stat))
    contrast = "$(level_i.Level) - $(level_j.Level)"

    return (
        effect = effect,
        contrast = contrast,
        estimate = estimate,
        se = se_diff,
        df = df_for_comparison,
        t = t_stat,
        p = p,
    )
end


function _filter_data_by_level_values(data::DataFrame, level_values::Dict{Symbol,String})
    filtered = data
    for (factor, value) in level_values
        filtered = filter(row -> row[factor] == value, filtered)
    end
    return filtered
end

function _se_from_difference_scores(level_i, level_j, model_data, dv, id, effect)::Float64
    level_i_vals = _parse_level_name(level_i.Level, effect)
    level_j_vals = _parse_level_name(level_j.Level, effect)

    (isnothing(level_i_vals) || isnothing(level_j_vals)) && return 0.0

    # Calculate difference scores for each subject
    diff_scores = Float64[]
    subjects = unique(model_data[!, id])

    for subj in subjects
        subj_data = filter(row -> row[id] == subj, model_data)
        level_i_data = _filter_data_by_level_values(subj_data, level_i_vals)
        level_j_data = _filter_data_by_level_values(subj_data, level_j_vals)

        if nrow(level_i_data) > 0 && nrow(level_j_data) > 0
            mean_i = mean(level_i_data[!, dv])
            mean_j = mean(level_j_data[!, dv])
            push!(diff_scores, mean_i - mean_j)
        end
    end

    length(diff_scores) > 1 || return 0.0
    return std(diff_scores) / sqrt(length(diff_scores))
end

# Helper function: Calculate SE from individual SE values (mixed designs)
_se_from_individual_values(level_i, level_j)::Float64 = sqrt(level_i.SE^2 + level_j.SE^2)

# Helper function: Calculate SE from MSE (between-subjects)
_se_from_mse(mse::Float64, n_i::Int, n_j::Int)::Float64 = sqrt(mse * (1 / n_i + 1 / n_j))

# Helper function to parse level name and extract factor values
# For simple effects: "F1_L1" -> Dict(:WF1 => "F1_L1")
# For interactions: "F1_L1, G1_L1" -> Dict(:WF1 => "F1_L1", :BF1 => "G1_L1")
function _parse_level_name(level_name::String, effect::String)
    try
        # Parse effect to get factor names
        effect_factors = Symbol.(strip.(split(effect, " × ")))

        # Parse level name
        level_parts = strip.(split(level_name, ","))

        if length(level_parts) == length(effect_factors)
            result = Dict{Symbol,String}()
            for (i, factor) in enumerate(effect_factors)
                result[factor] = strip(level_parts[i])
            end
            return result
        end
    catch
        return nothing
    end
    return nothing
end
