"""
Basic t-test functions 
"""

# PAIRED T-TEST
"""
    paired_ttest(x::AbstractVector, y::AbstractVector; tail::Symbol = :both)

Compute paired t-test with degrees of freedom, t-statistic, and p-value.
Also returns Cohen's dz (reported as `dz`).

# Arguments
- `x::AbstractVector`: First condition data (must have same length as y)
- `y::AbstractVector`: Second condition data (must have same length as x)
- `tail::Symbol`: Type of test - `:both` (two-tailed, default), `:left` (one-tailed, A < B), or `:right` (one-tailed, A > B)

# Returns
- Named tuple with fields:
  - `df`: degrees of freedom
  - `t`: t-statistic
  - `p`: p-value (returns `NaN` if `t` is `NaN`/`Inf`)
  - `dz`: Cohen's dz computed as mean(diff) / std(diff)
"""
function paired_ttest(x::AbstractVector, y::AbstractVector; tail::Symbol=:both)

    # validate equal lengths
    length(x) == length(y) || error("Paired t-test requires equal sample sizes")

    n = length(x)
    n < 2 && return (df=NaN, t=NaN, p=NaN, dz=NaN)  # Need at least 2 observations

    df = n - 1  # degrees of freedom for paired t-test

    # Compute mean and std of differences 
    diff = x .- y
    mean_diff = mean(diff)
    std_diff = std(diff, corrected=true)  # Sample standard deviation (n-1)

    # Compute t-value
    if std_diff == 0.0
        if mean_diff == 0.0
            t = NaN
        else
            t = Inf * sign(mean_diff)
        end
    else
        t = mean_diff / (std_diff / sqrt(n))
    end

    # Handle edge cases
    if isnan(t) || isinf(t)
        return (df=df, t=t, p=NaN, dz=NaN)
    end

    # Effect size (Cohen's dz)
    dz = std_diff == 0.0 ? NaN : abs((mean_diff / std_diff))

    # Compute p-value
    dist = TDist(df)
    if tail == :both # Two-tailed test
        p = 2 * (1 - cdf(dist, abs(t)))
    elseif tail == :left # One-tailed: H0: A >= B, H1: A < B
        p = cdf(dist, t)
    elseif tail == :right # One-tailed: H0: A <= B, H1: A > B
        p = 1 - cdf(dist, t)
    else
        error("tail must be :both, :left, or :right, got :$tail")
    end

    return (df=df, t=t, p=p, dz=dz)
end

# INDEPENDENT T-TEST
"""
    independent_ttest(x::AbstractVector, y::AbstractVector; tail::Symbol = :both)

Compute independent sample t-test with degrees of freedom, t-statistic, and p-value.
Assumes equal variances (standard independent t-test).
Also returns Cohen's d (reported as `d`).

# Arguments
- `x::AbstractVector`: First group data (must have at least 2 observations)
- `y::AbstractVector`: Second group data (must have at least 2 observations)
- `tail::Symbol`: Type of test - `:both` (two-tailed, default), `:left` (one-tailed, A < B), or `:right` (one-tailed, A > B)

# Returns
- Named tuple with fields:
  - `df`: degrees of freedom
  - `t`: t-statistic
  - `p`: p-value (returns `NaN` if `t` is `NaN`/`Inf`)
  - `d`: Cohen's d using pooled SD
"""
function independent_ttest(x::AbstractVector, y::AbstractVector; tail::Symbol=:both)

    # Validate input lengths
    n_A, n_B = length(x), length(y)
    (n_A < 2 || n_B < 2) &&
        error("Independent t-test requires at least 2 observations per group")

    df = n_A + n_B - 2  # degrees of freedom for independent t-test

    # Compute means and variances (Statistics.jl is already optimized with SIMD)
    mean_x, mean_y = mean(x), mean(y)

    # Pooled variance (assuming equal variances)
    var_x = var(x, corrected=true)
    var_y = var(y, corrected=true)
    pooled_var = ((n_A - 1) * var_x + (n_B - 1) * var_y) / df
    pooled_sd = sqrt(pooled_var)

    # Compute t-value
    if pooled_var == 0.0
        if mean_x == mean_y
            t = NaN  # Both groups identical
        else
            t = Inf * sign(mean_x - mean_y)
        end
    else
        t = (mean_x - mean_y) / sqrt(pooled_var * (1 / n_A + 1 / n_B))
    end

    # Handle edge cases
    if isnan(t) || isinf(t)
        return (df=df, t=t, p=NaN, d=NaN)
    end

    # Effect size (Cohen's d, pooled SD)
    d = pooled_sd == 0.0 ? NaN : abs(((mean_x - mean_y) / pooled_sd))

    # Compute p-value
    dist = TDist(df)
    if tail == :both # Two-tailed test
        p = 2 * (1 - cdf(dist, abs(t)))
    elseif tail == :left # One-tailed: H0: A >= B, H1: A < B
        p = cdf(dist, t)
    elseif tail == :right # One-tailed: H0: A <= B, H1: A > B
        p = 1 - cdf(dist, t)
    else
        error("tail must be :both, :left, or :right, got :$tail")
    end

    return (df=df, t=t, p=p, d=d)
end

# DATAFRAME DISPATCH METHODS
"""
    paired_ttest(df::DataFrame, col::Symbol; by::Symbol, levels = nothing, tail::Symbol = :both)

Convenience method for paired t-test from a DataFrame.

Splits `df` by the `by` column into exactly two groups and runs a paired t-test
on the values in `col`.

# Arguments
- `df::DataFrame`: DataFrame containing the data
- `col::Symbol`: Column to test
- `by::Symbol`: Grouping column (must have exactly 2 unique values, or use `levels`)
- `levels`: Optional vector of 2 values to select from `by` column (useful when >2 groups exist)
- `tail::Symbol`: Type of test (`:both`, `:left`, or `:right`)

# Examples
```julia
# Auto-detect two groups
paired_ttest(df, :dv_col, by = :grouping_col)

# Specify which two groups to compare
paired_ttest(df, :dv_col, by = :grouping_col, levels = [1, 2])
```
"""
function paired_ttest(df::DataFrame, col::Symbol; by::Symbol, levels=nothing, tail::Symbol=:both)
    groups = isnothing(levels) ? sort(unique(df[!, by])) : levels
    length(groups) == 2 || error("Expected 2 groups in column :$by, got $(length(groups)). Use `levels` to specify which pair to compare.")
    x = df[df[!, by].==groups[1], col]
    y = df[df[!, by].==groups[2], col]
    return paired_ttest(x, y; tail=tail)
end

"""
    independent_ttest(df::DataFrame, col::Symbol; by::Symbol, levels = nothing, tail::Symbol = :both)

Convenience method for independent t-test from a DataFrame.

Splits `df` by the `by` column into exactly two groups and runs an independent t-test
on the values in `col`.

# Arguments
- `df::DataFrame`: DataFrame containing the data
- `col::Symbol`: Column to test
- `by::Symbol`: Grouping column (must have exactly 2 unique values, or use `levels`)
- `levels`: Optional vector of 2 values to select from `by` column (useful when >2 groups exist)
- `tail::Symbol`: Type of test (`:both`, `:left`, or `:right`)

# Examples
```julia
# Auto-detect two groups
independent_ttest(df, :dv_col, by = :grouping_col)

# Specify which two groups to compare
independent_ttest(df, :dv_col, by = :grouping_col, levels = [1, 2])
```
"""
function independent_ttest(df::DataFrame, col::Symbol; by::Symbol, levels=nothing, tail::Symbol=:both)
    groups = isnothing(levels) ? sort(unique(df[!, by])) : levels
    length(groups) == 2 || error("Expected 2 groups in column :$by, got $(length(groups)). Use `levels` to specify which pair to compare.")
    x = df[df[!, by].==groups[1], col]
    y = df[df[!, by].==groups[2], col]
    return independent_ttest(x, y; tail=tail)
end
