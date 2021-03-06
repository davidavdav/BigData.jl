BigData.jl
==========
[![Build Status](https://travis-ci.org/davidavdav/BigData.jl.svg)](https://travis-ci.org/davidavdav/BigData.jl)

Please Note: BigData.jl is now integrated with [GaussianMixtures.jl](https://github.com/davidavdav/GaussianMixtures.jl) which is incorporated in METADATA.  So you can install by `Pkg.add("GaussianMixtures")` in Julia. 

Handle very tall matrices that are naturally split in separate files. 

Synopsis
--------

```Julia
## generate some random data
x = [rand(1000+rand(0:10), 10) for i=1:10] 
d = Data(x)
s = zeros(size(d,2))'
for xx in d
  s += sum(xx, 1)
end
println(s)
## using a parallel computation
s = sum(vcat(dmap(x->sum(x,1), d)...),1)
## same, but use data from disc
## first write the data
using HDF5, JLD
files = String[]
for i=1:length(x)
    append!(files, [string(i, ".jld")])
    save(last(files), "data", x[i])
end
## then use it in a data structure
myread(f::String) = load(f, "data")
d = Data(files, Float64, myread)
s = zeros(size(d,2))'
for xx in d
  s += sum(xx, 1)
end
println(s)
## or, of course
sum(d,1)
```


BigData (admittedly, a somewhat grand name) provides some basic infrastructure for working with matrix-like data structures that are too large to fit in memory.  It provides methods to compute basic statistics over the data, an iterator and more. 

The basic premise is that the data is organized in a large collection of files, and that in each file a matrix is stored with the same number of columns, but a variable number of rows.  A typical example is a sequence of row-vectors stacked to form a matrix, and organized in files as a result of some production process.  

The idea is that tyical operations on the entire dataset can be carried out in parallel, and within one file sequentially, so that the data can be `streamed' from disc through parallel computation engines without the need for big or shared memory.  An example of such operation is the computation of the (co)variance of all row vectors. 

Although the purpose of BigData is to work efficiently with data stored on disc, it will also work with segmented data already in memory, e.g., a `Vector` of `Matrix`s.  

Constructors
------------

```julia
d = Data(x::Vector{Matrix})
```
This creates a `Data` object formed by a list of matrices, which should all have the same number of columns. 

```julia
d = Data(list::Vector{String}, datatype::Type, load::Function)
d = Data(list::Vector{String}, datatype::Type; load=Function, size=Function)
```
This creates a `Data` object consisting of data stored in files in `list`.  The data will be loaded when needed by means of a user function specified by `load`.  In the second form, one can also specify a `size()` function that can be more efficient than loading the entire matrix and determining the size afterwards. 

If no `load ` argument is given, the constructor supplies default functions that boil down to:
```julia
## default load function
function load(file::String)
    JLD.load(file, "data")
end

## default size function
function size(file::String)
    jldopen(file) do fd
        Base.size(fd["data"])
    end
end
```

Accessing individual parts
--------------------------

Regardless whether the data is in memory or stored on disc, the actual data can be accessed by indexing or by iteration:
```julia
## indexing
for i in 1:length(d)
  println(d[i])
end
## iteration
s = 0.
for x in d
  s += sum(x)
end
```
A range subset, as in `d[3:5]` is supported, and returns a new `Data` object representing a subset of the data, without the data being loaded into memory.  

Parallell execution
-------------------
In principle, `pmap()` works on a `Data` object, but it may be more efficient in a computing cluster to use a similar function, `dmap()`.  This function makes sure that the same file is always processed by the same CPU in the cluster, so that local caching of data may speed up the loading of the data into memory and reduce network traffic.  Also special care is taken that the actual loading of the data from disc happens on the machine that operates on the data, so that between-node julia-to-julia transfer is minimal. 

```julia
## example of using dmap
d = Data(vec(readdlm("files.list", String)), Float64, myreaddata)
sums = dmap(sum, d)
```
Please note that the example function `sum()` (especially the version from NumericExtensions) is very fast, and that parallell execution with loading data across a network is probably less efficient than serial execution on a single CPU.  However, if the first argument to `dmap()` is more CPU-intensive, this form of parallelization may be useful. 

Basic functions
---------------
In the following, `d` is of type `Data`. 
 - `size(d)` compute the total size of `d` when all data is stacked vertically.  It is verified that all elements of `d` have the same number of columns.  If there is not a special `size()` function declared at the construction of `d`, this operation may be very slow, because all data is read by the `read` function, just to determine the resulting matrix size.
 - `length(d)` show the number of sub-matrices listed in `d`. 
 - `eltype(d)` return the element type of the matrices in `d`. 
 - `collect(d)` turn the Data structure into a single matrix. 
 - `sum(d)` return the overall sum of the elements in `d`. 
 - `sum(d, dim)` return the sum over `d` along dimension `dim`.  This is most efficient when `dim=1`. 
 - `stats(d, order=2, kind=:diag, dim=1)` compute 0th, 1st, ..., `order`th order statistics of the data along dimension `dim`.  If `kind==:full`, the full 2nd order scatter matrix for the row data is returned. 
 - `mean(d [, dim])` compute the mean, optionally over dimension `dim`.  
 - `var(d [, dim])` compute the variance over rows (or columns if `dim=1`), touching all data only once.  
 - `cov(d)` compute the covariance over row vectors.  

All of these functions may be less efficient than their counterparts from NumericExtensions, and this will hold especially if the data needs to be loaded from disc.  The main application for these functions is with `dim=1`, but we have also implementations without `dim` argument and with `dim=2`.  

Usage
-----
Once the data (or the file lists) is loaded into a `Data` object, it is easiest to work with the iterator (`for x in d`) or index constructions (`for i = 1:length(d) somefunction(d[i]) end`).   Some functionality can quite effectively be obtained using the general `stats()` function.  For instance, consider the implementation of `cov()` below:

```julia
function Base.cov(d::Data)
    n, sx, sxx = stats(d, 2, kind=:full)
    μ = sx ./ n
    (sxx - n*μ*μ') ./ (n-1)
end
```
