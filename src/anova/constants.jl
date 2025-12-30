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

# Pairwise comparison adjustment methods (currently implemented)
const PAIRWISE_ADJUST_NONE = :none
const PAIRWISE_ADJUST_BONFERRONI = :bonferroni
const PAIRWISE_ADJUST_SIDAK = :sidak