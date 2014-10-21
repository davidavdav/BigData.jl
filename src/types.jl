## types.jl
## (c) 2014 Davod A. van Leewen

## A data handle, either in memory or on disk, perhaps even mmapped but I haven't seen any 
## advantage of that.  It contains a list of either files (where the data is stored)
## or data units.  The point is, that in processing, these units can naturally be processed
## independently.  

## The API is a dictionary of functions that help loading the data into memory
## Compulsory is: :load, useful is: size
type Data
    datatype::Type
    list::Vector
    API::Dict
end

typealias DataOrMatrix{T} Union(Data, Matrix{T})
