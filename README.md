# assets-immunebuilder-weights

ImmuneBuilder model weights, distributed as Platforma assets. Consumed by `3d-structure-prediction` block.

ImmuneBuilder normally downloads its trained weights from Zenodo on first predictor construction. That network fetch is the unstable runtime dependency this repo removes: the weights are published once as Platforma assets, mounted into the exec workdir, and ImmuneBuilder is pointed at them via `weights_dir=` so no runtime download happens.

## Variants

| Variant          | Predictor          | Source (Zenodo record 7258553)             | Size    |
| ---------------- | ------------------ | ------------------------------------------ | ------- |
| `abodybuilder2`  | `ABodyBuilder2`    | `antibody_model_1..4`                      | ~703 MB |
| `nanobodybuilder2` | `NanoBodyBuilder2` | `nanobody_model_1..4`                      | ~703 MB |

A prediction run uses exactly one mode, so the weights are split per-mode: the consuming workflow imports only the asset matching the selected mode (~703 MB) rather than both (~1.4 GB). The unused `tcr*` / `tcr2*` checkpoints from the same Zenodo record are not packaged.

## Building locally

```bash
pnpm install
pnpm build       # downloads weights from Zenodo, then builds each asset tarball
```

The build step shells out to `scripts/download-weights.sh`, which `curl`s the weight files listed in each variant's `modelInfo.json` into `indexed_model/{variant}/`. The Zenodo record is an immutable DOI version, so the URLs are reproducible; the only network dependency is at build time (and CI retries), not at block runtime.

## License

ImmuneBuilder and its weights are distributed by the Oxford Protein Informatics Group under the BSD 3-Clause license (`Copyright (c) 2022, Brennan Abanades Kenyon`). Redistribution is permitted with the copyright notice and license text. Each variant directory carries the BSD-3 text in a tracked `LICENSE` file; the build step copies it into `indexed_model/{variant}/LICENSE` so the license ships **inside the published asset, next to the weights**.