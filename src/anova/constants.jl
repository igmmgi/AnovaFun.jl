# ANOVA-related constants

# P-value thresholds for significance markers in output
const P_VALUE_THRESHOLD_001 = 0.001  # Display: ***
const P_VALUE_THRESHOLD_01 = 0.01    # Display: **
const P_VALUE_THRESHOLD_05 = 0.05    # Display: *

# Sphericity test constants
const MIN_LEVELS_FOR_SPHERICITY = 3   # Minimum levels needed for meaningful sphericity test (2 levels = automatic)
const MIN_DF_FOR_SPHERICITY = 2       # Minimum degrees of freedom for sphericity test (1 df = 2 levels = automatic)
const PERFECT_SPHERICITY_W = 1.0      # W statistic for perfect sphericity (2 levels case)
const PERFECT_SPHERICITY_P = 1.0      # p-value when sphericity holds perfectly (2 levels case)
