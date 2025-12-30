# ANOVA-related constants

# P-value thresholds for significance markers in output
const P_VALUE_THRESHOLD_001 = 0.001  # Display: ***
const P_VALUE_THRESHOLD_01 = 0.01    # Display: **
const P_VALUE_THRESHOLD_05 = 0.05    # Display: *

# Effect size types
const EFFECT_SIZE_NONE = :none
const EFFECT_SIZE_ES = :es      # eta squared (η²)
const EFFECT_SIZE_PES = :pes    # partial eta squared (η²ₚ)
const EFFECT_SIZE_OS = :os      # omega squared (ω²)

# Sphericity correction types
const CORRECTION_NONE = :none
const CORRECTION_GG = :GG       # Greenhouse-Geisser
const CORRECTION_HF = :HF       # Huynh-Feldt

# Pairwise comparison adjustment methods
const PAIRWISE_ADJUST_NONE = :none
const PAIRWISE_ADJUST_BONFERRONI = :bonferroni
const PAIRWISE_ADJUST_HOLM = :holm
const PAIRWISE_ADJUST_HOCHBERG = :hochberg
const PAIRWISE_ADJUST_HOMMEL = :hommel
const PAIRWISE_ADJUST_BH = :bh           # Benjamini-Hochberg
const PAIRWISE_ADJUST_BY = :by           # Benjamini-Yekutieli
const PAIRWISE_ADJUST_SIDAK = :sidak
const PAIRWISE_ADJUST_SIDAK_SINGLE = :sidak_single

# Error bar types
const ERRORBAR_NONE = :none
const ERRORBAR_EMMEANS = :emmeans
const ERRORBAR_WITHIN = :within

# Individual data display types
const INDIVIDUAL_DATA_NONE = :none
const INDIVIDUAL_DATA_POINTS = :points
const INDIVIDUAL_DATA_CONNECTED = :connected_points

# Plot types
const PLOT_TYPE_LINE = :line
const PLOT_TYPE_BAR = :bar
const PLOT_TYPE_VIOLIN = :violin
const PLOT_TYPE_BOXPLOT = :boxplot
const PLOT_TYPE_RAIN_CLOUD = :raincloud