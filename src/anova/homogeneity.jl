"""
    check_homogeneity(result::AnovaResult; center::Function=mean)

Levene's test for homogeneity of variance (equal variances across groups).

For between-subjects designs, tests whether variances are equal across groups defined by
between-subjects factors. For mixed designs, tests are performed on the between-subjects
grouping factors. 

# Arguments
- `result::AnovaResult`: ANOVA result object
- `center::Function`: Centering function: `mean` or `median` 

# Returns
An `AnovaResult` object (same as `anova()`), containing:
- `table`: ANOVA table with test statistics
- `design`: Design information
- `model`: Fitted linear model
- Other accessor methods (see `anova()` documentation)

The main effect in the table (group) tests variance homogeneity across all group combinations. 

# Examples
```julia
result = anova(data, :dv, :subject, between=[:group])
check_homogeneity(result)  
```
"""
function check_homogeneity(result::AnovaResult; center::Function = mean)

    # we need at leave one between-subject factor
    bf = result.design.between_factors
    isempty(bf) && throw(
        ArgumentError("Levene's test requires at least one between-subjects factor. "),
    )

    # aggregate across any within-subjects factors to get one row per subject × between-subjects combination
    data_agg = aggregate(result.data, result.dv, result.id, nothing, bf)

    # compute group centers and add them the aggregated data
    data_agg = transform(groupby(data_agg, bf), result.dv => center => :group_center)

    # compute absolute deviations
    data_agg[!, result.dv] = abs.(data_agg[!, result.dv] .- data_agg.group_center)

    # combined factor for all group combinations
    data_agg[!, :group] =
        [join([string(row[f]) for f in bf], "_") for row in eachrow(data_agg)]

    # this is the final data that we actually need for the anova
    levene_data = select(data_agg, [result.id, :group, result.dv])

    # and in the end we have an anova 
    return anova(levene_data, result.dv, result.id, between = [:group], effect_size = :none)

end
