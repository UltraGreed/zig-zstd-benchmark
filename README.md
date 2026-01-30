WIP Zig std Zstandard benchmark

# Setup
1. Clone with submodules:

```sh
git clone --recurse-submodules https://github.com/UltraGreed/zig-zstd-benchmark
```

or clone as usual and pull submodules:

```sh
git clone https://github.com/UltraGreed/zig-zstd-benchmark
cd zig-zstd-benchmark
git submodule init
git submodule update
```

2. Build zstd library:
```sh
cd zstd
make
cd -
```

3. (Optional) Setup python environment for utils:

```py
python -m venv .venv
source .venv/bin/activate
pip install tqdm bokeh
```

# Usage
1. (Optional) Compress files with python script:

```sh
utils/zstd_compress_dir.py PATH_RAW_DIR PATH_COMP_DIR
```
This will compress all the files in `PATH_RAW_DIR` with all compression levels from -7 to 19, and save them
as `PATH_COMP_DIR/LEVEL/*.zst`.

2. Set path constants in the main of `src/zstd_bench.zig`. The compressed data path should contain 
subdirectories named after the respective compression levels, e.g. `PATH_COMP_DIR/7/silesia.zst`.
3. Build and run:

```zig
zig build -Doptimize=ReleaseFast run
```

Benchmarking results will be saved in `out/runs.csv` file.

4. (Optional) Plot results with python script:
```sh
utils/plot_results.py
```

Generated plot will be saved as `utils/plot_results.html` and automatically opened in default browser.

# Datasets used
1. [Silesia corpus](https://sun.aei.polsl.pl/~sdeor/index.php?page=silesia)
2. [enwik9 (1GB of English Wikipedia data)](https://mattmahoney.net/dc/textdata.html)
3. [Linux kernel v6.19-rc7 sources](https://github.com/torvalds/linux/releases/tag/v6.19-rc7)

# Results
NOTE: This work is currently WIP and the produced results may not be 100% correct

Benchmarking is done on Gentoo/Linux x86_64 machine with AMD Ryzen 5 5600X CPU, Zig v0.15.2, Zstd v1.5.7.

<img width="900" height="600" alt="silesia" src="https://github.com/user-attachments/assets/9e0511f9-81a4-4d98-b927-f539762653f8" />
<img width="900" height="600" alt="enwik9" src="https://github.com/user-attachments/assets/4f1984da-22df-493d-a84c-e7232d274473" />
<img width="900" height="600" alt="linux" src="https://github.com/user-attachments/assets/b559a43e-13bd-4bbc-afde-de4202c216fe" />

