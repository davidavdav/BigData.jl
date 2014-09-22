BigData.jl
==========

Handle very tall matrices that are naturally split in separate files. 

BigData (admittedly, a somewhat grand name) provides some basic infrastructure for working with matrix-like data structures that are too large to fit in memory.  It provides methods to compute basic statistics over the data, an iterator and more. 

The basic premise is that the data is organized in a large collection of files, and that in each file a matrix is stored with the same number of columns, but a variable number of rows.  A typical example is a sequence of row-vectors stacked to form a matrix, and organized in files according to some production process.  

The idea is that tyical operations on the entire dataset can be carried out in parallel, and within one file sequentially, so that the data can be `streamed' from disc through parallel computation engines without the need for big or shared memory.  An example of such operation is the computation of the variance of all row vectors. 

Although the purpose of BigData is to work efficiently with data stored on disc, it will also work with segmented data already in memory, e.g., a `Vector` of `Matrix`s.  

Constructors
------------

```julia
d = Data(x::Vector{Matrix})
```
This creates a `Data` object formed by alist of matrices, which should all have the same number of columns. 

```julia
d = Data(list::Vector{String}, datatype::Type, read::Function)
```
This creates a `Data` object consisting of data stored in files in `list`.  The data can be loaded when needed by a function specified by `read`. 

Accessing individual parts
--------------------------

Regardless if the data is in memory or stored on disc, the actual data can be accessed by indexing or by iteration:
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

Parallell execution
-------------------
In principle, `pmap()` works on a `Data` object, bt it may be more efficient in a computing cluster to use a similar function, `dmap()`.  This function makes sure that the same file is always processed by the same CPU in the cluster, so that local caching of data may speed up the loading of the data into memory and reduce network traffic. 

```julia
## example of using dmap
d = Data(vec(readdlm("files.list", String)), Float64, myreaddata)
sums = dmap(sum, d)
```

Basic functions
---------------
In the following, `d` is of type `Data`. 
 - `size(d)` compute the total size of `d` when all data is stacked vertically.  It is verified that all elements of `d` have the same number of columns.  This may be very slow, because currently all data is read by the `read` function specified in the coonstructor, just to determine the resulting matric size.
 - `length(d)` show the number of sub-matrices listed in `d`. 
 - `eltype(d)` return the element type of the matrices in `d`. 
 - `sum(d)` return the overall sum of the elements in `d`. 
 - `sum(d, dim)` return the sum over `d` along dimension `dim`.  This is most efficient when `dim=1`. 
 - `stats(d, order=2, kind=:diag)` compute 0, 1th and 2nd order statistics of the data along dimension 1 (rows).  If `kind==:full`, the full 2nd order scatter matrix for the row data is returned. 
 - `mean(d)` comput the mean over rows
 - `var(d)` compute the variance over rows, touching all data only once. 
