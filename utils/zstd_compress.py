#!/usr/bin/env python
import sys
from pathlib import Path
from itertools import chain
from compression import zstd
from compression.zstd import CompressionParameter

from tqdm import tqdm


LEVELS = list(chain(range(-7, 0), range(1, 19 + 1)))
THREADS = 13

def compress_file(path_in, path_out, level, threads):
    options = {CompressionParameter.nb_workers: threads,
               CompressionParameter.compression_level: level}

    original = Path(path_in).read_bytes()

    compressed = zstd.compress(original, options=options)

    Path(path_out).write_bytes(compressed)


def main(file_in, dir_out):
    print(f'Compressing {file_in} to {dir_out}')
    for level in (pbar := tqdm(LEVELS)):
        pbar.set_description(f'level {level}')
        level_path = Path(dir_out) / str(level)
        level_path.mkdir(exist_ok=True)

        orig_path = Path(file_in)
        compress_path = f'{level_path / orig_path.name}.zst'
        compress_file(orig_path, compress_path, level, THREADS)
    print('Compression done!')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: zstd_compress_dir.py PATH_IN_FILE PATH_OUT_DIR")
        exit(2)
    main(*sys.argv[1:])
