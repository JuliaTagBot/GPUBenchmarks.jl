using GPUBenchmarks, BenchmarkTools, FileIO

benchmark_files = [
    # "blackscholes",
    # "PDE",
    "poincare",
    # "juliaset",
    # "mapreduce"
]

GPUBenchmarks.new_run()

for file in benchmark_files
    # @run_julia (JULIA_NUM_THREADS = 8, "-O3", file) begin
        for device in GPUBenchmarks.devices()
            using GPUBenchmarks, BenchmarkTools, FileIO
            bench_mod = include(GPUBenchmarks.dir("benchmark", file * ".jl"))
            println("Benchmarking $file $device")
            result = bench_mod.execute(device)
            println("Benchmarking done for $device")
            GPUBenchmarks.append_data!(result)
        end
    # end
end
