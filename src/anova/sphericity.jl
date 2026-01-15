"""
    sphericity_check(result::AnovaResult)

Mauchly's test for sphericity for within-subjects designs with factor with more than two levels.

Tests whether the assumption of sphericity holds in repeated measures ANOVA. Sphericity
requires that the variances of the differences between all pairs of within-subject conditions
are equal.

# Arguments
- `result::AnovaResult`: ANOVA result object 

# Returns
A `DataFrame` with columns:
- `Effect`: Name of the within-subjects effect
- `W`: Mauchly's W statistic
- `p`: p-value

# Examples
```julia
result = anova(data, :dv, :subject, within=[:time])
sphericity_check(result)
```
"""
function sphericity_check(result::AnovaResult)

    wf = within_factors(result)
    isempty(wf) && throw(
        ArgumentError("Sphericity test requires at least one within-subjects factor."),
    )

    # Compute Mauchly's test for each within-subjects effect
    results = DataFrame(Effect = String[], W = Float64[], p = Float64[])

    within_effects = filter(row -> _is_within_effect_in_table(row.Effect, wf), result.table)
    for row in eachrow(within_effects)
        effect_factors = _parse_effect_name(row.Effect)
        W, p = _mauchly_test(result.data, result.dv, result.id, effect_factors)
        push!(results, (Effect = row.Effect, W = W, p = p))
    end

    return results
end


"""
    sphericity_correction(result::AnovaResult; type::Symbol=:GG)

Apply sphericity correction to an existing ANOVA result.

This function applies Greenhouse-Geisser or Huynh-Feldt correction to within-subjects effects
in an ANOVA result. This is useful if you want to apply a different correction method than
was used initially, or if you want to apply correction to a result that was computed without it.

# Arguments
- `result::AnovaResult`: ANOVA result object to apply correction to
- `type::Symbol`: Correction type. Options: `:GG` (Greenhouse-Geisser, default) or `:HF` (Huynh-Feldt)

# Returns
A new `AnovaResult` object with sphericity correction applied. The correction modifies:
- `ε` (epsilon) column: Added or updated with correction factor
- `DFn` and `DFd`: Adjusted by epsilon (may become non-integer)
- `p`: Recalculated using corrected degrees of freedom
- `MSE`: Recalculated based on corrected `DFd`

# Examples
```julia
# Run ANOVA without correction
result = anova(data, :dv, :subject, within=[:time], correction=:none)
result_gg = sphericity_correction(result, type=:GG) # Greenhouse-Geisser correction
result_hf = sphericity_correction(result, type=:HF) # Huynh-Feldt correction
```

# Note
This function requires at least one within-subjects factor. For between-subjects designs,
this function will return the result unchanged.
"""
function sphericity_correction(result::AnovaResult; type::Symbol = :GG)
    type ∉ [:GG, :HF] && throw(ArgumentError("type must be :GG or :HF"))

    # Check if there are within-subjects factors
    within_factors = result.design.within_factors
    isempty(within_factors) && return result  # No correction needed for between-subjects

    # Create a copy of the table to modify
    corrected_table = copy(result.table)

    # Apply correction
    _sphericity_correction!(
        corrected_table,
        result.data,
        result.dv,
        result.id,
        within_factors,
        type,
    )

    # Return new AnovaResult with corrected table
    return AnovaResult(
        result.data,
        result.dv,
        result.id,
        corrected_table,
        result.design,
        result.model,
    )
end


function _mauchly_test(data::DataFrame, dv::Symbol, id::Symbol, factors::Vector{Symbol})
    components = _get_sphericity_components(data, dv, id, factors)
    isnothing(components) && return PERFECT_SPHERICITY_W, PERFECT_SPHERICITY_P

    u_matrix, n_contrasts, df, n_conditions = components

    # Sphericity test requires at least 2 degrees of freedom (n_contrasts >= 2)
    # For n_contrasts = 1 (2 levels), sphericity is automatically satisfied
    if n_contrasts < MIN_DF_FOR_SPHERICITY
        return PERFECT_SPHERICITY_W, PERFECT_SPHERICITY_P  # Sphericity automatically satisfied (W=1.0, p=1.0)
    end

    # Compute W statistic
    det_u = det(u_matrix)
    trace_u = tr(u_matrix)
    logW = log(det_u) - n_contrasts * log(trace_u / n_contrasts)
    W = exp(logW)

    # Compute p-value with Bartlett correction
    # Formula from R's stats:::mauchly.test.SSD 
    rho = 1.0 - (2 * n_contrasts^2 + n_contrasts + 2) / (6 * n_contrasts * df)

    # w2 correction factor (second-order correction)
    w2 =
        (n_contrasts + 2) *
        (n_contrasts - 1) *
        (n_contrasts - 2) *
        (2 * n_contrasts^3 + 6 * n_contrasts^2 + 3 * n_conditions + 2) /
        (288 * (df * n_contrasts * rho)^2)

    # Test statistic (Bartlett-corrected chi-square approximation)
    z = -df * rho * logW

    # Degrees of freedom for chi-square test
    f = n_contrasts * (n_contrasts + 1) / 2 - 1

    # Ensure f > 0 (should be guaranteed by n_contrasts >= 2 check above, but double-check)
    f <= 0 && return PERFECT_SPHERICITY_W, PERFECT_SPHERICITY_P

    # p-value with second-order correction
    Pr1 = 1.0 - cdf(Chisq(f), z)
    Pr2 = 1.0 - cdf(Chisq(f + 4), z)  # 4 is from Bartlett correction formula (R stats package)
    p_value = Pr1 + w2 * (Pr2 - Pr1)

    # Ensure p-value is in valid range
    p_value = max(0.0, min(1.0, p_value))

    return W, p_value
end


function _compute_SSPE(data::Matrix{Float64})
    means = vec(mean(data, dims = 1))
    Y_centered = similar(data)
    for j = 1:size(data, 2)
        @views Y_centered[:, j] .= data[:, j] .- means[j]
    end
    return Y_centered' * Y_centered
end

function _build_contrast_matrix_for_effect(factors::Vector{Symbol}, levels::Vector, k::Int)
    length(factors) == 1 && return _contrast_matrix(k)
    n_levels_per_factor = length.(levels)
    factor_contrast_matrices = [_contrast_matrix(n) for n in n_levels_per_factor]
    combined_contrast_matrix = factor_contrast_matrices[1]
    for i = 2:length(factor_contrast_matrices)
        combined_contrast_matrix =
            kron(combined_contrast_matrix, factor_contrast_matrices[i])
    end
    return combined_contrast_matrix
end

function _get_sphericity_components(
    data::DataFrame,
    dv::Symbol,
    id::Symbol,
    factors::Vector{Symbol},
)
    # Get unique subjects and condition levels
    subject_ids = sort(unique(data[!, id]))
    factor_levels = [sort(collect(unique(data[!, f]))) for f in factors]
    n_cells = prod(length.(factor_levels))

    # Sphericity test requires at least 3 levels/cells to be meaningful
    # For 2 levels, sphericity is automatically satisfied (returns nothing, handled in _mauchly_test)
    n_cells < MIN_LEVELS_FOR_SPHERICITY && return nothing

    # Build data matrix and compute SSPE using unified function from utils.jl
    subject_condition_matrix =
        _subject_condition_matrix(data, dv, id, factors; aggregate = true)
    sspe_matrix = _compute_SSPE(subject_condition_matrix)

    # Build contrast matrix and compute U
    contrast_matrix = _build_contrast_matrix_for_effect(factors, factor_levels, n_cells)
    transformed_sspe = contrast_matrix' * sspe_matrix * contrast_matrix
    p_transpose_p = contrast_matrix' * contrast_matrix
    u_matrix = p_transpose_p \ transformed_sspe

    n_contrasts = size(transformed_sspe, 1)
    n_conditions = size(contrast_matrix, 1)
    df = length(subject_ids) - 1

    return u_matrix, n_contrasts, df, n_conditions
end

function _is_within_effect_in_table(effect_name::String, within_factors::Vector{Symbol})

    effect_name == "Intercept" && return false # skip intercept

    # Parse effect name to get factors
    effect_factors = _parse_effect_name(effect_name)

    # Check if all factors in the effect are within-subjects factors
    return !isempty(effect_factors) && all(f in within_factors for f in effect_factors)
end

function _compute_epsilon(
    u_matrix::Matrix{Float64},
    n_contrasts::Int,
    df::Int,
    type::Symbol,
)

    # calculate GG epsilon as needed for both
    trace_u = tr(u_matrix)
    sum_squared_elements = sum(u_matrix .* u_matrix')
    gg_epsilon = trace_u^2 / (n_contrasts * sum_squared_elements)

    type == :GG && return gg_epsilon

    # else must be HF
    n_subjects = df + 1
    numerator = n_subjects * n_contrasts * gg_epsilon - 2
    denominator = n_contrasts * (n_subjects - 1 - n_contrasts * gg_epsilon)
    hf_epsilon = numerator / denominator
    return min(1.0, hf_epsilon)  # Cap at 1.0
end

function _sphericity_correction!(
    table::DataFrame,
    data::DataFrame,
    dv::Symbol,
    id::Symbol,
    within_factors::Vector{Symbol},
    type::Symbol,
)
    type ∉ [:GG, :HF] && throw(ArgumentError("type must be :GG or :HF"))

    # Initialize epsilon column
    table[!, :ε] = fill(NaN, nrow(table))

    # Set values for Intercept (no correction needed, if present)
    intercept_idx = findfirst(table.Effect .== "Intercept")
    !isnothing(intercept_idx) && (table[intercept_idx, :ε] = 1.0)

    # Convert DFn and DFd to Float64 to allow corrected (non-integer) values
    eltype(table.DFn) <: Integer && (table[!, :DFn] = Float64.(table.DFn))
    eltype(table.DFd) <: Integer && (table[!, :DFd] = Float64.(table.DFd))

    # Apply corrections to within-subjects effects
    for idx = 1:nrow(table)
        effect_name = table[idx, :Effect]
        !_is_within_effect_in_table(effect_name, within_factors) && continue

        effect_factors = _parse_effect_name(effect_name)
        components = _get_sphericity_components(data, dv, id, effect_factors)

        if isnothing(components)
            table[idx, :ε] = 1.0  # k=2, sphericity holds
            continue
        end

        u_matrix, n_contrasts, df, _ = components
        epsilon = _compute_epsilon(u_matrix, n_contrasts, df, type)

        # Apply corrections
        F = table[idx, :F]
        df1 = table[idx, :DFn]
        df2 = table[idx, :DFd]

        table[idx, :ε] = epsilon
        table[idx, :p] = 1.0 - cdf(FDist(df1 * epsilon, df2 * epsilon), F)
        table[idx, :DFn] = df1 * epsilon
        table[idx, :DFd] = df2 * epsilon
        table[idx, :MSE] = table[idx, :SSd] / table[idx, :DFd]
    end

    return table
end
