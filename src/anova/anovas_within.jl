# Within-subjects (Repeated Measures) ANOVA
# What actually happens here?
# Step 1: Calculate grand mean (average of all measurements)
# Step 2: Calculate each subject's mean (average across all their measurements)
#        Subject variation = how much subjects differ from each other overall
# Step 3: Test the Intercept:
#        - Is the grand mean significantly different from zero?
#        - Error = between-subject variation (subjects differ from each other)
# Step 4: For each within-subject effect (e.g., Time, Condition):
#        a) Calculate effect SS: How much do the condition means differ?
#        b) Calculate error SS: Subject×Condition interaction (do subjects respond differently?)
#        c) F = effect / error, where error = how inconsistently subjects respond to conditions
# Step 5: Add effect size and significance markers
function _anova_within(data, dv, id, within, effect_size, correction)

    results = DataFrame(
        Effect = String[],
        DFn = Int[],
        DFd = Int[],
        SSn = Float64[],
        SSd = Float64[],
        MSE = Float64[],
        F = Float64[],
        p = Float64[],
    )
    n_id = length(unique(data[!, id]))
    grand_mean = mean(data[!, dv])
    id_means = combine(groupby(data, id), dv => mean => :subj_mean)

    # Factors/Levels/Conditions
    within_factors = within
    within_levels = _factor_levels(within_factors, data)
    n_conditions = prod(values(within_levels))
    design_info = DesignInfo(:within, Symbol[], within_factors, n_id)

    # SS for intercept = n_id * n_conditions * grand_mean^2
    ss_intercept = n_id * n_conditions * grand_mean^2

    # Error SS for intercept = subject variance (SS between subjects)
    df_error_intercept = n_id - 1
    ss_error_intercept = n_conditions * sum((id_means.subj_mean .- grand_mean) .^ 2)

    ms_error_intercept = ss_error_intercept / df_error_intercept
    F_intercept = ss_intercept / ms_error_intercept
    p_intercept = 1.0 - cdf(FDist(1, df_error_intercept), F_intercept)

    push!(
        results,
        (
            Effect = "Intercept",
            DFn = 1,
            DFd = df_error_intercept,
            SSn = ss_intercept,
            SSd = ss_error_intercept,
            MSE = ms_error_intercept,
            F = F_intercept,
            p = p_intercept,
        ),
    )

    # Get all factors in order for effect name ordering
    all_factors_ordered = all_factors(design_info)

    # For each effect, error = Subject × Effect interaction 
    for effect_factors in _factor_subsets(within_factors)
        ss_effect = _interaction_ss(
            effect_factors,
            within_factors,
            within_levels,
            data,
            dv,
            n_id,
            grand_mean,
        )
        df_effect = prod(within_levels[f] - 1 for f in effect_factors)
        ss_error = _effect_error_ss(
            effect_factors,
            data,
            dv,
            id,
            grand_mean,
            results,
            all_factors_ordered,
        )
        df_error = df_effect * (n_id - 1)
        _push_result!(
            results,
            _effect_name(effect_factors, all_factors_ordered),
            df_effect,
            df_error,
            ss_effect,
            ss_error,
        )
    end

    _finalize_results!(
        results,
        data,
        dv,
        design_info,
        effect_size,
        correction,
        within_factors,
        id,
    )

    return AnovaResult(
        data,
        dv,
        id,
        results,
        design_info,
        _univariate_model(data, dv, design_info),
    )
end

function _raw_ss_within_interaction(
    subset::Vector{Symbol},
    data::DataFrame,
    dv::Symbol,
    n_id::Int,
    grand_mean::Float64,
    all_within::Vector{Symbol},
    within_levels::Dict{Symbol,Int},
)
    isempty(subset) && return 0.0
    multiplier = prod(within_levels[f] for f in setdiff(all_within, subset); init = 1)
    means = combine(groupby(data, subset), dv => mean => :mean).mean
    return n_id * multiplier * sum((means .- grand_mean) .^ 2)
end

function _interaction_ss(factors, within, within_levels, data, dv, n_id, grand_mean)
    _inclusion_exclusion(
        factors,
        s -> _raw_ss_within_interaction(
            s,
            data,
            dv,
            n_id,
            grand_mean,
            within,
            within_levels,
        ),
    )
end

function _subject_effect_ss(
    subset::Vector{Symbol},
    data::DataFrame,
    dv::Symbol,
    id::Symbol,
    grand_mean::Float64,
)
    group_cols = vcat([id], subset)
    means_df = combine(groupby(data, group_cols), dv => mean => :mean)
    n_obs_per_cell = nrow(data) ÷ nrow(means_df)
    return n_obs_per_cell * sum((means_df.mean .- grand_mean) .^ 2)
end

function _subject_effect_inclusion_exclusion(
    effect_factors::Vector{Symbol},
    data::DataFrame,
    dv::Symbol,
    id::Symbol,
    grand_mean::Float64,
)
    subsets = _factor_subsets(effect_factors, include_empty = true)
    k = length(effect_factors)
    sum_ss = 0.0
    for subset in subsets
        coeff = (-1)^(k - length(subset))
        sum_ss += coeff * _subject_effect_ss(subset, data, dv, id, grand_mean)
    end
    return sum_ss
end

function _raw_effect_ss(
    effect_factors::Vector{Symbol},
    data::DataFrame,
    dv::Symbol,
    grand_mean::Float64,
)
    effect_means = combine(groupby(data, effect_factors), dv => mean => :mean)
    n_obs_per_cell = nrow(data) ÷ nrow(effect_means)
    return n_obs_per_cell * sum((effect_means.mean .- grand_mean) .^ 2)
end

function _sum_lower_order_ssn(
    effect_factors::Vector{Symbol},
    results::DataFrame,
    factor_order::Vector{Symbol} = Symbol[],
)
    k = length(effect_factors)
    (k <= 1 || isempty(results)) && return 0.0

    subsets = _factor_subsets(effect_factors, include_empty = true)
    lower_ssn = 0.0
    for subset in subsets
        (isempty(subset) || length(subset) == k) && continue
        effect_name = _effect_name(subset, factor_order)
        idx = findfirst(row -> row.Effect == effect_name, eachrow(results))
        !isnothing(idx) && (lower_ssn += results[idx, :SSn])
    end
    return lower_ssn
end

function _effect_error_ss(
    effect_factors::Vector{Symbol},
    data::DataFrame,
    dv::Symbol,
    id::Symbol,
    grand_mean::Float64,
    results::DataFrame,
    factor_order::Vector{Symbol} = Symbol[],
)
    isempty(effect_factors) && return 0.0

    inclusion_exclusion_ss =
        _subject_effect_inclusion_exclusion(effect_factors, data, dv, id, grand_mean)
    raw_ss_effect = _raw_effect_ss(effect_factors, data, dv, grand_mean)
    lower_ssn = _sum_lower_order_ssn(effect_factors, results, factor_order)

    return inclusion_exclusion_ss - raw_ss_effect + lower_ssn
end
