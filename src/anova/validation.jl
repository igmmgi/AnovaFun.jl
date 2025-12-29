"""
    validate_anova_inputs(data, dv, id, within, between, correction, effect_size)

Centralized validation for all ANOVA inputs. Throws informative errors for invalid inputs.
"""
function validate_anova_inputs(data, dv, id, within, between, correction, effect_size)
    # Validate DataFrame
    validate_dataframe(data)

    # Validate required columns
    validate_column_exists(data, dv, "dependent variable")
    validate_column_exists(data, id, "id identifier")

    # Validate DV is numeric
    validate_numeric_column(data, dv)

    # Validate no missing values in critical columns
    validate_no_missing_critical(data, dv, id)

    # Validate factors
    validate_all_factors(data, within, between)

    # Validate kwargs
    validate_correction(correction)
    validate_effect_size(effect_size)

    # Check data balance (warnings only)
    check_data_balance(data, id, within, between)
end

# ============================================================================
# Validation Helper Functions
# ============================================================================

function validate_dataframe(data)
    if !isa(data, AbstractDataFrame)
        throw(ArgumentError("First argument must be a DataFrame, got $(typeof(data))."))
    end
    if nrow(data) == 0
        throw(ArgumentError("DataFrame is empty (0 rows)."))
    end
end

function validate_column_exists(data::AbstractDataFrame, col::Symbol, description::String)
    if !(col in propertynames(data))
        available = join(string.(propertynames(data)), ", ")
        throw(
            ArgumentError(
                "Column '$col' ($description) not found in data. Available columns: $available",
            ),
        )
    end
end

function validate_numeric_column(data::AbstractDataFrame, col::Symbol)
    if !(eltype(data[!, col]) <: Number)
        throw(
            ArgumentError(
                "Dependent variable '$col' must be numeric, got $(eltype(data[!, col])).",
            ),
        )
    end
end

function validate_no_missing_critical(data::AbstractDataFrame, dv::Symbol, id::Symbol)
    missing_dv = count(ismissing, data[!, dv])
    missing_id = count(ismissing, data[!, id])

    if missing_dv > 0
        throw(
            ArgumentError(
                "Dependent variable '$dv' contains $missing_dv missing value(s).",
            ),
        )
    end
    if missing_id > 0
        throw(ArgumentError("id identifier '$id' contains $missing_id missing value(s)."))
    end
end

function validate_all_factors(data::AbstractDataFrame, within, between)
    # Check at least one factor specified
    if (isnothing(within) || (within isa AbstractVector && isempty(within))) &&
       (isnothing(between) || (between isa AbstractVector && isempty(between)))
        throw(ArgumentError("No factors specified."))
    end

    # Validate within factors
    if !isnothing(within) && !isempty(within)
        _validate_factors(within, "Within-subjects")
        for factor in within
            validate_column_exists(data, factor, "within-subjects factor")
            validate_factor_levels(data, factor, "within-subjects")
        end
    end

    # Validate between factors
    if !isnothing(between) && !isempty(between)
        _validate_factors(between, "Between-subjects")
        for factor in between
            validate_column_exists(data, factor, "between-subjects factor")
            validate_factor_levels(data, factor, "between-subjects")
        end
    end

    # Check for overlap
    if !isnothing(within) && !isnothing(between) && !isempty(within) && !isempty(between)
        overlap = intersect(within, between)
        if !isempty(overlap)
            throw(
                ArgumentError(
                    "Factor(s) specified as both within and between: $(overlap).",
                ),
            )
        end
    end
end

function validate_factor_levels(
    data::AbstractDataFrame,
    factor::Symbol,
    factor_type::String,
)
    levels = unique(skipmissing(data[!, factor]))
    n_levels = length(levels)

    if n_levels < 2
        throw(
            ArgumentError(
                "$factor_type factor '$factor' has only $n_levels level(s). ANOVA requires at least 2 levels per factor. Current levels: $(levels)",
            ),
        )
    end
end

function validate_correction(correction::Symbol)
    if correction ∉ [:none, :GG, :HF]
        throw(
            ArgumentError(
                "Invalid sphericity correction: $correction. Valid options: :none, :GG (Greenhouse-Geisser), :HF (Huynh-Feldt)",
            ),
        )
    end
end

function validate_effect_size(effect_size::Symbol)
    if effect_size ∉ [:none, :es, :pes, :os]
        throw(
            ArgumentError(
                "Invalid effect size: $effect_size. Valid options: :none, :es (eta squared), :pes (partial eta squared), :os (omega squared)",
            ),
        )
    end
end

# ============================================================================
# Data Balance Checking (Warnings)
# ============================================================================

function check_data_balance(data::AbstractDataFrame, id::Symbol, within, between)
    # Check within-subjects balance
    if !isnothing(within) && !isempty(within)
        missing_count = check_within_balance(data, id, within)
        if missing_count > 0
            @minimal_warning "Unbalanced within-subjects design: $missing_count id(s) have missing observations"
        end
    end

    # Check between-subjects balance
    if !isnothing(between) && !isempty(between)
        counts = check_between_balance(data, id, between)
        if !all_equal(counts)
            min_n, max_n = extrema(counts)
            @minimal_warning "Unbalanced between-subjects design: group sizes range from $min_n to $max_n subjects"
        end
    end
end

function check_within_balance(data::AbstractDataFrame, id::Symbol, within)
    # Expected number of observations per subject
    within_levels = [length(unique(data[!, f])) for f in within]
    expected_obs = prod(within_levels)

    # Count subjects with missing observations
    obs_counts = combine(groupby(data, id), nrow => :n_obs)
    missing_count = count(row -> row.n_obs != expected_obs, eachrow(obs_counts))

    return missing_count
end

function check_between_balance(data::AbstractDataFrame, id::Symbol, between)
    group_counts = combine(groupby(data, between), id => (x -> length(unique(x))) => :n_id)
    return group_counts.n_id
end

all_equal(x) = all(==(first(x)), x)
