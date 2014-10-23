module BigData ## a somewhat grand name

using NumericExtensions
using HDF5, JLD

include("types.jl")
include("data.jl")

export Data, DataOrMatrix, kind, dmap, stats
end
