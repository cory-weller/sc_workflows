#!/usr/bin/env python3

import sys
import os
import anndata as ad
import pandas as pd
import scanpy as sc
import scipy
from pathlib import Path
import numba

n = min(snakemake.threads, numba.config.NUMBA_NUM_THREADS, len(os.sched_getaffinity(0)))
sc.settings.n_jobs = n
numba.set_num_threads(n)
print(f"threads={snakemake.threads} numba={numba.config.NUMBA_NUM_THREADS} "
      f"affinity={len(os.sched_getaffinity(0))} using={n}", flush=True)

def main():
    cbh5 = Path(snakemake.input.cellbenderh5)
    
    adata = sc.read_10x_h5(cbh5.as_posix())
    adata.var_names_make_unique()
    
    
    adata.layers['counts'] = adata.X.copy()
    adata.raw = adata
    
    # Add mitochondrial and ribosomal markers
    adata.var['mt'] = adata.var_names.str.startswith('MT-')
    adata.var['rb'] = adata.var_names.str.startswith(('RPL', 'RPS'))
    
    # Calculate QC metrics
    sc.pp.calculate_qc_metrics(adata, qc_vars=['rb', 'mt'], percent_top=None, log1p=False, inplace=True)
    
    
    # Normalize data as CPM
    sc.pp.normalize_total(adata)
    adata.layers['cpm']=adata.X.copy()
    
    # Logarithmize the data
    sc.pp.log1p(adata)
    adata.layers['log-norm']=adata.X.copy() 
    
    
    # Threshold below a given mitochondria percent
    adata = adata[adata.obs['pct_counts_mt'] < snakemake.params.mito_max].copy()
    
    # Threshold above a given genes per cell threshold
    adata = adata[adata.obs['n_genes_by_counts'] > snakemake.params.genes_min].copy()
    
    # Threshold below a given ribosome threshold
    adata = adata[adata.obs['pct_counts_rb'] < snakemake.params.ribo_max].copy()
    
    # Recompute doublet score based on filtered data
    if snakemake.params.doublet_max is None or snakemake.params.doublet_max in ['None','none','NA','na']:
        sc.pp.scrublet(adata, expected_doublet_rate=(adata.n_obs / 1000) * 0.008, n_prin_comps=10)
    else:
        sc.pp.scrublet(adata, expected_doublet_rate=(adata.n_obs / 1000) * 0.008, threshold=snakemake.params.doublet_max, n_prin_comps=10)
    
    good_barcodes = list(adata.obs.index)
    
    with open(snakemake.output.good_bcs, 'w') as outfile:
        outfile.write('\n'.join(good_barcodes)+'\n')
    
    try:
        if snakemake.params.write_h5:
            adata.obs['library'] = snakemake.wildcards.library
            adata.obs['cellbc'] = adata.obs.index + '_' + adata.obs['library']
            adata.obs = adata.obs.set_index('cellbc')
            adata.write_h5ad(snakemake.output.out_h5)
    except NameError:
        pass


print('starting main block', flush=True)
main()
print('done', flush=True)
sys.exit(0)