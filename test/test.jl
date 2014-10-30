## test the functionality of BigData
using HDF5, JLD

Base.isapprox(a::Array, b::Array) = all([isapprox(x, y) for (x,y) in zip(a,b)])

xa = [randn(10000+rand(1:100), 10) for i=1:10]
d1 = Data(xa)
m1 = mean(d1)
c1 = cov(d1)

x = collect(d1)
@assert isapprox(mean(x), m1)
@assert isapprox(mean(x,1), mean(d1,1))
@assert isapprox(cov(x), c1)

isdir("tmp") || mkdir("tmp")

files = String[]
for (i, xx) in enumerate(d1)
    file = "tmp/$i.jld"
    push!(files, file)
    save(file, xx)
end

d2 = Data(files, Float64)
@assert size(d2) == size(d1) == size(x)
m2 = mean(d2)
c2 = cov(d2)
@assert isapprox(m1, m2)
@assert isapprox(mean(x,1), mean(d2,1))
@assert isapprox(c2, c1)

@assert isapprox(collect(d2), x)
