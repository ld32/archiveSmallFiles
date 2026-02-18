#!/bin/env python 

import zarr
import argparse
import zipfile
import os

def extract_zarr_zip(zip_file):
    if not zipfile.is_zipfile(zip_file):
        print(f"{zip_file} is not a valid zip file.")
        return
    
    store = zarr.ZipStore(zip_file, mode='r')
    root = zarr.open(store, mode='r')
    directory_path = os.path.dirname(zip_file)

    for key in root.array_keys():
        prefix, filename = key.split(':', 1)
        if prefix == 'l':
            link_target = ''.join(root[key][:].astype(str))
            try:
                os.symlink(link_target, os.path.join(directory_path, filename))
                print(f"Restored symbolic link from '{filename}' to '{link_target}'")
            except OSError as e:
                print(f"Failed to create symbolic link for '{filename}': {e}")

        elif prefix == 'f': 
            data = root[key][:]
            with open(os.path.join(directory_path, filename), 'wb') as f:
                f.write(data.tobytes())
            print(f"Restored file '{filename}'")

        else:
            print(f"Unknown type prefix '{prefix}' for key '{key}'")

    store.close()

def main():
    parser = argparse.ArgumentParser(description='Process a Zarr ZipStore file.')
    parser.add_argument('zip_file', type=str, help='Path to the Zarr zip file')

    args = parser.parse_args()

    extract_zarr_zip(args.zip_file)

if __name__ == '__main__':
    main()
