"""
    _process_factors(within, between)

Extract factor names and convert labels to strings from within and between dictionaries.
Returns (between_factors, within_factors, labelnames, factor_levels).
"""
function _process_factors(
    within::Union{Dict{Symbol, <:Vector}, Nothing},
    between::Union{Dict{Symbol, <:Vector}, Nothing},
)
    between_factors = Symbol[]
    within_factors = Symbol[]
    labelnames = Dict{Symbol, Vector{String}}()
    factor_levels = Dict{Symbol, Int}()
    
    if !isnothing(between) && !isempty(between)
        for (factor, levels) in between
            push!(between_factors, factor)
            labelnames[factor] = [string(level) for level in levels]
            factor_levels[factor] = length(levels)
        end
    end
    
    if !isnothing(within) && !isempty(within)
        for (factor, levels) in within
            push!(within_factors, factor)
            labelnames[factor] = [string(level) for level in levels]
            factor_levels[factor] = length(levels)
        end
    end
    
    if isempty(between_factors) && isempty(within_factors)
        throw(ArgumentError("At least one factor (within or between) must be specified"))
    end
    
    return between_factors, within_factors, labelnames, factor_levels
end

"""
    _generate_cell_combinations(between_factors, within_factors, factor_levels, labelnames)

Generate all cell combinations for the design.
"""
function _generate_cell_combinations(
    between_factors::Vector{Symbol},
    within_factors::Vector{Symbol},
    factor_levels::Dict{Symbol, Int},
    labelnames::Dict{Symbol, Vector{String}},
)
    
    all_factors = vcat(between_factors, within_factors)
    level_ranges = [1:factor_levels[f] for f in all_factors]
    cells = String[]
    for combo in Base.Iterators.product(level_ranges...)
        cell_parts = String[]
        for (i, factor) in enumerate(all_factors)
            level_idx = combo[i]
            level_label = labelnames[factor][level_idx]
            push!(cell_parts, level_label)
        end
        push!(cells, join(cell_parts, "_"))
    end
    
    return cells
end

"""
    _parse_cell(cell_string, factors)

Parse a cell string like "a1_b1" into a dictionary mapping factors to levels.
"""
function _parse_cell(cell_string::String, factors::Vector{Symbol})
    result = Dict{Symbol, String}()
    parts = split(cell_string, "_")
    for (i, factor) in enumerate(factors)
        if i <= length(parts)
            result[factor] = parts[i]
        end
    end
    return result
end

"""
    _combine_cell_names(between_cell, within_cell)

Combine between and within cell names using underscore separator.
"""
function _combine_cell_names(between_cell::String, within_cell::String)
    isempty(between_cell) && return within_cell
    isempty(within_cell) && return between_cell
    return "$(between_cell)_$(within_cell)"
end

"""
    _reorder_columns(df)

Reorder DataFrame columns: id first, then factor columns, then dv last.
"""
function _reorder_columns(df::DataFrame)
    factor_cols = [col for col in propertynames(df) if col != :id && col != :dv]
    return df[:, [:id; factor_cols; :dv]]
end

"""
    _build_correlation_matrix(r_vec, n_within)

Build a correlation matrix from a pre-normalized vector of correlations.
Follows Superpower convention for filling from upper triangle.
"""
function _build_correlation_matrix(r_vec::Vector{Float64}, n_within::Int)
    
    # Build correlation matrix (Superpower convention: fill upper triangle)
    corr_matrix = zeros(n_within, n_within)
    idx = 1
    for col in 1:n_within
        for row in 1:col
            if row == col
                corr_matrix[row, col] = 1.0  # Diagonal
            else
                corr_matrix[row, col] = r_vec[idx]  # Upper triangle
                corr_matrix[col, row] = r_vec[idx]  # Lower triangle (mirror)
                idx += 1
            end
        end
    end
    
    return corr_matrix
end

"""
    _assign_subjects_to_groups(n, between_factors, factor_levels, labelnames)

Assign subjects to between-subjects groups. Returns empty dict if no between factors.
"""
function _assign_subjects_to_groups(n::Int, between_factors::Vector{Symbol}, factor_levels::Dict{Symbol, Int}, labelnames::Dict{Symbol, Vector{String}})
    isempty(between_factors) && return Dict{String, Vector{Int}}()
    
    between_combinations = _generate_cell_combinations(between_factors, Symbol[], factor_levels, labelnames)
    subjects_per_group = div(n, length(between_combinations))
    subject_ids = 1:n
    
    assignments = Dict{String, Vector{Int}}()
    subject_idx = 1
    for combo in between_combinations
        group_subjects = subject_ids[subject_idx:(subject_idx + subjects_per_group - 1)]
        assignments[combo] = group_subjects
        subject_idx += subjects_per_group
    end
    return assignments
end

"""
    _get_subjects_for_cell(cell, between_factors, subject_assignments, n)

Get the list of subject IDs for a given cell based on between-subjects factors.
"""
function _get_subjects_for_cell(cell::String, between_factors::Vector{Symbol}, subject_assignments::Dict{String, Vector{Int}}, n::Int)
    isempty(between_factors) && return 1:n
    cell_parts = split(cell, "_")
    between_key = join(cell_parts[1:length(between_factors)], "_")
    return subject_assignments[between_key]
end

"""
    _generate_correlated_data(n, between_factors, within_factors, cell_params, r_vec, subject_assignments, factor_levels, labelnames)

Generate correlated data using multivariate normal distribution.
"""
function _generate_correlated_data(n::Int, between_factors::Vector{Symbol}, within_factors::Vector{Symbol}, 
                                   cell_params::Dict{String, Vector{Float64}}, r_vec::Vector{Float64}, 
                                   subject_assignments::Dict{String, Vector{Int}},
                                   factor_levels::Dict{Symbol, Int}, labelnames::Dict{Symbol, Vector{String}})
    all_factors = vcat(between_factors, within_factors)
    within_cells = _generate_cell_combinations(Symbol[], within_factors, factor_levels, labelnames)
    n_within = length(within_cells)

    # Build covariance matrix (SDs should be same across between-subjects groups for covariance structure)
    # Get SDs from first between-group or pure within-subjects cells
    corr_matrix = _build_correlation_matrix(r_vec, n_within)
    
    # Get SDs: use first between-group's cells if mixed design, otherwise use pure within cells
    if !isempty(between_factors)
        first_between = first(keys(subject_assignments))
        sd_vec = [cell_params[_combine_cell_names(first_between, cell)][2] for cell in within_cells]
    else
        sd_vec = [cell_params[cell][2] for cell in within_cells]
    end
    
    all(sd_vec .> 0.0) || throw(ArgumentError("Standard deviation (sd) must be > 0 for simulation. Got sd with values <= 0."))
    cov_matrix = corr_matrix .* (sd_vec * sd_vec')
    
    # Pre-allocate vectors for DataFrame columns
    n_rows = n * n_within
    ids = Vector{Int}(undef, n_rows)
    dvs = Vector{Float64}(undef, n_rows)
    factor_cols = Dict{Symbol, Vector{String}}(factor => Vector{String}(undef, n_rows) for factor in all_factors)
    
    # Generate data for each between-subjects group (or all subjects if pure within-subjects)
    groups = isempty(between_factors) ? [("", 1:n)] : [(combo, subjects) for (combo, subjects) in subject_assignments]
    
    row_idx = 1
    for (between_combo, subjects) in groups
        means_vec = [cell_params[isempty(between_combo) ? cell : _combine_cell_names(between_combo, cell)][1] for cell in within_cells]
        mv_dist = MvNormal(means_vec, cov_matrix)
        
        for subject_id in subjects
            values = rand(mv_dist)
            for (i, within_cell) in enumerate(within_cells)
                full_cell = isempty(between_combo) ? within_cell : _combine_cell_names(between_combo, within_cell)
                cell_factors = _parse_cell(full_cell, all_factors)
                
                # Fill pre-allocated vectors
                ids[row_idx] = subject_id
                dvs[row_idx] = values[i]
                for (factor, level) in cell_factors
                    factor_cols[factor][row_idx] = level
                end
                row_idx += 1
            end
        end
    end
    
    # Create DataFrame once from pre-allocated vectors
    return DataFrame(Dict(:id => ids, :dv => dvs, (factor => factor_cols[factor] for factor in all_factors)...))
end

"""
    _generate_independent_data(cell_params, between_factors, subject_assignments, n, all_factors)

Generate independent data for each cell.
"""
function _generate_independent_data(cell_params::Dict{String, Vector{Float64}}, 
                                    between_factors::Vector{Symbol}, subject_assignments::Dict{String, Vector{Int}}, 
                                    n::Int, all_factors::Vector{Symbol})
    # Calculate total number of rows
    n_rows = sum(length(_get_subjects_for_cell(cell, between_factors, subject_assignments, n)) for cell in keys(cell_params))
    
    # Pre-allocate vectors
    ids = Vector{Int}(undef, n_rows)
    dvs = Vector{Float64}(undef, n_rows)
    factor_cols = Dict{Symbol, Vector{String}}(factor => Vector{String}(undef, n_rows) for factor in all_factors)
    
    row_idx = 1
    for cell in keys(cell_params)
        cell_mean, cell_sd = cell_params[cell]
        cell_factors = _parse_cell(cell, all_factors)
        cell_subjects = _get_subjects_for_cell(cell, between_factors, subject_assignments, n)
        
        for subject_id in cell_subjects
            value = cell_mean + cell_sd * randn()
            ids[row_idx] = subject_id
            dvs[row_idx] = value
            for (factor, level) in cell_factors
                factor_cols[factor][row_idx] = level
            end
            row_idx += 1
        end
    end
    
    return DataFrame(Dict(:id => ids, :dv => dvs, (factor => factor_cols[factor] for factor in all_factors)...))
end

"""
    _generate_data(n, between_factors, within_factors, cell_params, r, labelnames, factor_levels)

Generate simulated data for the design with proper correlation structure.
`cell_params` maps cell names to [mean, sd] vectors.
"""
function _generate_data(
    n::Int,
    between_factors::Vector{Symbol},
    within_factors::Vector{Symbol},
    cell_params::Dict{String, Vector{Float64}},
    r::Union{Vector{Float64}, Nothing},
    labelnames::Dict{Symbol, Vector{String}},
    factor_levels::Dict{Symbol, Int},
)
    subject_assignments = _assign_subjects_to_groups(n, between_factors, factor_levels, labelnames)
    all_factors = vcat(between_factors, within_factors)
    
    # Generate data based on whether correlation is needed
    df = if !isnothing(r)
        _generate_correlated_data(n, between_factors, within_factors, cell_params, r, subject_assignments, factor_levels, labelnames)
    else
        _generate_independent_data(cell_params, between_factors, subject_assignments, n, all_factors)
    end
    
    return _reorder_columns(df)
end

"""
    simulate_data(n; within=nothing, between=nothing, mu, sd, r=nothing)

Generate a simulated DataFrame with known properties for ANOVA analysis.

This function creates a DataFrame with the specified design structure, means, standard deviations, and correlations.
The design is specified using dictionaries mapping factor names to their level labels, making it consistent
with the `anova` function signature.

# Arguments
- `n::Int`: Number of subjects/participants (positional argument)
- `within::Union{Dict{Symbol, Vector}, Nothing}`: Dictionary mapping within-subjects factor names to level labels. 
  Example: `Dict(:factor1 => [:a1, :a2], :factor2 => [:b1, :b2])`
- `between::Union{Dict{Symbol, Vector}, Nothing}`: Dictionary mapping between-subjects factor names to level labels.
  Example: `Dict(:group => [:control, :treatment])`
- `mu::Union{Real, Vector{<:Real}}`: Cell means in cell order (all combinations of factors)
- `sd::Union{Real, Vector{<:Real}}`: Standard deviation. Single value for all cells, or vector (one per cell, matching `mu` order)
- `r::Union{Real, Vector{<:Real}, Nothing}`: Correlation for within-subjects factors (compound symmetry). Default: `nothing` (uses 0.0)

# Returns
A `DataFrame` with columns in order:
- `id`: Subject/participant ID (first column)
- Factor columns: One column per factor with level labels (middle columns)
- `dv`: Dependent variable values (last column)

# Examples
```julia
# Generate data for a 2×2 within-subjects design
data = simulate_data(20, 
                     within = Dict(:factor1 => [:a1, :a2], :factor2 => [:b1, :b2]),
                     mu = [1.0, 1.0, 1.0, 2.0], 
                     sd = 1.0, 
                     r = 0.5)

# Generate data for a mixed design
data = simulate_data(40, 
                     between = Dict(:voice => [:human, :robot]),
                     within = Dict(:emotion => [:cheerful, :sad]),
                     mu = [1.03, 1.41, 0.98, 1.01], 
                     sd = 1.03, 
                     r = 0.8)

# Then analyze it (same as before)
result = anova(data, :dv, :id, between=[:voice], within=[:emotion])
```
"""
function simulate_data(
    n::Int;
    within::Union{Dict{Symbol, <:Vector}, Nothing} = nothing,
    between::Union{Dict{Symbol, <:Vector}, Nothing} = nothing,
    mu::Union{Real, Vector{<:Real}},
    sd::Union{Real, Vector{<:Real}},
    r::Union{Real, Vector{<:Real}, Nothing} = nothing,
)
    # Extract factor names and convert labels to strings
    between_factors, within_factors, labelnames, factor_levels = _process_factors(within, between)
    
    # Generate cell combinations and validate parameter lengths
    cells = _generate_cell_combinations(between_factors, within_factors, factor_levels, labelnames)
    
    n_cells = length(cells)
    mu = mu isa Number ? fill(Float64(mu), n_cells) : Float64.(mu)
    sd = sd isa Number ? fill(Float64(sd), n_cells) : Float64.(sd)

    length(mu) == n_cells || throw(ArgumentError("Number of means ($(length(mu))) doesn't match design cells ($n_cells)"))
    length(sd) == n_cells || throw(ArgumentError("Number of sd values ($(length(sd))) doesn't match design cells ($n_cells)"))
    
    # Normalize r to vector 
    r = if !isempty(within_factors)
        n_within = length(_generate_cell_combinations(Symbol[], within_factors, factor_levels, labelnames))
        n_cors_needed = n_within * (n_within - 1) ÷ 2
        if isnothing(r)
            fill(0.0, n_cors_needed)
        elseif r isa Number
            fill(Float64(r), n_cors_needed)
        else
            length(r) != n_cors_needed && throw(ArgumentError("r vector must have length n_within*(n_within-1)/2 = $n_cors_needed, got $(length(r))"))
            Float64.(r)
        end
    else
        nothing  # Not used for pure between-subjects designs
    end
    
    # Create dictionary mapping cell names to [mean, sd] pairs
    cell_params = Dict(cell => [mu[i], sd[i]] for (i, cell) in enumerate(cells))
    
    # Generate and return data
    return _generate_data(n, between_factors, within_factors, cell_params, r, labelnames, factor_levels)
end

"""
    within_correlation_matrix(data::DataFrame)

Return the within-subjects correlation matrix for a design from a DataFrame (e.g., from `simulate_data`).

Data must be in long format (with `:id`, factor columns, and `:dv`). It will be converted to wide format internally.

# Arguments
- `data::DataFrame`: DataFrame in long format with `:id`, factor columns, and `:dv`

# Returns
A `DataFrame` with cell names as row and column names, containing correlation values.

# Examples
```julia
data = simulate_data(40, 
                     between=Dict(:voice => [:human, :robot]),
                     within=Dict(:emotion => [:cheerful, :sad]),
                     mu=[1.03, 1.41, 0.98, 1.01], sd=1.03, r=0.8)
corr = within_correlation_matrix(data)
```
"""
function within_correlation_matrix(data::DataFrame)
    # Get factor columns (everything except :id and :dv)
    factor_cols = [col for col in propertynames(data) if col != :id && col != :dv]
    isempty(factor_cols) && throw(ArgumentError("DataFrame must contain factor columns"))
    
    # Convert to wide format: create combined condition column from all factors
    data_wide = length(factor_cols) > 1 ?
        transform(data, factor_cols => ByRow((args...) -> join([string(a) for a in args], "_")) => :condition) :
        transform(data, first(factor_cols) => ByRow(string) => :condition)
    
    # Unstack to wide format
    data_wide = unstack(data_wide, :id, :condition, :dv)
    
    # Get cell column names (everything except :id)
    cell_cols = [col for col in propertynames(data_wide) if col != :id]
    
    # Calculate correlation matrix directly
    corr_matrix = cor(Matrix(data_wide[:, cell_cols]))
    
    # Create DataFrame with cell names (convert symbols to strings for display)
    cell_names = string.(cell_cols)
    corr_df = DataFrame(corr_matrix, cell_names)
    insertcols!(corr_df, 1, :cell => cell_names)
    
    return corr_df
end

