#!/usr/bin/env python3

import sys
import anndata as ad
import pandas as pd
import numpy as np
import scanpy as sc
import scipy
from pathlib import Path

# debug = False
# if debug:
#     library = 'S00001'
#     from types import SimpleNamespace
#     snakemake = SimpleNamespace()
#     snakemake.input = SimpleNamespace()
#     snakemake.output = SimpleNamespace()
#     snakemake.params = SimpleNamespace()
#     snakemake.input.in_h5 = f'DATA/CELLBENDER/{library}/output_filtered.h5'
#     snakemake.input.demux_summary = f'DATA/VIREO/{library}/vireo/summary.tsv'
#     snakemake.input.demux_assignment = f'DATA/VIREO/{library}/vireo/donor_ids.tsv'
#     snakemake.output.out_h5 = f'DATA/CELLBENDER/{library}/demux.h5'
#     snakemake.params.min_fraction = 0.05
#     snakemake.params.min_cells = 100
#     snakemake.params.max_doublet_LL = -10

#def main():
cellbender_h5 = Path(snakemake.input.in_h5)

# Note that donor_ids.tsv from Vireo is already the subset of high-quality cell barcodes determined
# earlier in the workflow, based on cellbender filtering, so that filtering is not necessary again!
# the only important doublet filtering is cells that could be multi-donor doublets based on Vireo.

adata = sc.read_10x_h5(cellbender_h5.as_posix())
adata.var_names_make_unique()

#adata.layers['counts'] = adata.X.copy()
#adata.raw = adata

# Add mitochondrial and ribosomal markers
#adata.var['mt'] = adata.var_names.str.startswith('MT-')
#adata.var['rb'] = adata.var_names.str.startswith(('RPL', 'RPS'))

# Calculate QC metrics
#sc.pp.calculate_qc_metrics(adata, qc_vars=['rb', 'mt'], percent_top=None, log1p=False, inplace=True)


# Normalize data as CPM
#sc.pp.normalize_total(adata)
#adata.layers['cpm']=adata.X.copy()

# Logarithmize the data
#sc.pp.log1p(adata)
#adata.layers['log-norm']=adata.X.copy() 


meta = pd.read_csv(snakemake.input.demux_assignment, sep='\t')


# exclude cells called as doublets
meta = meta[meta['donor_id'] != 'doublet']

# exclude cells with doublet log likelihood ratio above threshold
meta = meta[meta['doublet_logLikRatio'] < snakemake.params.max_doublet_LL]

# Calculate proportions
cell_proportions = meta['donor_id'].value_counts(normalize=True)
cell_proportions = cell_proportions[cell_proportions > snakemake.params.min_fraction]


cell_counts = meta['donor_id'].value_counts(normalize=False)
cell_counts = cell_counts[cell_counts > snakemake.params.min_cells]

# Take intersection of donors passing proportion and count min
donors_kept = list(set(np.intersect1d(cell_counts.index, cell_proportions.index)))

# Only retain cells in the QC-passed donor list
meta = meta[meta['donor_id'].isin(donors_kept)]

meta = meta.set_index('cell')
meta = meta.drop(columns=['prob_max','prob_doublet','n_vars','best_singlet','best_doublet','doublet_logLikRatio'])
# Left-join onto adata.obs (preserves adata's cell order and count)

adata = adata[adata.obs_names.isin(meta.index)].copy()
adata.obs = adata.obs.join(meta, how="left")
adata.obs['library'] = snakemake.wildcards.library


adata.obs['cellbc'] = adata.obs.index + '_' + adata.obs['donor_id']
adata.obs = adata.obs.set_index('cellbc')

adata.write_h5ad(snakemake.output.out_h5)