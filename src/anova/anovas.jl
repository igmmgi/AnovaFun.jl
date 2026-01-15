"""
    anova(data, dv, id; within=nothing, between=nothing, correction=:none, effect_size=:pes)

Perform ANOVA on factorial designs including repeated measures (within-subjects), between-subjects, and mixed designs.

# Arguments
- `data::AbstractDataFrame`: DataFrame containing the data in long format (one row per observation)
- `dv::Symbol`: Symbol naming the dependent variable column
- `id::Symbol`: Symbol naming the subject/participant identifier column
- `within::Union{AbstractVector{Symbol}, Nothing}`: Vector of Symbols naming within-subjects (repeated measures) factors (default: `nothing`)
- `between::Union{AbstractVector{Symbol}, Nothing}`: Vector of Symbols naming between-subjects factors (default: `nothing`)
- `correction::Symbol`: Sphericity correction type for within-subjects effects. Options: `:none` (default), `:GG` (Greenhouse-Geisser), or `:HF` (Huynh-Feldt). When not `:none`, adds `ε` (epsilon) column and adjusts degrees of freedom and p-values in the ANOVA table.
- `effect_size::Symbol`: Effect size to include. Options: `:none` (no effect sizes), `:es` (eta squared, η²), `:pes` (partial eta squared, η²ₚ, default), `:os` (omega squared, ω²)

# Returns
An `AnovaResult` object containing:
- `table::DataFrame`: ANOVA table with columns: Effect, DFn, DFd, SSn, SSd, MSE, F, p, sig, and optionally ε (epsilon), η², η²ₚ, ω²
- `design::DesignInfo`: Design metadata (type: `:between`, `:within`, or `:mixed`, factors, number of subjects)
- `model`: Fitted linear model (GLM.TableRegressionModel) for diagnostics (residuals, fitted values, coefficients, etc.)
- `data::DataFrame`: Original data used for analysis
- `dv::Symbol`: Dependent variable name
- `id::Symbol`: Subject identifier name

# Examples
```julia
# Between-subjects ANOVA
result = anova(data, :dv, :id, between=[:group])

# Within-subjects (repeated measures) ANOVA
result = anova(data, :dv, :id, within=[:time])

# With Greenhouse-Geisser correction for sphericity
result = anova(data, :dv, :id, within=[:time], correction=:GG)

# Mixed design
result = anova(data, :dv, :id, between=[:group], within=[:time])

# With omega squared effect size
result = anova(data, :dv, :id, within=[:time], effect_size=:os)
```

# Notes
- Data must be in long format with one row per observation
- At least one factor (within or between) must be specified
- For within-subjects designs, sphericity correction is recommended when factors have more than 2 levels
"""
function anova(
    data::AbstractDataFrame,
    dv::Symbol,
    id::Symbol;
    within::Union{AbstractVector{Symbol},Nothing} = nothing,
    between::Union{AbstractVector{Symbol},Nothing} = nothing,
    correction::Symbol = :none,
    effect_size::Symbol = :pes,
)

    validate_anova_inputs(data, dv, id, within, between, correction, effect_size)

    # data needs to be aggregated for ANOVA
    data = aggregate(data, dv, id, within, between)

    # do the anova thing!
    result = _anova(data, dv, id, within, between, effect_size, correction)

    return result

end

function _anova(data, dv, id, within, between, effect_size, correction)
    # ANOVA type (handle both nothing and empty vectors)
    if isnothing(within) || (within isa AbstractVector && isempty(within))
        return _anova_between(data, dv, id, between, effect_size)
    elseif isnothing(between) || (between isa AbstractVector && isempty(between))
        return _anova_within(data, dv, id, within, effect_size, correction)
    else # Mixed design
        return _anova_mixed(data, dv, id, within, between, effect_size, correction)
    end
end


function _factor_subsets(factors::Vector{Symbol}; include_empty::Bool = false)
    subsets = Vector{Vector{Symbol}}()
    start_order = include_empty ? 0 : 1
    for n_factors = start_order:length(factors)
        append!(subsets, _combinations(factors, n_factors))
    end
    return subsets
end

# ============================================================================
# Sum of Squares (SS) Calculation Functions
# ============================================================================
# All SS calculations follow the inclusion-exclusion principle:
# SS(A×B) = SS(A) + SS(B) - SS(∅) for interactions
# 
# Pattern: _*_effect_ss wraps _inclusion_exclusion with a raw SS function
# - _raw_ss_within_interaction: for pure within-subjects effects
# - _raw_ss_between: for pure between-subjects effects  
# - _raw_general_ss: for mixed-design effects
# ============================================================================

# Generic inclusion-exclusion function for computing interaction SS
function _inclusion_exclusion(factors::Vector{Symbol}, raw_ss_func::Function)
    length(factors) == 1 && return raw_ss_func(factors)

    subsets = _factor_subsets(factors, include_empty = true)
    k = length(factors)
    ss_value = 0.0

    for subset in subsets
        coeff = (-1)^(k - length(subset))
        ss_value += coeff * raw_ss_func(subset)
    end

    return ss_value
end

function _contrast_matrix(n_levels::Int)
    contrast_matrix = zeros(n_levels, n_levels - 1)
    for i = 1:(n_levels-1)
        contrast_matrix[i, i] = 1.0
        contrast_matrix[n_levels, i] = -1.0
    end
    return contrast_matrix
end

function _sspe(y::Matrix{Float64})
    y_mean = mean(y, dims = 1)
    y_centered = y .- y_mean
    return y_centered' * y_centered
end

function _multivariate_ssd(SSPE::Matrix{Float64}, P::Matrix{Float64})
    p_transpose_p = P' * P
    projected_sspe = P' * SSPE * P
    return tr(projected_sspe * inv(p_transpose_p))
end


function _univariate_model(data::DataFrame, dv::Symbol, design::DesignInfo)
    factors = vcat(design.between_factors, design.within_factors)
    isempty(factors) && throw(ArgumentError("Cannot fit model with no factors"))

    # Build formula: dv ~ f1 * f2 * f3 ...
    # In StatsModels, * expands to main effects + interactions (like R)
    formula_terms = Term.(factors)
    rhs = length(formula_terms) == 1 ? formula_terms[1] : reduce(*, formula_terms)
    formula = Term(dv) ~ rhs

    # Use sum contrasts to match R's afex package 
    contrasts_dict = Dict(
        f => StatsModels.EffectsCoding(base = sort(unique(data[!, f]))[end]) for
        f in factors
    )

    return lm(formula, data; contrasts = contrasts_dict)
end


function _push_result!(results, effect_name, df_n, df_d, ss_n, ss_d)
    mse = ss_d / df_d
    F = (ss_n / df_n) / mse
    p = 1.0 - cdf(FDist(df_n, df_d), F)
    push!(
        results,
        (;
            Effect = effect_name,
            DFn = df_n,
            DFd = df_d,
            SSn = ss_n,
            SSd = ss_d,
            MSE = mse,
            F = F,
            p = p,
        ),
    )
end

_factor_levels(factors, data) = Dict(f => length(unique(data[!, f])) for f in factors)


function _significance!(results::DataFrame)
    results[!, :sig] = map(results.p) do p
        if p < P_VALUE_THRESHOLD_001
            "***"
        elseif p < P_VALUE_THRESHOLD_01
            "**"
        elseif p < P_VALUE_THRESHOLD_05
            "*"
        else
            "n.s."
        end
    end
    return results
end

function _effect_sizes!(
    results::DataFrame,
    data::DataFrame,
    dv::Symbol,
    effect_size::Symbol,
)
    if effect_size == :pes
        # partial eta squared (η²ₚ): SS_effect / (SS_effect + SS_error)
        results[!, :η²ₚ] = results.SSn ./ (results.SSn .+ results.SSd)
    elseif effect_size in [:es, :os]

        grand_mean = mean(data[!, dv])
        ss_total = sum((data[!, dv] .- grand_mean) .^ 2)

        if effect_size == :es
            # eta squared (η²): SS_effect / SS_total
            results[!, :η²] = results.SSn ./ ss_total
        else
            # omega squared (ω²): (SS_effect - df_effect * MS_error) / (SS_total + MS_error)
            ms_error = results.SSd ./ results.DFd
            omega_squared =
                (results.SSn .- results.DFn .* ms_error) ./ (ss_total .+ ms_error)
            results[!, :ω²] = max.(0.0, omega_squared)
        end
    end
    return results
end

function _finalize_results!(
    results::DataFrame,
    data::DataFrame,
    dv::Symbol,
    design_info::DesignInfo,
    effect_size::Symbol,
    correction::Symbol,
    within_factors::Vector{Symbol} = Symbol[],
    id::Symbol = :id,
)
    correction != :none &&
        _sphericity_correction!(results, data, dv, id, within_factors, correction)
    effect_size != :none && _effect_sizes!(results, data, dv, effect_size)
    _significance!(results)

    # Sort rows according to factor order
    all_factors_ordered = all_factors(design_info)
    if !isempty(all_factors_ordered)
        # Create a sorting key: order by number of factors, then by factor order
        function sort_key(effect_name::String)
            effect_name == "Intercept" && return (0, Int[])  # Intercept first
            effect_factors = _parse_effect_name(effect_name)
            order_indices = [findfirst(==(f), all_factors_ordered) for f in effect_factors]
            return (length(effect_factors), order_indices)
        end
        sort!(results, :Effect, by = sort_key)
    end

    # Reorder columns
    base_cols = [:Effect, :DFn, :DFd, :SSn, :SSd, :MSE, :F, :p, :sig]
    optional_cols = [:ε, :η²ₚ, :η², :ω²]
    cols_to_select =
        vcat(base_cols, [col for col in optional_cols if col in propertynames(results)])
    select!(results, cols_to_select)
end
