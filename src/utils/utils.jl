"""
    aggregate(data, dv, id, within, between)

Aggregate data to cell means per subject and condition combination.
This collapses the data to one value per subject × condition for ANOVA calculations.

# Arguments
- `data::AbstractDataFrame`: Input data
- `dv::Symbol`: Dependent variable name
- `id::Symbol`: Subject identifier name
- `within::Union{AbstractVector{Symbol}, Nothing}`: Within-subjects factors
- `between::Union{AbstractVector{Symbol}, Nothing}`: Between-subjects factors

# Returns
- `DataFrame`: Aggregated data with one row per subject × condition combination
"""
function aggregate(
    data::AbstractDataFrame,
    dv::Symbol,
    id::Symbol,
    within::Union{AbstractVector{Symbol},Nothing},
    between::Union{AbstractVector{Symbol},Nothing},
)::DataFrame
    # group by id + between/within factors, and compute dv mean, to give 1 value per id × condition combination
    group_vars = vcat([id], something(between, Symbol[]), something(within, Symbol[]))
    return combine(groupby(data, group_vars), dv => mean => dv)
end

# helpers for effect names + effect name parsing
# Create effect name using a reference order (for maintaining user's factor order)
# If reference_order is empty or not provided, falls back to sorted order
function _effect_name(
    effect_factors::Vector{Symbol},
    reference_order::Vector{Symbol} = Symbol[],
)::String
    length(effect_factors) == 1 && return string(first(effect_factors))

    # If no reference order provided, use sorted order (default behavior)
    if isempty(reference_order)
        return join(string.(sort(effect_factors)), " × ")
    end

    # Use the order from reference_order, but only include factors that are in effect_factors
    ordered_factors = [f for f in reference_order if f in effect_factors]
    # If some factors aren't in reference_order, add them at the end (sorted)
    missing_factors = [f for f in effect_factors if f ∉ reference_order]
    if !isempty(missing_factors)
        ordered_factors = vcat(ordered_factors, sort(missing_factors))
    end
    return join(string.(ordered_factors), " × ")
end

_parse_effect_name(e::String)::Vector{Symbol} = Symbol.(strip.(split(e, " × ")))

# generate all combinations of k elements from a list
function _combinations(arr::AbstractVector{T}, k::Int) where {T}
    k == 0 && return [T[]]
    k > length(arr) && return Vector{T}[]

    result = Vector{T}[]
    for i = 1:(length(arr)-k+1)
        for combo in _combinations(arr[(i+1):end], k - 1)
            push!(result, vcat([arr[i]], combo))
        end
    end
    return result
end

# adjust interval margins
function _adjust_ci(se::Float64, df::Int, method::Symbol, n::Int, alpha::Float64)
    if method == :none
        t_crit = quantile(TDist(df), 1 - alpha / 2)
        return t_crit * se
    elseif method == :bonferroni
        t_crit = quantile(TDist(df), 1 - (alpha / (2 * n)))
        return t_crit * se
    elseif method == :sidak
        # Sidak: adjusted confidence level = (1 - alpha)^(1/k)
        # Per-item alpha = 1 - (1 - alpha)^(1/k)
        adjusted_alpha = 1 - (1 - alpha)^(1 / n)
        t_crit = quantile(TDist(df), 1 - adjusted_alpha / 2)
        return t_crit * se
    end
end

# Helper: Get ANOVA table row info for an effect (DFn, DFd, MSE)
# Works with both AnovaResult objects and ANOVA table DataFrames
function _get_anova_row_info(source::Union{AnovaResult,DataFrame}, effect_name::String)
    # Extract the ANOVA table
    table = source isa AnovaResult ? source.table : source

    effect_row = findfirst(row -> row.Effect == effect_name, eachrow(table))
    isnothing(effect_row) && return nothing

    dfn = table[effect_row, :DFn]
    dfd = table[effect_row, :DFd]
    mse = table[effect_row, :MSE]

    return (dfn = dfn, dfd = dfd, mse = mse)
end

# Build a subject×condition matrix for multivariate ANOVA computations
function _subject_condition_matrix(
    data::AbstractDataFrame,
    dv::Symbol,
    id::Symbol,
    effect_factors::Vector{Symbol};
    aggregate::Bool = true,
)
    # Get unique subjects and condition levels
    ids = sort(unique(data[!, id]))
    condition_levels = [sort(unique(data[!, f])) for f in effect_factors]
    n_id = length(ids)
    n_conditions = prod(length(levels) for levels in condition_levels)

    # Initialize matrix
    Y = zeros(Float64, n_id, n_conditions)

    # Build index maps
    id_map = Dict{eltype(ids),Int}(id_val => idx for (idx, id_val) in enumerate(ids))
    cond_map = Dict{Tuple,Int}()
    sizehint!(cond_map, n_conditions)
    for (idx, combo) in enumerate(Iterators.product(condition_levels...))
        cond_map[combo] = idx
    end

    if aggregate
        # Accumulate and average (for sphericity tests with potential repeated observations)
        data_sums = zeros(Float64, n_id, n_conditions)
        data_counts = zeros(Int, n_id, n_conditions)

        id_col = data[!, id]
        dv_col = data[!, dv]
        factor_cols = [data[!, f] for f in effect_factors]

        for i = 1:nrow(data)
            id_idx = id_map[id_col[i]]
            cond_key = Tuple(factor_cols[j][i] for j = 1:length(effect_factors))
            cond_idx = cond_map[cond_key]
            data_sums[id_idx, cond_idx] += dv_col[i]
            data_counts[id_idx, cond_idx] += 1
        end

        for i = 1:n_id, j = 1:n_conditions
            count = data_counts[i, j]
            count == 0 &&
                throw(ArgumentError("Missing data for subject $(ids[i]) and condition $j"))
            Y[i, j] = data_sums[i, j] / count
        end
    else
        # Direct assignment (assumes one value per cell, used in multivariate error SS)
        for row in eachrow(data)
            id_idx = id_map[row[id]]
            cond_key = Tuple(row[f] for f in effect_factors)
            cond_idx = get(cond_map, cond_key, nothing)
            if !isnothing(cond_idx)
                Y[id_idx, cond_idx] = row[dv]
            end
        end
    end

    return Y
end

"""
    errorbar_limits!(result, errorbars)

Add error bar distances from mean to the EmmeansResult (mutating).

Adds an `error` column to `result.means` with the symmetrical distance from the mean 
(error bars extend Mean ± error).

# Arguments
- `result::EmmeansResult`: The emmeans result (will be mutated)
- `errorbars::Symbol`: Error bar type (`:none`, `:SE`, `:CI`, `:withinSE`, `:withinCI`)

# Returns
- `nothing` (mutates `result.means` in place)
"""
function errorbar_limits!(result::EmmeansResult, errorbars::Symbol)
    means_df = result.means

    allowed_errorbars = [:none, :SE, :CI, :withinSE, :withinCI]
    errorbars ∉ allowed_errorbars &&
        throw(ArgumentError("errorbars must be one of: $(allowed_errorbars)"))

    # For :CI, compute error from Lower/Upper: (Upper - Lower) / 2
    if errorbars == :CI
        means_df[!, :error] = (means_df.Upper .- means_df.Lower) ./ 2
        # For within-participant error bars, need raw data
    elseif errorbars ∈ [:withinSE, :withinCI]
        error_values = _within_errors(
            means_df,
            result.anova.data,
            result.anova.dv,
            result.anova.id,
            result.level,
            errorbars == :withinCI,  # whether to compute CI (true) or just SE (false)
            result.anova.design.within_factors,
        )
        if !isnothing(error_values)
            means_df[!, :error] = error_values
        end
    end

    return nothing
end

# Helper: Match factor order by finding a row in se_df that matches level_parts
# Returns the factor order as a Vector{Symbol} matching the order of level_parts
function _match_factor_order(
    level_parts::Vector{String},
    se_df::DataFrame,
    effect_factors::Vector{Symbol},
)::Vector{Symbol}
    # Default to original factor order if no match found
    factor_order = effect_factors

    for se_row in eachrow(se_df)
        se_values = [string(se_row[f]) for f in effect_factors]
        if Set(se_values) == Set(level_parts)
            # Map level_parts positions to effect_factors by matching values
            factor_order = Vector{Symbol}(undef, length(level_parts))
            used = Set{Int}()
            for (i, level_val) in enumerate(level_parts)
                for (j, factor) in enumerate(effect_factors)
                    if j ∉ used && string(se_row[factor]) == level_val
                        factor_order[i] = factor
                        push!(used, j)
                        break
                    end
                end
            end
            break
        end
    end

    return factor_order
end

# Helper: Determine factor order from means_df Level strings and se_df
function _determine_factor_order_from_se_df(
    effect_means::DataFrame,
    se_df::DataFrame,
    effect_factors::Vector{Symbol},
)::Vector{Symbol}
    isempty(effect_means) && return effect_factors

    first_level = effect_means[1, :Level]
    level_parts = String.(strip.(split(first_level, ", ")))
    return _match_factor_order(level_parts, se_df, effect_factors)
end

# Helper: Create error lookup dictionary mapping level strings to error values
function _create_error_lookup_dict(
    se_df::DataFrame,
    factor_order::Vector{Symbol},
)::Dict{String,Float64}
    error_lookup = Dict{String,Float64}()
    for row in eachrow(se_df)
        level_str = join([string(row[f]) for f in factor_order], ", ")
        error_lookup[level_str] = row.computed_error
    end
    return error_lookup
end

# Helper: Update means_df error column for a specific effect
function _update_means_df_error_column!(
    means_df::DataFrame,
    effect_name::String,
    error_lookup::Dict{String,Float64},
)
    for i = 1:nrow(means_df)
        if means_df[i, :Effect] == effect_name && haskey(error_lookup, means_df[i, :Level])
            means_df[i, :error] = error_lookup[means_df[i, :Level]]
        end
    end
end

# Compute within-participant error bars and return vector of error values
# Uses Cousineau-Morey method 
function _within_errors(
    means_df::DataFrame,
    raw_data::DataFrame,
    dv::Symbol,
    id_col::Symbol,
    confidence_level::Float64,
    compute_ci::Bool = true,
    within_factors::Vector{Symbol} = Symbol[],
)

    all_ids = unique(raw_data[!, id_col])
    n_id = length(all_ids)
    if n_id < 2 || isempty(within_factors)
        @minimal_warning "Can't compute within-participant errors: need at least 2 ids (subjects) and within-subjects factors"
        return nothing
    end

    # Step 1: Calculate individual means per subject and grand mean and join
    id_means_df = combine(groupby(raw_data, id_col), dv => mean => :subj_mean)
    grand_mean_all = mean(id_means_df.subj_mean)
    data_with_means = leftjoin(raw_data, id_means_df, on = id_col)

    # Step 2: Normalize data (Cousineau & O'Brien 2014, Equation 2)
    data_with_means[!, :new_dv] =
        data_with_means[!, dv] .- data_with_means.subj_mean .+ grand_mean_all

    # Step 3: Compute y_bar per within condition and join to DataFrame
    y_bar_df = combine(groupby(data_with_means, within_factors), :new_dv => mean => :y_bar)
    data_with_means = leftjoin(data_with_means, y_bar_df, on = within_factors)

    # Step 4: Apply Morey correction (Cousineau & O'Brien 2014, Equation 4)
    # new_z = sqrt(J / (J - 1)) * (new_y - y_bar[within_fac]) + y_bar[within_fac]
    J = nrow(y_bar_df)
    morey_correction = J > 1 ? sqrt(J / (J - 1)) : 1.0
    data_with_means[!, :corrected_dv] =
        morey_correction .* (data_with_means.new_dv .- data_with_means.y_bar) .+
        data_with_means.y_bar

    # Step 5: Compute error values - build up vector to replace error column
    alpha = 1 - confidence_level

    # Compute SEs for all effects with within-subject factors and update means_df
    for effect_name in unique(means_df.Effect)
        effect_name == "Grand Mean" && continue

        effect_factors = _parse_effect_name(effect_name)
        effect_within_factors = [f for f in effect_factors if f in within_factors]
        isempty(effect_within_factors) && continue

        # Compute SE for each level combination
        se_df = combine(groupby(data_with_means, effect_factors)) do group
            corrected_values = group[!, :corrected_dv]
            n_obs = length(corrected_values)
            cell_se = n_obs > 1 ? std(corrected_values) / sqrt(n_obs) : 0.0

            if compute_ci
                df_for_ci = n_obs - 1
                t_critical =
                    df_for_ci > 0 ? quantile(TDist(df_for_ci), 1 - alpha / 2) : 1.0
                (computed_error = cell_se * t_critical,)
            else
                (computed_error = cell_se,)
            end
        end

        # Determine factor order from means_df Level strings
        effect_means = filter(r -> r.Effect == effect_name, means_df)
        isempty(effect_means) && continue

        factor_order =
            _determine_factor_order_from_se_df(effect_means, se_df, effect_factors)
        error_lookup = _create_error_lookup_dict(se_df, factor_order)
        _update_means_df_error_column!(means_df, effect_name, error_lookup)
    end

    return means_df.error
end
