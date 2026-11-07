#!/bin/sh
# Monta o diretório do app no registry da FlatPark a partir deste repositório,
# que é a fonte. A FlatPark quer os arquivos lado a lado, então os de src/ sobem
# um nível e o manifesto passa a citá-los assim.
#
#   ./scripts/flatpark.sh ~/Personal/flatpark
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
id=br.jus.trt8.PJeCalc
destino="${1:?caminho do clone da FlatPark}/registry/$id"

mkdir -p "$destino"
sed 's|path: src/|path: |' "$raiz/$id.yml" > "$destino/$id.yml"
cp "$raiz/$id.desktop" "$raiz/$id.metainfo.xml" "$raiz/$id.png" \
    "$raiz/flatpark.yml" "$raiz/resolve-update.sh" \
    "$raiz/src/apply_extra.sh" "$raiz/src/pjecalc.sh" "$raiz/src/pjecalc-browser.sh" \
    "$destino/"
echo "$destino"
