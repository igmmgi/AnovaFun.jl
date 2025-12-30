"""
    power_analysis(n; within=nothing, between=nothing, mu, sd, r=nothing, n_sims=1000, alpha=0.05, pairwise=false)

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
- `pairwise::Bool`: Whether to compute pairwise comparison power (default: false)

# Returns
A `PowerResult` object containing:
- Power estimates and effect sizes (partial eta-squared) for each ANOVA effect
- Power and effect sizes (Cohen's d) for pairwise comparisons (all pairwise comparisons across all cell means), if `pairwise=true`

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
    pairwise::Bool = false,
)
    # Extract factor names and convert labels to strings
    between_factors, within_factors, labelnames, factor_levels = _process_factors(within, between)
    
    # Convert per-group n to total n for between-subjects designs
    total_n = _calculate_total_n(n, between_factors, factor_levels)
    
    # Convert to Dict format for PowerResult (using strings from labelnames)
    between_dict = isempty(between_factors) ? nothing : Dict(factor => labelnames[factor] for factor in between_factors)
    within_dict = isempty(within_factors) ? nothing : Dict(factor => labelnames[factor] for factor in within_factors)
    
    # Use simulate_data to generate data (it handles all the parameter normalization)
    result = _power_simulation(total_n, between_factors, within_factors, mu, sd, r, n_sims, alpha, pairwise, between_dict, within_dict, labelnames, factor_levels)
    
    # Update power_df to show per-group n instead of total n
    result.power.n .= n
    if !isnothing(result.pairwise)
        result.pairwise.n .= n
    end
    
    return result
end

"""
    _calculate_cohens_d(t_stat, df, n, between_factors, within_factors, labelnames)

Calculate Cohen's d from a t-statistic for pairwise comparisons.
"""
function _calculate_cohens_d(
    t_stat::Float64,
    df::Int,
    n::Int,
    between_factors::Vector{Symbol},
    within_factors::Vector{Symbol},
    labelnames::Dict{Symbol, Vector{String}},
)
    if !isfinite(t_stat)
        return 0.0
    end
    
    cohens_d = if !isempty(between_factors) && isempty(within_factors)
        # Pure between-subjects: d = |t| * sqrt(2/n_per_group)
        n_groups = prod(length(labelnames[f]) for f in between_factors)
        n_per_group = n ÷ n_groups
        n_per_group > 0 ? abs(t_stat) * sqrt(2.0 / n_per_group) : 0.0
    else
        # Within-subjects or mixed: d = |t| / sqrt(n_effective)
        n_effective = df + 1
        n_effective > 0 ? abs(t_stat) / sqrt(n_effective) : 0.0
    end
    
    return isfinite(cohens_d) ? cohens_d : 0.0
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
    compute_pairwise::Bool,
    between_dict::Union{Dict{Symbol, Vector{String}}, Nothing},
    within_dict::Union{Dict{Symbol, Vector{String}}, Nothing},
    labelnames::Dict{Symbol, Vector{String}},
    factor_levels::Dict{Symbol, Int},
)

    _, _, r_vec, cell_params = _normalize_sim_inputs(
        between_factors,
        within_factors,
        mu,
        sd,
        r,
        factor_levels,
        labelnames,
    )
    
    # Initialize effect structure by running one simulation first
    # We need this to know which effects exist and their order before allocating arrays
    effect_names = String[]
    effect_row_indices = Int[]
    n_effects = 0
    
    # Run first simulation to determine effect structure
    sim_data = _generate_data(n, between_factors, within_factors, cell_params, r_vec, labelnames, factor_levels)
    first_result = _run_anova_on_sim_data(sim_data, between_factors, within_factors)
    
    # Extract effect structure (skip Intercept)
    for i in 1:nrow(first_result.table)
        effect = first_result.table.Effect[i]
        if effect != "Intercept"
            n_effects += 1
            push!(effect_names, effect)
            push!(effect_row_indices, i)
        end
    end
    
    # Compute pairwise comparisons for initialization (if requested)
    first_pw_result = nothing
    first_pw_comparisons = String[]
    n_comparisons = 0
    
    if compute_pairwise
        em = emmeans(first_result)
        pw = pairwise(em, simple=nothing, adjust=:none)
        
        first_pw_result = pw
        first_pw_comparisons = [row.Contrast for row in eachrow(pw.table)]
        n_comparisons = length(first_pw_comparisons)
    end
    
    # Pre-compute inverse of n_sims to avoid repeated division
    inv_n_sims = 1.0 / n_sims
    
    # Pre-allocate arrays for tracking (will be combined from threads)
    significant_counts = zeros(Int, n_effects)
    effect_sizes_sum = zeros(Float64, n_effects)
    
    # Pre-allocate arrays for pairwise tracking
    pw_significant_counts = zeros(Int, n_comparisons)
    pw_effect_sizes_sum = zeros(Float64, n_comparisons)
    
    # Add results from first simulation 
    p_values = first_result.table.p
    effect_sizes = first_result.table.η²ₚ
    
    for (idx, row_idx) in enumerate(effect_row_indices)
        if p_values[row_idx] < alpha
            significant_counts[idx] += 1
        end
        effect_sizes_sum[idx] += effect_sizes[row_idx]
    end
    
    # Add pairwise results from first simulation
    if compute_pairwise
        for (idx, row) in enumerate(eachrow(first_pw_result.table))
            if row.p < alpha
                pw_significant_counts[idx] += 1
            end
            cohens_d = _calculate_cohens_d(row.t, row.df, n, between_factors, within_factors, labelnames)
            pw_effect_sizes_sum[idx] += cohens_d
        end
    end
    
    # Run remaining simulations in parallel using tasks
    if n_sims > 1
        tasks = Task[]
        for sim in 2:n_sims

            task = Threads.@spawn begin
                task_counts = zeros(Int, n_effects)
                task_sums = zeros(Float64, n_effects)
                task_pw_counts = zeros(Int, n_comparisons)
                task_pw_sums = zeros(Float64, n_comparisons)
                
                try
                    sim_data = _generate_data(n, between_factors, within_factors, cell_params, r_vec, labelnames, factor_levels)
                    result = _run_anova_on_sim_data(sim_data, between_factors, within_factors)
                    
                    for (idx, row_idx) in enumerate(effect_row_indices)
                        if result.table.p[row_idx] < alpha
                            task_counts[idx] += 1
                        end
                        task_sums[idx] += result.table.η²ₚ[row_idx]
                    end
                    
                    # Compute pairwise comparisons
                    if compute_pairwise
                        em = emmeans(result)
                        pw = pairwise(em, simple=nothing, adjust=:none)
                        
                        for (idx, (pw_row, sim_row)) in enumerate(zip(eachrow(first_pw_result.table), eachrow(pw.table)))
                            if strip(pw_row.Contrast) == strip(sim_row.Contrast)
                                if sim_row.p < alpha
                                    task_pw_counts[idx] += 1
                                end
                                cohens_d = _calculate_cohens_d(sim_row.t, sim_row.df, n, between_factors, within_factors, labelnames)
                                task_pw_sums[idx] += cohens_d
                            end
                        end
                    end
                catch e
                    @minimal_warning "Simulation $sim failed: $e"
                end
                
                (task_counts, task_sums, task_pw_counts, task_pw_sums)
            end
            push!(tasks, task)
        end
        
        # Wait for all tasks and combine results
        for task in tasks
            task_counts, task_sums, task_pw_counts, task_pw_sums = fetch(task)
            significant_counts .+= task_counts
            effect_sizes_sum .+= task_sums
            pw_significant_counts .+= task_pw_counts
            pw_effect_sizes_sum .+= task_pw_sums
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
    
    # Build pairwise DataFrame (if computed)
    pairwise_df = nothing
    if compute_pairwise
        pw_power_values = pw_significant_counts .* inv_n_sims .* 100.0
        pw_mean_effect_sizes = pw_effect_sizes_sum .* inv_n_sims
        
        pairwise_df = DataFrame(
            n = fill(n, n_comparisons),
            Comparison = first_pw_comparisons,
            Power = pw_power_values,
            EffectSize = pw_mean_effect_sizes,
        )
    end
    
    return PowerResult(between_dict, within_dict, power_df, pairwise_df, n_sims, alpha)
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

