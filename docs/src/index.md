# AnovaFun.jl

```@docs
AnovaFun
```

A Julia package for analysis of factorial experiments, including repeated measures (within-subjects), between-subjects, and mixed designs, inspired by the R packages afex, ez and emmeans.

## Overview

AnovaFun.jl provides comprehensive ANOVA functionality for factorial experimental designs. The package implements traditional ANOVA methods with support for within-subjects (repeated measures), between-subjects, and mixed designs.

**Note**: This package implements a subset of features from R packages afex, ez, and emmeans, focusing on common ANOVA analyses. It has been tested against R's aov, ezANOVA, afex, emmeans, and JASP's ANOVA interface.

## Features

- **Between-subjects ANOVA** - Compare groups across independent subjects
- **Within-subjects (Repeated Measures) ANOVA** - Compare conditions within the same subjects
- **Mixed-design ANOVA** - Combine between and within factors
- **Estimated Marginal Means (emmeans)** - Calculate marginal means with confidence intervals
- **Pairwise Comparisons** - Post-hoc tests with multiple comparison adjustments
- **Sphericity Corrections** - Greenhouse-Geisser and Huynh-Feldt corrections
- **Effect Sizes** - η² (eta squared), partial η², and ω² (omega squared)
- **Interactive Plots** - Publication-quality plots via Makie
- **APA-formatted Tables** - PrettyTables integration for publication-ready output

## Quick Start

```julia
using AnovaFun

# Load your data (long format, one row per observation)
# data = CSV.read("your_data.csv", DataFrame)

# Between-subjects ANOVA
result = anova(data, :dv, :subject, between = [:group])

# Within-subjects ANOVA
result = anova(data, :dv, :subject, within = [:time])

# Mixed design
result = anova(data, :dv, :subject, between = [:group], within = [:time])

# View results
result.table  # ANOVA table

# Estimated marginal means
em = emmeans(result)

# Interactive plots
plot_anova(em, x_grouping = :time, y_grouping = :group)
```

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/igmmgi/AnovaFun.jl")
```

## Documentation

- [API Reference](@ref)

## Overview

AnovaFun.jl provides a comprehensive toolkit for ANOVA analysis, including:

- **Between-subjects ANOVA** - Compare groups across independent subjects
- **Within-subjects (Repeated Measures) ANOVA** - Compare conditions within the same subjects
- **Mixed-design ANOVA** - Combine between and within factors
- **Estimated Marginal Means (emmeans)** - Calculate marginal means with confidence intervals
- **Pairwise Comparisons** - Post-hoc tests with multiple comparison adjustments
- **Sphericity Corrections** - Greenhouse-Geisser and Huynh-Feldt corrections
- **Effect Sizes** - η² (eta squared), partial η², and ω² (omega squared)

## Installation

```julia
using Pkg
Pkg.add("AnovaFun")
```

## Quick Start

### Between-Subjects ANOVA

```julia
using AnovaFun, DataFrames

# 2x2 between-subjects design
result = anova(data, :score, :subject, between = [:group, :condition])
```

### Within-Subjects (Repeated Measures) ANOVA

```julia
result = anova(data, :score, :subject, within = [:time])

# With Greenhouse-Geisser correction
result = anova(data, :score, :subject, within = [:time], correction = :GG)
```

### Mixed-Design ANOVA

```julia
result = anova(data, :score, :subject, between = [:group], within = [:time])
```

### Estimated Marginal Means

```julia
em = emmeans(result)
em.means
```

### Pairwise Comparisons

```julia
pw = pairwise(em)                       # All pairwise comparisons
pw = pairwise(em, adjust = :bonferroni) # With Bonferroni correction
pw = pairwise(em, by = :time)           # For a specific effect only
```

## Data Format

Data should be in long format with one row per observation:

```julia
DataFrame(
    subject   = [1, 1, 1, 2, 2, 2, ...],
    group     = ["A", "A", "A", "B", "B", "B", ...],
    time      = ["T1", "T2", "T3", "T1", "T2", "T3", ...],
    score     = [23.1, 25.4, 24.2, 19.3, 21.5, 20.1, ...]
)
```

## Documentation Structure

- **[API Reference](api.md)**: Complete function and type documentation

## Index

```@index
```

