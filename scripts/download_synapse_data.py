#!/usr/bin/env python3
# coding: utf-8

import sys
import time
sys.tracebacklimit = 0
from pathlib import Path
import os
import pandas as pd


#===================================================================================================
# 01 Load config
#===================================================================================================

project_dir = Path('.').resolve().as_posix()
synapse_metadata_file = Path(snakemake.input.metadata_file).resolve().as_posix()
data_dir = Path(snakemake.input.metadata_file).resolve().parent


import synapseclient
import asyncio
import hashlib

from synapseclient.models import (
    File, Folder, Project, Table, EntityView, Dataset,
    DatasetCollection, MaterializedView, SubmissionView, VirtualTable
)


def require_path(path, label, kind, create=False):
    """kind must be 'file' or 'dir'."""
    if kind not in ("file", "dir"):
        raise ValueError("kind must be 'file' or 'dir'")
    path = Path(path).resolve()
    if path.exists():
        # exists — verify it's the right type
        if kind == "file" and not path.is_file():
            raise FileNotFoundError(f"{label} {path} exists but is not a file")
        if kind == "dir" and not path.is_dir():
            raise NotADirectoryError(f"{label} {path} exists but is not a directory")
        return path.absolute()
    # doesn't exist
    if not create:
        raise FileNotFoundError(f"required {label} {kind} {path} does not exist")
    elif create:
        try:
            if kind == "file":
                path.parent.mkdir(parents=True, exist_ok=True)  # ensure parent dir
                path.touch()
            elif kind == 'dir':
                path.mkdir(parents=True, exist_ok=True)
            return path.absolute()
        except OSError as e:
            raise OSError(f"ERROR: could not create {label} {kind} {path}") from e


def get_md5(path:PosixPath):
    path = str(path.resolve().absolute())
    hash_md5 = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


async def main():
    # Authenticate to synapse
    if snakemake.params.tokenfile.startswith('~'):
        token_file = require_path(Path(snakemake.params.tokenfile).expanduser(), label='synapse auth token', kind='file', create=False)
    else:
        token_file = require_path(snakemake.params.tokenfile, label='synapse auth token', kind='file', create=False)
    with open(token_file, 'r') as f:
        token = f.read().strip()

    syn = synapseclient.login(authToken=token)


    # Import reads metadata file
    metadata_filename = data_dir / synapse_metadata_file
    df = pd.read_csv(metadata_filename, sep='\t')

    if snakemake.params.clobber in ['True', 'true', 'T', 't', 'Yes', 'yes', 'Y', 'y']:
        print(f"WARNING: synapse.clobber is set to True. Files will be removed and overwritten! Waiting 10 seconds before continuing")
        time.sleep(10)
                  
    bad_files = []
    good_files = []
    #retries = []        # Tuple (synid, filepath, version, meta_md5)

    # FIRST check of files
    # iterate over rows of metadata:
    for i in range(df.shape[0]):
        x = df.iloc[i]
        filepath = data_dir / x['file_name']
        sanitized_filepath = data_dir / x['sanitized_name']
        md5_filepath = Path(str(sanitized_filepath) + '.md5')
        synid = x['synid']
        version = int(x['version_label'])
        meta_md5 = x['content_md5']
        
        # Delete files clobber=True and files exist
        if snakemake.params.clobber in ['True', 'true', 'T', 't', 'Yes', 'yes', 'Y', 'y']:
            for file in [filepath, sanitized_filepath, md5_filepath]:
                if file.exists():
                    file.unlink()
        
        # Start fresh download file if it does not exist in sanitized format
        if not sanitized_filepath.exists():
            if filepath.exists():
                filepath.unlink()
            if md5_filepath.exists():
                md5_filepath.unlink()
            await syn.get_async(synid, download_file=True,
                            downloadLocation=filepath.parent,
                            if_collision="overwrite.local",
                            synapse_client=syn)
            # Rename to sanitized name
            filepath.rename(sanitized_filepath)
        
        # Calculate md5 if it does not exist
        if not md5_filepath.exists():
            file_md5 = get_md5(sanitized_filepath)
        else:
            with open(md5_filepath, 'r') as infile:
                file_md5 = infile.read().strip()
        
        # Compare md5
        if file_md5 != meta_md5:
            print(f"{synid} Local file md5 ({file_md5}) does not match metadata md5 ({meta_md5}) for file {sanitized_filepath} version {version}!")
            print(f"Removing file {sanitized_filepath}")
            os.remove(sanitized_filepath)
            os.remove(md5_filepath)
            bad_files.append((synid, sanitized_filepath, version, meta_md5))
        
        # Only written if file md5 matches metadata md5
        elif file_md5 == meta_md5:
            good_files.append((synid, sanitized_filepath, version, meta_md5))
            with open(md5_filepath, 'w') as outfile:
                outfile.write(file_md5 + '\n')
    print(f"Total files in {metadata_filename}: {df.shape[0]}")
    print(f"Good files: {len(good_files)}")
    print(f"Bad files: {len(bad_files)}")

    
    # Test if every file in metadata passed md5 check
    if df.shape[0] != len(good_files):
        raise RuntimeError(f"Not all files pass md5 check. {len(bad_files)} bad files:\n{'\n'.join(bad_files)}")
    else:
        Path(snakemake.output.touchfile).touch()

if __name__ == "__main__":
    asyncio.run(main())
    print("Completed successfully")
    sys.exit(0)