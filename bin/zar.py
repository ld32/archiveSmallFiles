#!/bin/env python 

import os, sys
import zarr
import numpy as np
import argparse

def parse_arguments():
    """Set up command-line argument parsing."""
    parser = argparse.ArgumentParser(description="Convert files listed in a file to Zarr using ZipStore.")
    parser.add_argument('file_list', type=str, help='Path to the file containing a list of files and their types to be processed')
    parser.add_argument('directory_path', type=str, help='Base directory path for the files listed')
    parser.add_argument('zip_file_name', type=str, help='The .zarr.giz file name')
    return parser.parse_args()

def process(batch, directory_path, zip_file_name):
    """Process a batch of files and save them in a Zarr store."""
    
    store = zarr.ZipStore(zip_file_name, mode='w')
    root = zarr.group(store=store)

    for entry in batch:
        filename, file_type = entry.rsplit(' ', 1)
        file_path = os.path.join(directory_path, filename)
        
        try:
            if file_type == 'l':
                link_target = os.readlink(file_path)
                root.create_dataset(name=f"l:{filename}", data=np.array(list(link_target), dtype='|S1'), compressor=zarr.Blosc(cname="zstd", clevel=5))
                
            elif file_type == 'f':
                with open(file_path, 'rb') as file:
                    binary_data = file.read()
                root.create_dataset(name=f"f:{filename}", data=np.frombuffer(binary_data, dtype='u1'), compressor=zarr.Blosc(cname="zstd", clevel=5))
                
            else:
                print(f"Unknown type '{file_type}' for file '{filename}'")

        except Exception as e:
            print(f"Could not process {filename}: {str(e)}")
            if os.path.exists(zip_file_name):
                store.close()
                os.remove(zip_file_name)
                print(f"{zip_file_name} was removed.")
            else:
                print(f"{zip_file_name} does not exist.")
            
            sys.exit(1)

    store.close()
    print(f"Batch stored in {zip_file_name}")

def main():
    args = parse_arguments()
    
    file_list_path = args.file_list
    directory_path = args.directory_path
    zip_file_name = args.zip_file_name

    with open(file_list_path, 'r') as f:
        lines = [line.strip() for line in f.readlines()]

    process(lines, directory_path, zip_file_name)
if __name__ == '__main__':
    main()