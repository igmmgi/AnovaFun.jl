"""
    power_analysis(n; within=nothing, between=nothing, mu, sd, r=nothing, n_sims=1000, alpha=0.05)

Perform power analysis for an ANOVA design using simulation, similar to Superpower's ANOVA_power.

# Arguments
- `n::Int`: Number of subjects/participants (positional argument)
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
                        mu=[1.0, 1.0, 1.0, 2.0], 
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
    between_factors, within_factors, labelnames, _ = _process_factors(within, between)
    
    # Convert to Dict format for PowerResult (using strings from labelnames)
    between_dict = isempty(between_factors) ? nothing : Dict(factor => labelnames[factor] for factor in between_factors)
    within_dict = isempty(within_factors) ? nothing : Dict(factor => labelnames[factor] for factor in within_factors)
    
    # Use simulate_data to generate data (it handles all the parameter normalization)
    return _power_simulation(n, between_factors, within_factors, mu, sd, r, labelnames, n_sims, alpha, between_dict, within_dict)
end

"""
    _power_simulation(n, between_factors, within_factors, mu, sd, r, labelnames, n_sims, alpha, between_dict, within_dict)

Simulation-based power analysis.
"""
function _power_simulation(
    n::Int,
    between_factors::Vector{Symbol},
    within_factors::Vector{Symbol},
    mu::Union{Real, Vector{<:Real}},
    sd::Union{Real, Vector{<:Real}},
    r::Union{Real, Vector{<:Real}, Nothing},
    labelnames::Dict{Symbol, Vector{String}},
    n_sims::Int,
    alpha::Float64,
    between_dict::Union{Dict{Symbol, Vector{String}}, Nothing},
    within_dict::Union{Dict{Symbol, Vector{String}}, Nothing},
)
    
    # Initialize effect tracking on first iteration
    effect_names = String[]
    effect_indices = Dict{String, Int}()  # Map effect names to array indices
    significant_counts = Int[]
    effect_sizes_sum = Float64[]
    initialized = false
    
    for sim in 1:n_sims
        # Generate simulated data using simulate_data (handles all normalization)
        sim_data = simulate_data(n, within=within_dict, between=between_dict, mu=mu, sd=sd, r=r)
        
        # Run ANOVA with effect sizes
        try
            result = _run_anova_on_sim_data(sim_data, between_factors, within_factors)
            
            # Initialize tracking on first successful simulation with pre-allocated arrays
            if !initialized
                n_effects = 0
                for i in 1:nrow(result.table)
                    effect = result.table.Effect[i]
                    if effect != "Intercept"
                        n_effects += 1
                        push!(effect_names, effect)
                        effect_indices[effect] = n_effects
                    end
                end
                # Pre-allocate arrays for tracking
                significant_counts = zeros(Int, n_effects)
                effect_sizes_sum = zeros(Float64, n_effects)
                initialized = true
            end
            
            # Check which effects are significant and track effect sizes using array indexing
            for i in 1:nrow(result.table)
                effect = result.table.Effect[i]
                if effect != "Intercept"
                    idx = effect_indices[effect]
                    if result.table.p[i] < alpha
                        significant_counts[idx] += 1
                    end
                    # Track effect size - the column name is :η²ₚ (partial eta squared)
                    effect_sizes_sum[idx] += result.table.η²ₚ[i]
                end
            end
        catch e
            @minimal_warning "Simulation $sim failed: $e"
            continue
        end
    end
    
    # Calculate power and mean effect sizes (in-place, no allocations)
    power_values = significant_counts ./ n_sims .* 100.0
    mean_effect_sizes = effect_sizes_sum ./ n_sims
    
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
    between = isempty(between_factors) ? nothing : between_factors
    within = isempty(within_factors) ? nothing : within_factors
    # Calculate effect sizes - use :pes (partial eta squared) 
    return anova(data, :dv, :id, between=between, within=within, effect_size=:pes, correction=:none)
end
