# Mixed Design ANOVA 
# What actually happens here?
# NB: Mixed designs are much more complex!
# Step 1: Identify subjects and their groups (between-subjects factors)
# Step 2: Calculate grand mean collapsing across within-subject measurements per person
# Step 3: Calculate between-subjects error:
#        - How much do people vary within their groups?
#        - This is our error term for between-subjects effects
# Step 4: Test Intercept using between-subjects error
# Step 5: Test between-subjects effects (e.g., Group, Gender):
#        - Do group means differ from grand mean?
#        - Error = within-group variation (same as Step 3)
# Step 6: Test within-subjects effects (e.g., Time, Condition):
#        - Do condition means differ?
#        - Error = Subject × Condition interaction (within groups)
# Step 7: Test interactions between within and between factors:
#        - E.g., does the Time effect differ by Group?
#        - Error = Subject × Time interaction (within groups)
function _anova_mixed(data, dv, id, within, between, effect_size, correction)

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

    # Factors/Levels/Conditions
    within_factors = within
    between_factors = between
    within_levels = _factor_levels(within_factors, data)
    between_levels = _factor_levels(between_factors, data)
    within_cells_multiplier = prod(values(within_levels))

    # Calculate grand means collapsing across within-factor levels
    between_data = combine(groupby(data, vcat([id], between_factors)), dv => mean => dv)
    n_id = nrow(between_data)
    grand_mean_between = mean(between_data[!, dv])

    design_info = DesignInfo(:mixed, between_factors, within_factors, n_id)
    all_factors_ordered = all_factors(design_info)

    # Calculate between-subjects error
    ss_error_between, df_error_between =
        _between_error_ss(between_data, dv, between_factors)
    ss_error_between *= within_cells_multiplier
    df_error_between <= 0 && throw(
        ArgumentError(
            "Not enough observations to estimate between-subject error variance.",
        ),
    )

    # Intercept 
    ss_intercept = n_id * grand_mean_between^2 * within_cells_multiplier
    F_intercept = ss_intercept / (ss_error_between / df_error_between)
    p_intercept = 1.0 - cdf(FDist(1, df_error_between), F_intercept)

    mse_intercept = ss_error_between / df_error_between
    push!(
        results,
        (
            Effect = "Intercept",
            DFn = 1,
            DFd = df_error_between,
            SSn = ss_intercept,
            SSd = ss_error_between,
            MSE = mse_intercept,
            F = F_intercept,
            p = p_intercept,
        ),
    )

    # between-subjects effects (Error = between-subjects error)
    for n_factors = 1:length(between_factors)
        for effect_factors in _combinations(between_factors, n_factors)
            ss_effect =
                _general_effect_ss(
                    effect_factors,
                    between_data,
                    dv,
                    id,
                    grand_mean_between,
                    Symbol[],
                ) * within_cells_multiplier
            df_effect = _calculate_df_from_levels(effect_factors, between_levels)
            _push_result!(
                results,
                _effect_name(effect_factors, all_factors_ordered),
                df_effect,
                df_error_between,
                ss_effect,
                ss_error_between,
            )
        end
    end

    # Test within-subjects effects (e.g., Time)
    # Error = Subject × Time interaction 
    for n_factors = 1:length(within_factors)
        for within_subset in _combinations(within_factors, n_factors)
            effect_data =
                _aggregate_for_effect(data, id, within_subset, dv, between_factors)
            grand_mean_effect = mean(effect_data[!, dv])
            ss_effect = _general_effect_ss(
                within_subset,
                effect_data,
                dv,
                id,
                grand_mean_effect,
                within_subset,
            )
            remaining_within = setdiff(within_factors, within_subset)
            scale_factor = _calculate_scale_factor(remaining_within, within_levels)
            ss_effect *= scale_factor
            df_within = _calculate_df_from_levels(within_subset, within_levels)
            df_within == 0 && continue
            df_error = df_within * df_error_between
            ss_error = _within_error_ss(
                within_subset,
                remaining_within,
                scale_factor,
                effect_data,
                data,
                dv,
                id,
                between_factors,
            )
            _push_result!(
                results,
                _effect_name(within_subset, all_factors_ordered),
                df_within,
                df_error,
                ss_effect,
                ss_error,
            )
        end
    end

    # Test interactions between between and within factors (e.g., Group × Time)
    # Error = Subject × Within interaction (within groups)
    for between_subset in _factor_subsets(between_factors)
        for within_subset in _factor_subsets(within_factors)
            effect_factors = vcat(between_subset, within_subset)
            effect_data =
                _aggregate_for_effect(data, id, effect_factors, dv, between_factors)
            grand_mean_effect = mean(effect_data[!, dv])
            ss_effect = _general_effect_ss(
                effect_factors,
                effect_data,
                dv,
                id,
                grand_mean_effect,
                within_subset,
            )
            remaining_within = setdiff(within_factors, within_subset)
            scale_factor = _calculate_scale_factor(remaining_within, within_levels)
            ss_effect *= scale_factor

            df_between = _calculate_df_from_levels(between_subset, between_levels)
            df_within = _calculate_df_from_levels(within_subset, within_levels)
            df_effect = df_between * df_within
            df_error = df_within * df_error_between
            ss_error = _within_error_ss(
                within_subset,
                remaining_within,
                scale_factor,
                effect_data,
                data,
                dv,
                id,
                between_factors,
                between_subset,
            )
            _push_result!(
                results,
                _effect_name(effect_factors, all_factors_ordered),
                df_effect,
                df_error,
                ss_effect,
                ss_error,
            )
        end
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

function _aggregate_for_effect(
    data::DataFrame,
    id::Symbol,
    effect_factors::Vector{Symbol},
    dv::Symbol,
    between_factors::Vector{Symbol},
)
    # Build unique list of grouping columns
    group_cols = unique(vcat([id], between_factors, effect_factors))
    return combine(groupby(data, group_cols), dv => mean => dv)
end

function _calculate_df_from_levels(factors::Vector{Symbol}, levels::Dict{Symbol,Int})
    isempty(factors) && return 1
    return prod(levels[f] - 1 for f in factors)
end

function _calculate_scale_factor(
    remaining_factors::Vector{Symbol},
    levels::Dict{Symbol,Int},
)
    return prod(levels[f] for f in remaining_factors; init = 1)
end

function _raw_general_ss(
    factor_subset::Vector{Symbol},
    data::DataFrame,
    dv::Symbol,
    id::Symbol,
    grand_mean::Float64,
    effect_factors::Vector{Symbol},
    within_effect_factors::Vector{Symbol},
)
    isempty(factor_subset) && return 0.0
    group_stats = combine(groupby(data, factor_subset)) do sdf
        (; n_id = length(unique(sdf[!, id])), mean = mean(sdf[!, dv]))
    end
    complement_within =
        [f for f in setdiff(effect_factors, factor_subset) if f in within_effect_factors]
    within_multiplier =
        prod(length(unique(data[!, f])) for f in complement_within; init = 1)
    return sum(
        group_stats.n_id .* within_multiplier .* (group_stats.mean .- grand_mean) .^ 2,
    )
end

_general_effect_ss(effect_factors, data, dv, id, grand_mean, within_effect_factors) =
    _inclusion_exclusion(
        effect_factors,
        s -> _raw_general_ss(
            s,
            data,
            dv,
            id,
            grand_mean,
            effect_factors,
            within_effect_factors,
        ),
    )

function _mixed_residuals(
    group_data::AbstractDataFrame,
    dv::Symbol,
    id::Symbol,
    between_part::Vector{Symbol},
    within_part::Vector{Symbol},
)
    # Subject means
    subj_means = combine(groupby(group_data, [id]), dv => mean => :subj_mean)
    df = leftjoin(group_data, subj_means, on = [id])

    # Cell means (combination of between_part and within_part)
    cell_cols = isempty(between_part) ? within_part : vcat(between_part, within_part)
    cell_means = combine(groupby(group_data, cell_cols), dv => mean => :cell_mean)
    df = leftjoin(df, cell_means, on = cell_cols)

    # Between-part means (or overall mean if no between_part)
    if isempty(between_part)
        df[!, :between_mean] = fill(mean(group_data[!, dv]), nrow(df))
    else
        between_means =
            combine(groupby(group_data, between_part), dv => mean => :between_mean)
        df = leftjoin(df, between_means, on = between_part)
    end

    # Residuals: dv - subject_mean - cell_mean + between_mean
    return df[!, dv] .- df.subj_mean .- df.cell_mean .+ df.between_mean
end

function _mixed_error_ss(
    effect_data::DataFrame,
    dv::Symbol,
    id::Symbol,
    between_part::Vector{Symbol},
    within_part::Vector{Symbol},
    all_between::Vector{Symbol},
)
    groups =
        isempty(all_between) ? [effect_data] :
        [g for g in groupby(effect_data, all_between)]
    total = 0.0
    for group in groups
        residuals = _mixed_residuals(group, dv, id, between_part, within_part)
        total += sum(residuals .^ 2)
    end
    return total
end

function _within_error_ss(
    within_subset::Vector{Symbol},
    remaining_within::Vector{Symbol},
    scale_factor::Int,
    effect_data::DataFrame,
    full_data::DataFrame,
    dv::Symbol,
    id::Symbol,
    between_factors::Vector{Symbol},
    between_subset::Vector{Symbol} = Symbol[],
)
    if isempty(remaining_within) && length(within_subset) > 1
        # Pure within×within interaction: use multivariate approach
        return _within_within_error_multivariate(
            within_subset,
            full_data,
            dv,
            id,
            between_factors,
        )
    else # Single within factor or has remaining factors: use standard approach
        ss_error_base = _mixed_error_ss(
            effect_data,
            dv,
            id,
            between_subset,
            within_subset,
            between_factors,
        )
        return isempty(remaining_within) ? ss_error_base : ss_error_base * scale_factor
    end
end

function _within_within_error_multivariate(
    within_factors::Vector{Symbol},
    data::DataFrame,
    dv::Symbol,
    id::Symbol,
    between_factors::Vector{Symbol},
)
    P = _interaction_contrast_matrix(within_factors, data)

    if !isempty(between_factors)
        # Compute SSPE within each between-subjects group and sum
        total_ssd = 0.0
        for bf_group in groupby(data, between_factors)
            # Use unified matrix building function from utils.jl
            Y = _subject_condition_matrix(
                bf_group,
                dv,
                id,
                within_factors;
                aggregate = false,
            )
            SSPE = _sspe(Y)
            total_ssd += _multivariate_ssd(SSPE, P)
        end
        return total_ssd
    else # No between factors - single group
        Y = _subject_condition_matrix(data, dv, id, within_factors; aggregate = false)
        SSPE = _sspe(Y)
        return _multivariate_ssd(SSPE, P)
    end
end

function _interaction_contrast_matrix(within_factors::Vector{Symbol}, data::DataFrame)
    n_levels = [length(unique(data[!, f])) for f in within_factors]
    contrasts = [_contrast_matrix(n) for n in n_levels]
    result = contrasts[1]
    for i = 2:length(contrasts)
        result = kron(result, contrasts[i])
    end
    return result
end
