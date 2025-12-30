"""
    power_analysis(n; within=nothing, between=nothing, mu, sd, r=nothing, n_sims=1000, alpha=0.05)

Perform power analysis for an ANOVA design using simulation.

# Arguments
- `n::Int`: Number of subjects/participants (positional argument)
  - For between-subjects designs: number of subjects **per group**
  - For within-subjects designs: total number of subjects
  - For mixed designs: number of subjects **per between-subjects group**
- `within::Union{Dict{Symbol, Vector}, Nothing}`: Dictionary mapping within-subjects factor names to level labels
- `between::Union{Dict{Symbol, Vector}, Nothing}`: Dictionary mapping between-subjects factor names to level labels
- `mu::Union{Real, Vector{<:Real}}`: Cell means. Single value for all cells, or vector (one per cell, matching cell order)
- `sd::Union{Real, Vector{<:Real}}`: Standard deviation. Single value for all cells, or vector (one per cell, matching `mu` order)
- `r::Union{Real, Vector{<:Real}, Nothing}`: Correlation for within-subjects factors (default: nothing)
- `n_sims::Int`: Number of simulations to run (default: 1000)
- `alpha::Float64`: Significance level (default: 0.05)

# Returns
A `PowerResult` object containing power estimates and effect sizes (partial eta-squared) for each effect.

# Examples
```julia
# Within-subjects design
result = power_analysis(20, 
                        within=Dict(:factor1 => [1, 2], :factor2 => [1, 2]),
                        mu=[1.1, 1.2, 1.6, 1.8], 
                        sd=1.0, 
                        r=0.5, 
                        n_sims=1000)
result.power  # View power estimates and effect sizes

# Mixed design
result = power_analysis(40,
                        between=Dict(:voice => [:human, :robot]),
                        within=Dict(:emotion => [:cheerful, :sad]),
                        mu=[1.03, 1.41, 0.98, 1.01],
                        sd=1.03,
                        r=0.8)
```
"""
function power_analysis(
    n::Int;
    within::Union{Dict{Symbol, <:Vector}, Nothing} = nothing,
    between::Union{Dict{Symbol, <:Vector}, Nothing} = nothing,
    mu::Union{Real, Vector{<:Real}},
    sd::Union{Real, Vector{<:Real}},
    r::Union{Real, Vector{<:Real}, Nothing} = nothing,
    n_sims::Int = 1000,
    alpha::Float64 = 0.05,
)
    # Extract factor names and convert labels to strings
    between_factors, within_factors, labelnames, factor_levels = _process_factors(within, between)
    
    # Convert per-group n to total n for between-subjects designs
    total_n = _calculate_total_n(n, between_factors, within_factors, factor_levels)
    
    # Convert to Dict format for PowerResult (using strings from labelnames)
    between_dict = isempty(between_factors) ? nothing : Dict(factor => labelnames[factor] for factor in between_factors)
    within_dict = isempty(within_factors) ? nothing : Dict(factor => labelnames[factor] for factor in within_factors)
    
    # Use simulate_data to generate data (it handles all the parameter normalization)
    result = _power_simulation(total_n, between_factors, within_factors, mu, sd, r, n_sims, alpha, between_dict, within_dict, labelnames, factor_levels)
    
    # Update power_df to show per-group n instead of total n
    result.power.n .= n
    
    return result
end

"""
    _power_simulation(n, between_factors, within_factors, mu, sd, r, n_sims, alpha, between_dict, within_dict, labelnames, factor_levels)

Simulation-based power analysis.
"""
function _power_simulation(
    n::Int,
    between_factors::Vector{Symbol},
    within_factors::Vector{Symbol},
    mu::Union{Real, Vector{<:Real}},
    sd::Union{Real, Vector{<:Real}},
    r::Union{Real, Vector{<:Real}, Nothing},
    n_sims::Int,
    alpha::Float64,
    between_dict::Union{Dict{Symbol, Vector{String}}, Nothing},
    within_dict::Union{Dict{Symbol, Vector{String}}, Nothing},
    labelnames::Dict{Symbol, Vector{String}},
    factor_levels::Dict{Symbol, Int},
)
    
    # Pre-compute normalized parameters once (avoid repeated allocations in simulate_data())
    # This matches what simulate_data() does but we do it once instead of every iteration
    
    cells = _generate_cell_combinations(between_factors, within_factors, factor_levels, labelnames)
    n_cells = length(cells)
    mu_vec = mu isa Number ? fill(Float64(mu), n_cells) : Float64.(mu)
    sd_vec = sd isa Number ? fill(Float64(sd), n_cells) : Float64.(sd)
    
    # Normalize r to vector
    r_vec = if !isempty(within_factors)
        n_within = length(_generate_cell_combinations(Symbol[], within_factors, factor_levels, labelnames))
        n_cors_needed = n_within * (n_within - 1) ÷ 2
        if isnothing(r)
            fill(0.0, n_cors_needed)
        elseif r isa Number
            fill(Float64(r), n_cors_needed)
        else
            Float64.(r)
        end
    else
        nothing
    end
    
    # Create dictionary mapping cell names to [mean, sd] pairs
    cell_params = Dict(cell => [mu_vec[i], sd_vec[i]] for (i, cell) in enumerate(cells))
    
    # Helper function to generate data without parameter normalization overhead
    function generate_sim_data(n_subjects::Int)
        return _generate_data(n_subjects, between_factors, within_factors, cell_params, r_vec, labelnames, factor_levels)
    end
    
    # Initialize effect structure by running one simulation first
    # We need this to know which effects exist and their order before allocating arrays
    effect_names = String[]
    effect_indices = Dict{String, Int}()
    effect_row_indices = Int[]
    n_effects = 0
    
    # Run first simulation to determine effect structure
    first_result = nothing
    max_attempts = 100
    attempts = 0
    while isnothing(first_result) && attempts < max_attempts
        attempts += 1
        try
            sim_data = generate_sim_data(n)
            first_result = _run_anova_on_sim_data(sim_data, between_factors, within_factors)
            
            # Extract effect structure (skip Intercept)
            for i in 1:nrow(first_result.table)
                effect = first_result.table.Effect[i]
                if effect != "Intercept"
                    n_effects += 1
                    push!(effect_names, effect)
                    push!(effect_row_indices, i)
                    effect_indices[effect] = n_effects
                end
            end
        catch e
            @minimal_warning "Initialization simulation failed: $e"
            first_result = nothing
            # Continue trying until we get a successful simulation
        end
    end
    
    if isnothing(first_result)
        throw(ErrorException("Failed to initialize power simulation after $max_attempts attempts. Check your design parameters."))
    end
    
    # Pre-compute inverse of n_sims to avoid repeated division
    inv_n_sims = 1.0 / n_sims
    
    # Pre-allocate arrays for tracking (will be combined from threads)
    significant_counts = zeros(Int, n_effects)
    effect_sizes_sum = zeros(Float64, n_effects)
    
    # Add results from first simulation (guaranteed to exist after while loop)
    p_values = first_result.table.p
    effect_sizes = first_result.table.η²ₚ
    
    for (idx, row_idx) in enumerate(effect_row_indices)
        if p_values[row_idx] < alpha
            significant_counts[idx] += 1
        end
        effect_sizes_sum[idx] += effect_sizes[row_idx]
    end
    
    # Parallelize remaining simulations using tasks (avoid threadid() issues)
    if n_sims > 1
        n_threads = Threads.nthreads()
        
        if n_threads == 1
            # Single thread: use simple sequential loop (no task overhead)
            for sim in 2:n_sims
                try
                    sim_data = generate_sim_data(n)
                    result = _run_anova_on_sim_data(sim_data, between_factors, within_factors)
                    
                    p_values = result.table.p
                    effect_sizes = result.table.η²ₚ
                    
                    for (idx, row_idx) in enumerate(effect_row_indices)
                        if p_values[row_idx] < alpha
                            significant_counts[idx] += 1
                        end
                        effect_sizes_sum[idx] += effect_sizes[row_idx]
                    end
                catch e
                    @minimal_warning "Simulation $sim failed: $e"
                    continue
                end
            end
        else
            # Multiple threads: use tasks for safe parallel execution
            tasks = Task[]
            for sim in 2:n_sims
                task = Threads.@spawn begin
                    task_counts = zeros(Int, n_effects)
                    task_sums = zeros(Float64, n_effects)
                    
                    try
                        sim_data = generate_sim_data(n)
                        result = _run_anova_on_sim_data(sim_data, between_factors, within_factors)
                        
                        p_values = result.table.p
                        effect_sizes = result.table.η²ₚ
                        
                        for (idx, row_idx) in enumerate(effect_row_indices)
                            if p_values[row_idx] < alpha
                                task_counts[idx] += 1
                            end
                            task_sums[idx] += effect_sizes[row_idx]
                        end
                    catch e
                        @minimal_warning "Simulation $sim failed: $e"
                    end
                    
                    (task_counts, task_sums)
                end
                push!(tasks, task)
            end
            
            # Wait for all tasks and combine results
            for task in tasks
                task_counts, task_sums = fetch(task)
                significant_counts .+= task_counts
                effect_sizes_sum .+= task_sums
            end
        end
    end
    
    # Calculate power and mean effect sizes (using pre-computed inverse)
    power_values = significant_counts .* inv_n_sims .* 100.0
    mean_effect_sizes = effect_sizes_sum .* inv_n_sims
    
    power_df = DataFrame(
        n = fill(n, length(effect_names)),
        Effect = effect_names,
        Power = power_values,
        EffectSize = mean_effect_sizes,
    )
    
    return PowerResult(between_dict, within_dict, power_df, n_sims, alpha)
end

"""
    _run_anova_on_sim_data(data, between_factors, within_factors)

Run ANOVA on simulated data with effect size calculations.
"""
function _run_anova_on_sim_data(data::DataFrame, between_factors::Vector{Symbol}, within_factors::Vector{Symbol})
    # Calculate effect sizes - use :pes (partial eta squared) 
    return anova(data, :dv, :id, 
                 between=isempty(between_factors) ? nothing : between_factors,
                 within=isempty(within_factors) ? nothing : within_factors,
                 effect_size=:pes, correction=:none)
end
