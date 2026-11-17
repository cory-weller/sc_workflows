#!/usr/bin/env python3
# coding: utf-8

import synapseclient
import asyncio
from pathlib import Path
import os
import sys
sys.tracebacklimit = 0

# try:
#     from sysbio_sc import *
# except ModuleNotFoundError:
#     try:
#         sys.path.append('src')
#         from sysbio_sc import *
#     except:
#         raise


project_dir = Path('.').resolve().as_posix()
data_dir = Path(snakemake.output.metadata_file).resolve().parent.as_posix()
synapse_metadata_file = Path(snakemake.output.metadata_file).resolve().as_posix()



from synapseclient.models import (
    File, Folder, Project, Table, EntityView, Dataset,
    DatasetCollection, MaterializedView, SubmissionView, VirtualTable
)


def write_mdata(mdata, fn):
    header = [x[0] for x in mdata[0]]
    values = []
    for x in mdata:
        values.append([i[1] for i in x])
    os.makedirs(Path(fn).parent, exist_ok=True)
    with open(fn, 'w') as outfile:
        outfile.write('\t'.join(header) + '\n')     # Write first half of tuple as header
        for v in values:
            outfile.write('\t'.join(v) + '\n')     # Write second half of tuple as values

def format_property(p):
    o = {}
    for key,value in p.items():
        if not isinstance(value, list):
            o[key] = str(value)
        if isinstance(value, list):
            o[key] = ';'.join([str(x) for x in value])
    return(o)

def update_files(synfolder, filetree='.'):
    # Update each file in the current node
    for synfile in synfolder.files:
        synfile.file_name = f"{filetree}/{synfile.file_handle.file_name}"
    # Recurse into nested folders
    for folder in synfolder.folders:
        update_files(folder, f"{filetree}/{folder.id}")

# def get_files(synfolder):
#     for synfile in synfolder.files:
#         yield synfile
#     for folder in synfolder.folders:
#         yield from get_files(folder)

def get_items(_dict, _keys):
    items = []
    for key in _keys:
        if key in _dict:
            items.append((key, _dict[key]))
        else:
            items.append((key, 'N/A'))
    return(items)

def extract_mdata(SYNFILE):
    file_handle_order = ['id',
                    'etag',
                    'created_by',
                    'created_on',
                    'modified_on',
                    'concrete_type',
                    'content_type',
                    'content_md5',
                    'storage_location_id',
                    'content_size',
                    'status',
                    'bucket_name',
                    'key',
                    'preview_id',
                    'is_preview',
                    'external_url']
    annotations_order = ['sex',
                        'assay',
                        'grant',
                        'organ',
                        'study',
                        'tissue',
                        'runType',
                        'species',
                        'cellType',
                        'dataType',
                        'platform',
                        'consortium',
                        'fileFormat',
                        'readLength',
                        'specimenID',
                        'dataSubtype',
                        'libraryPrep',
                        'individualID',
                        'resourceType',
                        'isModelSystem',
                        'isMultiSpecimen',
                        'nucleicAcidSource',
                        'individualIdSource']
    metadata = []
    synid = SYNFILE.id
    metadata =  [('synid',synid)]
    sanitized_filename = SYNFILE.file_name
    sanitized_filename = sanitized_filename.replace(' ','_')
    sanitized_filename = sanitized_filename.replace('(','')
    sanitized_filename = sanitized_filename.replace(')','')
    metadata += [('file_name', SYNFILE.file_name)]
    metadata += [('sanitized_name', sanitized_filename)]
    metadata += [('version_label', SYNFILE.version_label)]
    metadata += get_items(format_property(SYNFILE.file_handle.__dict__), file_handle_order)
    metadata += get_items(format_property(SYNFILE.annotations), annotations_order)
    return(metadata)


async def get_files(synid, syn):
    empty_entity = await syn.get_async(synid, download_file=False)
    if empty_entity.concreteType == 'org.sagebionetworks.repo.model.FileEntity':  # is File
        entity = await File(id=synid, download_file=False).get_async()    # Single file object with metadata
        entity.file_name = entity.id + '/' + entity.file_handle.file_name
        return([entity])
    elif empty_entity.concreteType == 'org.sagebionetworks.repo.model.Folder':     # is Folder
        entity = Folder(id=synid)
        entity = await entity.sync_from_synapse_async(download_file=False)       # Folder with list of file objects
        update_files(entity, entity.id)
        return(flatten_files(entity))

def flatten_files(node):
    files = []
    if node.files is not None:
        files += (node.files)
    for folder in node.folders:
        files += flatten_files(folder)
    return files

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

async def main():

    # Check if final output exists:
    metadata_output = Path(synapse_metadata_file)
    if metadata_output.exists():
        if snakemake.params.clobber in ['True', 'true', 'T', 't', 'Yes', 'yes', 'Y', 'y']:
            print(f"Final output {metadata_output} exists, but re-running anyway because synapse.clobber=True")
        else:
            print(f"Final output {metadata_output} exists, stopping because synapse.clobber=False")
            return


    # Authenticate to synapse
    if snakemake.params.tokenfile.startswith('~'):
        token_file = require_path(Path(snakemake.params.tokenfile).expanduser(), label='synapse auth token', kind='file', create=False)
    else:
        token_file = require_path(snakemake.params.tokenfile, label='synapse auth token', kind='file', create=False)
    with open(token_file, 'r') as f:
        token = f.read().strip()

    syn = synapseclient.login(authToken=token)


    # Recursively syncfolder data

    datasets = snakemake.params.datasets
    # Ensure it is a list, even if length of 1
    if isinstance(datasets, str):
        datasets_ids = [datasets]
    else:
        datasets_ids = datasets

    print(f"Retrieving metadata for datasets: {' '.join(datasets_ids)}")

    combined_metadata = []
    for synapse_id in datasets_ids:
        mdata = await get_files(synapse_id, syn)
        combined_metadata += [extract_mdata(x) for x in mdata]

    # TODO: Sanitize filenaames
    # Replace space with underscore
    # Remove parentheses
    

    # Write to final metadata file for sequencing reads to output
    write_mdata(combined_metadata, metadata_output)




if __name__ == "__main__":
    asyncio.run(main())
    print("Completed successfully")
    sys.exit(0)