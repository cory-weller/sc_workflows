# README

**IMPORTANT**

This repository is intended to reference the `sc_workflows` directory. This means you should not need to modify anything within `sc_workflows`!

Instead, `git clone` or `git submodule add` this within your parent project directory. The end directory structure will look like the following:

```
my-new-project/
├── DATA/
├── scripts/
└── sc_workflows/
    ├── envs/
    ├── orchestrator_templates/
    ├── README.md
    ├── scripts/
    ├── setup.sh
    └── Snakefile
```

Then you should run `bash sc_workflows/setup.sh` to copy templates into your project.

```
my-new-project/
├── config.yaml
├── DATA/
├── run.sh
├── scripts/
├── sc_workflows/
|   ├── envs/
|   ├── orchestrator_templates/
|   ├── README.md
|   ├── scripts/
|   ├── setup.sh
|   └── Snakefile
├── slurm_profile/
|   └── config.yaml
└── Snakefile
```

notably:
- `config.yaml` contains broad snakemake settings
- `slurm_profile/config.yaml` contains settings specific to the SLURM job handler
- `run.sh` executes Snakefile
- `Snakefile` contains the project-level snakemake orchestrator
