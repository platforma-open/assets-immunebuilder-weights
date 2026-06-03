#!/usr/bin/env bash
#
# Download ImmuneBuilder model weights into the variant's indexed_model/ directory.
#
# Usage:
#   download-weights.sh <modelInfo.json>
#
# modelInfo.json schema:
#   {
#     "base_url": "https://zenodo.org/record/7258553/files",
#     "target_dir": "abodybuilder2",
#     "files": ["antibody_model_1", "antibody_model_2", ...],
#     "url_suffix": "?download=1"   // optional; default "?download=1"
#   }
#
# Each file is fetched from "<base_url>/<file><url_suffix>". The URLs mirror
# ImmuneBuilder's own `model_urls` (see ImmuneBuilder/ABodyBuilder2.py and
# NanoBodyBuilder2.py). The Zenodo record is an immutable DOI version, so the
# files are byte-reproducible; the only network dependency is at build time.
#
# The asset's package.json must declare `block-software.entrypoints.main.asset.root`
# pointing at `./indexed_model/<target_dir>` — pl-pkg picks up the downloaded
# files from there.

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <modelInfo.json>" >&2
    exit 1
fi

MODEL_INFO="$1"

if [ ! -f "$MODEL_INFO" ]; then
    echo "Error: $MODEL_INFO not found" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required (install via 'brew install jq' or 'apt-get install jq')" >&2
    exit 1
fi

BASE_URL=$(jq -r '.base_url' "$MODEL_INFO")
TARGET_DIR=$(jq -r '.target_dir' "$MODEL_INFO")
URL_SUFFIX=$(jq -r '.url_suffix // "?download=1"' "$MODEL_INFO")

if [ -z "$BASE_URL" ] || [ "$BASE_URL" = "null" ]; then
    echo "Error: base_url missing from $MODEL_INFO" >&2
    exit 1
fi
if [ -z "$TARGET_DIR" ] || [ "$TARGET_DIR" = "null" ]; then
    echo "Error: target_dir missing from $MODEL_INFO" >&2
    exit 1
fi

OUTPUT_DIR="indexed_model/$TARGET_DIR"
mkdir -p "$OUTPUT_DIR"

mapfile -t FILES < <(jq -r '.files[]' "$MODEL_INFO")
if [ "${#FILES[@]}" -eq 0 ]; then
    echo "Error: no files listed in $MODEL_INFO" >&2
    exit 1
fi

for file in "${FILES[@]}"; do
    url="${BASE_URL}/${file}${URL_SUFFIX}"
    out="$OUTPUT_DIR/$file"

    # Skip if already present and non-empty (lets repeated local builds reuse
    # downloads; CI starts from a clean tree so always fetches).
    if [ -s "$out" ]; then
        echo "Already present, skipping: $out"
        continue
    fi

    echo "Downloading $url -> $out ..."
    # -f: fail on HTTP errors; -L: follow Zenodo redirects; --retry: ride out
    # transient Zenodo flakiness (the whole reason this asset exists).
    curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
        -o "$out" "$url"

    # are_weights_ready() (ImmuneBuilder/util.py) treats a 0-byte file or one
    # starting with "EMPTY" as not-ready. Guard against a truncated/placeholder
    # download here so a bad fetch fails the build instead of shipping a broken
    # asset that silently re-triggers the runtime download.
    if [ ! -s "$out" ]; then
        echo "Error: downloaded $out is empty" >&2
        exit 1
    fi
    firstbytes=$(head -c 5 "$out")
    if [ "$firstbytes" = "EMPTY" ]; then
        echo "Error: $out is an EMPTY placeholder, not real weights" >&2
        exit 1
    fi
done

# Bundle the BSD-3 license alongside the weights so it ships inside the asset.
LICENSE_SRC="$(dirname "$MODEL_INFO")/LICENSE"
if [ -f "$LICENSE_SRC" ]; then
    cp "$LICENSE_SRC" "$OUTPUT_DIR/LICENSE"
    echo "Bundled license: $LICENSE_SRC -> $OUTPUT_DIR/LICENSE"
else
    echo "WARNING: no LICENSE at $LICENSE_SRC; asset will ship without an explicit license." >&2
fi

echo "Done. Files in $OUTPUT_DIR:"
ls -la "$OUTPUT_DIR"
