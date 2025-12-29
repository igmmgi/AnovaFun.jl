using Documenter

# Add the parent directory to the load path so we can load the local package
push!(LOAD_PATH, dirname(@__DIR__))

# Use CairoMakie for headless documentation builds (no OpenGL required)
using CairoMakie
CairoMakie.activate!()

# Load AnovaFun after backend setup
using AnovaFun

# Set up the documentation
makedocs(
    sitename = "AnovaFun",
    modules = [AnovaFun],  # Include modules for proper cross-referencing
    pages = [
        "Home" => "index.md",
        "API Reference" => "api.md",
    ],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        assets = String[],
        size_threshold = nothing,  
    ),
    doctest = true,
    checkdocs = :exports,  
)

