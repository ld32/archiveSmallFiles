#!/bin/env python 

import zarr
import sys

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <zarr_zip_file>")
    sys.exit(1)

zip_file_name = sys.argv[1]

store = zarr.ZipStore(zip_file_name, mode='r')
root = zarr.open_group(store)

for name in root.keys():
    #print(name)
    print(name[2:])

store.close()


