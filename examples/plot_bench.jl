if Pkg.installed("BenchmarkTools") == nothing ||
   Pkg.installed("Query") == nothing ||
  # Pkg.installed("CUDAnative") == nothing ||
   Pkg.installed("DataFrames") == nothing

   error("Please install BenchmarkTools, Query, CUDAnative and DataFrames")
   # Pkg.add("Query")
   # Pkg.add("DataFrames")
end

using DataFrames, Query, Plots
pyplot()

cd(dirname(@__FILE__))
name = "blackscholes"
results = readtable("$(name)_results.csv")
results = @from i in results begin
    @orderby descending(i.minT)
    @select i
    @collect DataFrame
end
labels = String[]
times = Vector{Float64}[]
for backend in unique(results[:Backend])
    push!(labels, string(backend))
    time = @from r in results begin
      @where r.Backend == backend
      @select get(r.minT)
      @collect
   end
   push!(times, time ./ 10^9)
end

p2 = plot(
    [10^i for i = 7:-1:1],
    times,
    m = (5, 0.8, :circle, stroke(0)),
    line = 1.5,
    labels = reshape(labels, (1, length(labels))),
    title = name,
    legend = :topleft,
    xaxis = ("N", :log10),
    yaxis = ("Time in s", :log10)
)

savefig("$name.svg")

function filterResults(df, n)
   dfR = @from r in df begin
      @where r.N == 10^n
      @select {r.Backend, r.minT}
      @collect DataFrame
   end
   return dfR
end

io = IOBuffer()
for n in 7:7
    df = filterResults(results, n)
    baseline = get(df[1, 2])
    println(io, "| Backend | Time (s) for N = 10^$n | OP/s in million | Speedup |")
    println(io, "| ---- | ---- | ---- | ---- |")
    for row in eachrow(df)
        b = (row[:Backend])
        t = get(row[:minT])
        @printf(io, "| %s | %6.4f s| %4d | %4.1f|\n",
            b, t / 10^9,
            (10^n / (t / 10^9)) / 10^6,
            baseline / t
        )
    end
    display(Markdown.parse(io))
    seekstart(io)
    println(String(take!(io)))
end
