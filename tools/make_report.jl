using GPUBenchmarks, Plots, Colors, BenchmarkTools

#########################
# Parameters

# lol we can't just use 0.0, because Plots.jl errors then
missing_val = 0.0 + eps(Float64)
text2pix = 0.95
ywidth = 3.0
window_size = (800, 500)
nice_colors = map([
    (0, 116, 217), # Blue
    (127, 219, 255), # Aqua
    (133,  20,  75), # Maroon
    (240,  18, 190), # Fuchsia
    (46, 204,  64), # Green
    (177,  13, 201), # Purple
    (57, 204, 204), # Teal
    (61, 153, 112), # Olive
    (255, 220,   0), # Yellow
    (255,  65,  54), # Red
    (1, 255, 112), # Lime
    (255, 133,  27), # Orange
    (0,  31,  63), # Navy
    (221, 221, 221), # Silver
    (17,  17,  17), # Black
    (170, 170, 170), # Gray
]) do x
    RGB(map(v-> v / 255, x)...)
end

#######################
# helpers

function get_time(x::BenchmarkTools.Trial)
    time = minimum(x).time
    isinf(time) ? missing_val : time / 10^9
end

function judged_push!(benchset, benchmark, name)
    get_time(benchmark) == missing_val && return
    for benches in benchset
        judgment = judge(minimum(first(benches)[2]), minimum(benchmark))
        if judgment.time == :invariant
            push!(benches, (name, benchmark))
            return
        end
    end
    # we have a new unique benchresult and can open a new group
    push!(benchset, [(name, benchmark)])
    return
end

get_trial(x::BenchmarkTools.Trial) = x
function get_trial(x)
    BenchmarkTools.Trial(
        BenchmarkTools.Parameters(),
        fill(Inf, 1000),
        fill(Inf, 1000),
        typemax(Int),
        typemax(Int)
    )
end

grouptime(x) = minimum(last(first(x))).time
function speedup!(benchset)
    sort!(benchset, by = grouptime)
    slowest = grouptime(benchset[end])
    map(x-> slowest / grouptime(x), benchset)
end

rect(w, h, x, y) = Shape(x + [0,w,w,0], y + [0,0,h,h])
function plot_speedup!(p, position, number, color)
    label = @sprintf("%4.2fx", number)
    annotation = text(label, 11, :white, :right)
    ps = annotation.font.pointsize
    w = (length(label) * ps) / text2pix
    w *= 1.2
    shape = rect(-w, ps * ywidth, (position)...)
    plot!(p, shape, linewidth = 0, color = color, markerstrokewidth = 0)
    annotate!(p, [((position .+ (-4, 15text2pix))..., annotation)])
    position .- (w + (5 * text2pix), 0)
end

function plot_label!(p, position, label, color)
    label_str = if label == :julia
        "jl 4core 8threads" # be more descriptive
    else
        replace(string(label), "_", " ")
    end
    labeltext = text(label_str, 11, :black, :right)
    ps = labeltext.font.pointsize
    w = (length(label_str) * ps) / text2pix
    shape = rect(10, ps * ywidth, (position .- (12, 0))...)
    plot!(p, shape, linewidth = 0, color = color)

    shape = rect(-w, ps * ywidth, (position .- (17, 0))...)
    plot!(
        p, shape, linewidth = 1,
        linecolor = RGBA(0.6, 0.6, 0.6, 0.9), color = RGBA(1, 1, 1, 0)
    )
    annotate!(p, [((position .+ (-23, 15text2pix))..., labeltext)])
    position .- (w + (25text2pix), 0)
end

function plot_benchset(p, position, wstart, benchset, label_colors, speed_cmap)
    speedups = speedup!(benchset)
    iterator = (zip(reverse(speedups), speed_cmap, reverse(benchset)))
    for (speedup, scolor, benches) in iterator
        position = plot_speedup!(p, position, speedup, scolor)
        for (name, bench) in benches
            position = plot_label!(p, position, name, label_colors[name])
        end
        position = (wstart, position[2] + 11 * ywidth + 5)
    end
    position
end

function plot_legend(title, benchset, label_colors, size)
    pad = 5
    width, height = size .* 0.5

    wstart = width - pad
    position = (wstart, 0)
    p = plot(
        title = title,
        xlims = (0, width), ylims = (0, height),
        legend = false,
        grid = false,
        axis = false,
        aspect_ratio = 1,
        markerstrokewidth = 0,
    )
    speed_cmap = linspace(colorant"#E53A15", colorant"#AAE500", length(benchset))
    plot_benchset(p, position, wstart, benchset, label_colors, speed_cmap)
    p
end
function github_url(isimage, name...)
    str = joinpath(
        "https://github.com/JuliaGPU/GPUBenchmarks.jl/blob/master/",
        name...,
        isimage ? "?raw=true" : ""
    )
    # there is a better way to do this in HTTParser or so... keep forgetting where and how
    replace(str, " ", "%20")
end

##########################################
# plotting code

gr(size = window_size)


md_io = open(GPUBenchmarks.dir("results", string("results.md")), "w")

println(md_io, """
# GPU Benchmarks

This is the first iteration of Julia's GPU benchmark suite.
Please treat all numbers with care and open issues if numbers seem off.
If you have suggestions or improvements, please go ahead and open a PR with this repository.

Packages benchmarked:

[CuArrays](https://github.com/FluxML/CuArrays.jl) appears as: **cuarrays**

[ArrayFire](https://github.com/gaika/ArrayFire.jl) appears as: **arrayfire cl**, **arrayfire cu**

[GPUArrays](https://github.com/JuliaGPU/GPUArrays.jl) appears as: **opencl**, **cudanative** and **julia** for a multi threaded backend

Julia Base Arrays appear as: **julia base**

Hardware used for GPU: **GTX 950**

Hardware used for Julia single and multithreaded backends: **Intel® Core™ i7-6700 CPU @ 3.40GHz × 4**

Julia's Array implementation is used as a baseline for performance and precision.
So the baseline is in most cases the maximum single threaded performance with SIMD acceleration.
The mean difference in the precision compared to the Julia baseline is plotted as points, with the size of difference corelating with point size.

---

""")

# most_current = filter(x-> x.timestamp == GPUBenchmarks.last_time_stamp(), GPUBenchmarks.get_database())
most_current = GPUBenchmarks.get_database()
using GPUBenchmarks: codepath, name
codepaths = unique(codepath.(most_current))
for code_path in codepaths
    suites = unique(name.(filter(x-> codepath(x) == code_path, most_current)))
    mod = include(code_path)
    jl_name = basename(code_path)
    file_name, ext = splitext(jl_name)
    println(md_io, "### ", titlecase(file_name))
    println(md_io, mod.description)
    for suitename in suites
        suite = filter(x-> name(x) == suitename, most_current)
        println(md_io, "#### ", titlecase(suitename))
        i = 1
        legend_colors = Dict()
        main_plot = plot(
            xaxis = ("Problem size N", :log10), yaxis = ("Time in Seconds", :log10),
            legend = false,
            markerstrokewidth = 0,
        );
        devices = unique(map(x-> x.device, suite))
        benchset_firstn = []
        benchset_lastn = []
        for device in devices
            device_benches = sort(filter(x-> x.device == device, suite), by = (x)-> x.N)
            times, Ns = map(x-> x.benchmark, device_benches), map(x-> x.N, device_benches)
            meandiff = map(x-> x.meandiffrence, device_benches) .* 3000.0
            judged_push!(benchset_firstn, first(times), device)
            judged_push!(benchset_lastn, last(times), device)
            times = get_time.(times)
            color = nice_colors[i]
            legend_colors[device] = color
            error_cmap = linspace(colorant"#E53A15", colorant"#AAE500", length(Ns))
            plot!(main_plot, Ns, times, m = (error_cmap, 0.4, stroke(2, color)), ms = meandiff)
            plot!(main_plot, Ns, times, line = (2, color))
            i += 1
        end
        pfirstn = plot_legend("N = 10^1", benchset_firstn, legend_colors, window_size)
        plastn = plot_legend("N = 10^7", benchset_lastn, legend_colors, window_size)

        layout = @layout [
            a{0.5h}
            a{0.5w} a{0.5w}
        ]
        plot(main_plot, pfirstn, plastn, layout = layout)
        plotbase = GPUBenchmarks.dir("results", "plots")
        isdir(plotbase) || mkdir(plotbase)
        pngpath = joinpath(plotbase, suitename * ".png")
        savefig(pngpath)
        println(pngpath)
        img_url = github_url(true, split(pngpath, Base.Filesystem.path_separator)[end-2:end]...)

        code_url = github_url(false, "benchmark", jl_name)
        println(md_io, "[![$suitename]($img_url)]($code_url)")
        println(md_io)
        println(md_io, "[code]($code_url)")
        println(md_io)
        println(md_io, "___")
        println(md_io)
    end
end
close(md_io)
