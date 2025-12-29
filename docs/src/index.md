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

