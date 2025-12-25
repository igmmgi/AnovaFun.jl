# Between-subjects ANOVA
# What actually happens here?
# Step 1: Count how many subjects we have and what groups they are in
# Step 2: Calculate the grand mean (average of all data points)
# Step 3: Calculate within-group variance (how much people vary WITHIN each group)
#        This becomes our error term (SSd) - natural variation within groups
# Step 4: For each effect (main effects and interactions):
#        a) Calculate how much the group means differ from grand mean (SSn)
#        b) Calculate F = (SSn/DFn) / (SSd/DFd)
#        c) Get p-value from F distribution
# Step 5: Add effect size and significance markers
function _anova_between(data, dv, id, between, effect_size)

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
    n_id = nrow(data)
    grand_mean = mean(data[!, dv])

    # Factors/Levels/Conditions
    between_levels = _factor_levels(between, data)
    design_info = DesignInfo(:between, between, Symbol[], n_id)

    # Between-subjects error (pooled within-group variance)
    # For each group, calculate how much subjects vary around their group mean
    group_data = groupby(data, between)
    ss_error_between = 0.0
    for sub_data in group_data
        sub_values = sub_data[!, dv]
        ss_error_between += sum((sub_values .- mean(sub_values)) .^ 2)
    end
    df_error_between = n_id - length(group_data)
    df_error_between <= 0 && throw(
        ArgumentError(
            "Not enough observations to estimate residual variance for between-subjects ANOVA.",
        ),
    )

    # Get all factors in order for effect name ordering
    all_factors_ordered = all_factors(design_info)

    for n_factors = 1:length(between)
        for effect_factors in _combinations(between, n_factors)
            df_effect = prod(between_levels[f] - 1 for f in effect_factors)
            ss_effect = _between_effect_ss(effect_factors, data, dv, grand_mean)
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

    _finalize_results!(results, data, dv, design_info, effect_size, :none)

    return AnovaResult(
        data,
        dv,
        id,
        results,
        design_info,
        _univariate_model(data, dv, design_info),
    )
end

function _raw_ss_between(
    subset::Vector{Symbol},
    data::DataFrame,
    dv::Symbol,
    grand_mean::Float64,
)
    isempty(subset) && return 0.0
    group_stats = combine(groupby(data, subset), dv => mean => :mean, nrow => :n)
    return sum(row.n * (row.mean - grand_mean)^2 for row in eachrow(group_stats))
end

function _between_effect_ss(effect_factors, data, dv, grand_mean)
    _inclusion_exclusion(effect_factors, s -> _raw_ss_between(s, data, dv, grand_mean))
end

function _between_error_ss(data::DataFrame, dv::Symbol, between::Vector{Symbol})
    total_n = nrow(data)
    grand_mean = mean(data[!, dv])

    if isempty(between)
        ss_error = sum((data[!, dv] .- grand_mean) .^ 2)
        df_error = total_n - 1
    else
        grouped = groupby(data, between)
        ss_error = sum(
            combine(
                grouped,
                dv => (values -> sum((values .- mean(values)) .^ 2)) => :ss,
            ).ss,
        )
        df_error = total_n - length(grouped)
    end

    return ss_error, df_error
end
