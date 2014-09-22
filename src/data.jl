## data.jl Julia code to handle matrix-type data on disc

# require("gmmtypes.jl")

using NumericExtensions

## constructor for a plain matrix.  rowvectors: data points x represented as rowvectors
function Data{T<:FloatingPoint}(x::Matrix{T}, rowvectors=true) 
    if rowvectors
        Data(T, Matrix{T}[x], nothing)
    else
        Data(T, Matrix{T}[x'], nothing)
    end
end

## constructor for a vector of plain matrices
## x = Matrix{Float64}[rand(1000,10), rand(1000,10)]
function Data{T<:FloatingPoint}(x::Vector{Matrix{T}}, rowvectors=true)
    if rowvectors
        Data(T, x, nothing)
    else
        Data(T, map(transpose, x), nothing)
    end
end

## constructor for a plain file.
function Data(file::String, datatype::Type, read::Function)
    Data(datatype, [file], read)
end

## constructor for a vector of files
function Data{S<:String}(files::Vector{S}, datatype::Type, read::Function)
    Data(datatype, files, read)
end

kind(x::Data) = eltype(x.list) <: String ? :file : :matrix

function getindex(x::Data, i::Int) 
    if kind(x) == :matrix
        x.list[i]
    else
        x.read(x.list[i])
    end
end

function getindex(x::Data, r::Range1)
    Data(x.datatype, x.list[r], x.read)
end

## define an iterator for Data
Base.length(x::Data) = length(x.list)
Base.start(x::Data) = 0
Base.next(x::Data, state::Int) = x[state+1], state+1
Base.done(x::Data, state::Int) = state == length(x)
Base.eltype(x::Data) = x.datatype

## This function is like pmap(), but executes each element of Data on a predestined
## worker, so that file caching at the local machine is beneficial
function dmap(f::Function, x::Data)
    if kind(x) == :file
        nx = length(x)
        w = workers()
        nw = length(w)
        worker(i) = w[1 .+ ((i-1) % nw)]
        results = cell(nx)
        getnext(i) = x.list[i]
        read = x.read
        @sync begin
            for i = 1:nx
                @async begin
                    next = getnext(i)
                    results[i] = remotecall_fetch(worker(i), s->f(read(s)), next)
                end
            end
        end
        results
    else
        pmap(f, x)
    end
end

## stats: compute nth order stats for array
function stats{T<:FloatingPoint}(x::Matrix{T}, order::Int=2; kind=:diag)
    n, d = size(x)
    if kind == :diag
        if order == 2
            return n, vec(sum(x,1)), vec(sumsq(x, 1))   # NumericExtensions is fast
        elseif order == 1
            return n, vec(sum(x,1))
        else
            sx = zeros(T, order, d)
            for j=1:d
                for i=1:n
                    xi = xp = x[i,j]
                    sx[1,j] += xp
                    for o=2:order
                        xp *= xi
                        sx[o,j] += xp
                    end
                end
            end
            return {n, map(i->vec(sx[i,:]), 1:order)...}
        end
    elseif kind == :full
        order == 2 || error("Can only do covar starts for order=2")
        ## lazy implementation
        sx = vec(sum(x, 1))
        sxx = x' * x
        return {n, sx, sxx}
    end
end

## Helper functions for stats tuples:
## This relies on sum(::Tuple), which sums over the elements of the tuple. 
function +(a::Tuple, b::Tuple)
    length(a) == length(b) || error("Tuples must be of same length in addition")
    tuple(map(sum, zip(a,b))...)
end
Base.zero(t::Tuple) = map(zero, t)

## this function calls pmap as an option for parallelism
function stats(d::Data, order::Int=2; kind=:diag)
    s = dmap(x->stats(x, order, kind=kind), d)
    reduce(+, s)     
end

function Base.sum(d::Data)
    s = zero(d.datatype)
    for x in d
        s += sum(x)
    end
    return s
end

function Base.sum(d::Data, dim::Int)
    if dim==1                           # the `fast' direction
        return stats(d,1)[2]
    else
        if length(d)>1
            s = zeros(d.datatype, size(d[1], 1))
            for x in d
                s += sum(x, dim)
            end
            return s
        else
            return nothing
        end
    end
end

function Base.mean(d::Data)
    n, sx = stats(d, 1)
    sx ./ n
end

function Base.var(d::Data)
    n, sx, sxx = stats(d, 2)
    μ = sx ./ n
    (sxx - n*μ.^2) ./ (n-1)
end

## this is potentially very slow because it reads all file just to find out the size
function Base.size(d::Data)
    s = dmap(size, d)
    nrow, ncol = s[1]
    ok = true
    for i in 2:length(s)
        ok &= s[i][2] == ncol
        nrow += s[i][1]
    end
    if !ok
        error("Inconsistent number of columns in data")
    end
    nrow, ncol
end

function Base.size(d::Data, dim::Int)
    if dim==2
        size(d[1],dim)
    else
        size(d)[dim]
    end
end
