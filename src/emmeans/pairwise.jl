"""
    pairwise(emmeans_result::EmmeansResult; simple=nothing, adjust=:none)

Compute pairwise comparisons from an emmeans result.
Matches R's `pairs()` function from the emmeans package.

# Arguments
- `emmeans_result::EmmeansResult`: `EmmeansResult` object from `emmeans()`
- `simple::Union{Symbol, Nothing}`: Simple contrasts specification (default: `nothing`):
  - `nothing`: All pairwise comparisons across all cell means (like R's `pairs(em)`)
  - `:each`: Simple contrasts for each factor within levels of other factors
  - `:FactorName`: Simple contrasts for specified factor within levels of other factors
- `adjust::Symbol`: Method for p-value and confidence interval adjustment. Options: `:none` (default), `:bonferroni`, or `:sidak`

# Returns
A `PairwiseResult` object containing:
- `table::DataFrame`: Pairwise comparison results with columns:
  - `Context`: Conditioning context (e.g., "CurrentCongruency = Congruent") for simple contrasts
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
result = anova(data, :dv, :id, within=[:A, :B])
em = emmeans(result, by=[:A, :B])

# All pairwise comparisons across all cell means
pw = pairwise(em)

# Simple contrasts for factor A within levels of B
pw = pairwise(em, simple=:A)

# Simple contrasts for each factor
pw = pairwise(em, simple=:each)

# With p-value correction
pw = pairwise(em, adjust=:bonferroni)
```
"""
function pairwise(
    em::EmmeansResult;
    simple::Union{Symbol,Nothing} = nothing,
    adjust::Symbol = :none,
)
    table = _pairs(em.means, em.anova, simple, adjust, em.level)
    return PairwiseResult(table)
end

# Compute pairwise comparisons from emmeans result
function _pairs(
    means::DataFrame,
    anova::AnovaResult,
    simple::Union{Symbol,Nothing},
    adjust::Symbol,
    level::Float64,
)

    adjustments = [:none, :bonferroni, :sidak]
    adjust ∉ adjustments &&
        throw(ArgumentError("adjust must be one of: $(join(adjustments, ", "))"))

    results = DataFrame(
        Context = String[],
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
    
    if isnothing(simple)
        # Mode 1: All pairwise comparisons across all cell means
        _process_all_pairwise!(results, means, errors, anova, adjust, level)
    elseif simple == :each
        # Mode 2: Simple contrasts for each factor
        _process_simple_each!(results, means, errors, anova, adjust, level)
    else
        # Mode 3: Simple contrasts for specific factor
        _process_simple_factor!(results, means, errors, anova, simple, adjust, level)
    end

    return results
end

function _adjust_pvalues(p_values::Vector{Float64}, method::Symbol, n_comparisons::Int)
    method == :none && return copy(p_values)
    method == :bonferroni && return min.(p_values .* n_comparisons, 1.0)
    method == :sidak && return min.(1.0 .- (1.0 .- p_values) .^ n_comparisons, 1.0)
end

# Get the highest-order effect (the one with most factors, typically the interaction)
function _get_highest_order_effect(means::DataFrame)::String
    unique_effects = filter(e -> e != "Grand Mean", unique(means.Effect))
    isempty(unique_effects) && return ""
    
    # Count factors in each effect (by counting " × ")
    factor_counts = [(e, count("×", e) + 1) for e in unique_effects]
    sort!(factor_counts, by=x -> x[2], rev=true)
    return factor_counts[1][1]
end

# Parse effect name to get factor symbols
function _parse_effect_name(effect::String)::Vector{Symbol}
    effect == "Grand Mean" && return Symbol[]
    return Symbol.(strip.(split(effect, " × ")))
end

# Mode 1: All pairwise comparisons across all cell means
function _process_all_pairwise!(
    results::DataFrame,
    means::DataFrame,
    errors::DataFrame,
    anova::AnovaResult,
    adjust::Symbol,
    level::Float64,
)
    effect = _get_highest_order_effect(means)
    isempty(effect) && return
    
    effect_data = filter(row -> row.Effect == effect, means)
    nrow(effect_data) < 2 && return
    
    error_info = _get_anova_error_info(errors, effect, anova.design)
    comparisons = _generate_pairwise_comparisons(effect_data, effect, anova, error_info)
    _add_comparison_results!(results, comparisons, "", effect, adjust, level)
end

# Mode 2: Simple contrasts for each factor
function _process_simple_each!(
    results::DataFrame,
    means::DataFrame,
    errors::DataFrame,
    anova::AnovaResult,
    adjust::Symbol,
    level::Float64,
)
    effect = _get_highest_order_effect(means)
    isempty(effect) && return
    
    effect_factors = _parse_effect_name(effect)
    length(effect_factors) < 1 && return
    
    # For each factor, compute simple contrasts
    for simple_factor in effect_factors
        _process_simple_factor!(results, means, errors, anova, simple_factor, adjust, level)
    end
end

# Mode 3: Simple contrasts for specific factor within levels of other factors
function _process_simple_factor!(
    results::DataFrame,
    means::DataFrame,
    errors::DataFrame,
    anova::AnovaResult,
    simple_factor::Symbol,
    adjust::Symbol,
    level::Float64,
)
    effect = _get_highest_order_effect(means)
    isempty(effect) && return
    
    effect_factors = _parse_effect_name(effect)
    
    # Validate that simple_factor is in the effect
    if simple_factor ∉ effect_factors
        available = join(string.(effect_factors), ", ")
        throw(ArgumentError("Factor '$simple_factor' not found in effect. Available: $available"))
    end
    
    # If only one factor, no conditioning needed
    if length(effect_factors) == 1
        _process_all_pairwise!(results, means, errors, anova, adjust, level)
        return
    end
    
    effect_data = filter(row -> row.Effect == effect, means)
    conditioning_factors = filter(f -> f != simple_factor, effect_factors)
    
    # Get error info for this effect
    error_info = _get_anova_error_info(errors, effect, anova.design)
    
    # Get unique levels of conditioning factors
    conditioning_levels = _get_conditioning_levels(effect_data, conditioning_factors)
    
    for cond_level in conditioning_levels
        # Filter data to this conditioning level
        filtered_data = _filter_by_conditioning(effect_data, conditioning_factors, cond_level)
        nrow(filtered_data) < 2 && continue
        
        # Create context string (e.g., "CurrentCongruency = Congruent")
        context = _format_context(conditioning_factors, cond_level)
        
        # Generate comparisons for this subset
        # Use the full effect name for proper SE calculation (level names are in interaction format)
        comparisons = _generate_pairwise_comparisons(filtered_data, effect, anova, error_info)
        _add_comparison_results!(results, comparisons, context, string(simple_factor), adjust, level)
    end
end

# Get unique combinations of conditioning factor levels
function _get_conditioning_levels(effect_data::DataFrame, conditioning_factors::Vector{Symbol})
    levels_list = Vector{Vector{String}}()
    
    for row in eachrow(effect_data)
        level_parts = strip.(split(row.Level, ","))
        effect_factors = _parse_effect_name(row.Effect)
        
        # Extract values for conditioning factors only
        cond_values = String[]
        for (i, factor) in enumerate(effect_factors)
            if factor in conditioning_factors
                push!(cond_values, level_parts[i])
            end
        end
        
        if cond_values ∉ levels_list
            push!(levels_list, cond_values)
        end
    end
    
    return levels_list
end

# Filter effect data by conditioning level
function _filter_by_conditioning(
    effect_data::DataFrame,
    conditioning_factors::Vector{Symbol},
    cond_level::Vector{String},
)
    return filter(effect_data) do row
        level_parts = strip.(split(row.Level, ","))
        effect_factors = _parse_effect_name(row.Effect)
        
        cond_idx = 1
        for (i, factor) in enumerate(effect_factors)
            if factor in conditioning_factors
                if level_parts[i] != cond_level[cond_idx]
                    return false
                end
                cond_idx += 1
            end
        end
        return true
    end
end

# Format context string for simple contrasts
function _format_context(conditioning_factors::Vector{Symbol}, cond_level::Vector{String})::String
    parts = [string(f) * " = " * cond_level[i] for (i, f) in enumerate(conditioning_factors)]
    return join(parts, ", ")
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
    context::String,
    effect_name::String,
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
                Context = context,
                Effect = effect_name,
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
