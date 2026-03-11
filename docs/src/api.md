# API Reference

## Index

```@index
Pages = ["api.md"]
```

## Types

```@autodocs
Modules = [AnovaFun]
Order = [:type]
Filter = t -> !startswith(string(t), "_")
```

## Functions

```@autodocs
Modules = [AnovaFun]
Order = [:function, :macro]
Filter = t -> !startswith(string(t), "_")
```
