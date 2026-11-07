#!/bin/sh
# Leva o manifesto, o metainfo e o CHANGELOG para um instalador espelhado.
# Roda na Action de release, depois de o asset ser conferido; não faz commit.
# Sem nada a mudar (a versão já está no manifesto), sai sem tocar em nada.
#
#   ./scripts/atualizar-manifesto.sh <versão> <url> <sha256> <tamanho> [<data AAAA-MM-DD>]
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
id=br.jus.trt8.PJeCalc
versao=${1:?versão}
url=${2:?url}
sha256=${3:?sha256}
tamanho=${4:?tamanho}
data=${5:-$(date -u +%F)}

case "$versao" in *[!0-9.]* | '') echo "versão inválida: $versao" >&2; exit 1 ;; esac
printf '%s' "$sha256" | grep -qxE '[0-9a-f]{64}' || { echo "sha256 inválido: $sha256" >&2; exit 1; }
case "$tamanho" in *[!0-9]* | '') echo "tamanho inválido: $tamanho" >&2; exit 1 ;; esac
printf '%s' "$data" | grep -qxE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || { echo "data inválida: $data" >&2; exit 1; }

atual=$(sed -n 's|.*/pjecalc-\([0-9.]*\)-instalador-x64\.exe$|\1|p' "$raiz/$id.yml")
[ -n "$atual" ] || { echo "não achei a versão atual no manifesto" >&2; exit 1; }
if [ "$atual" = "$versao" ]; then
    echo "o manifesto já está na $versao"
    exit 0
fi
# Um disparo manual com uma tag antiga não pode rebaixar o pacote.
if [ "$(printf '%s\n%s\n' "$atual" "$versao" | sort -V | tail -n 1)" != "$versao" ]; then
    echo "a $versao é anterior à $atual do manifesto" >&2
    exit 1
fi

python3 -I - "$raiz" "$id" "$versao" "$url" "$sha256" "$tamanho" "$data" <<'PY'
import re, sys
raiz, app, versao, url, sha256, tamanho, data = sys.argv[1:8]

# Manifesto: só o bloco do instalador, dentro do bloco gerenciado.
p = f"{raiz}/{app}.yml"
texto = open(p, encoding="utf-8").read()
bloco = re.compile(
    r"(filename: pjecalc-installer\.exe\n(?:\s+.*\n)*?\s+url: ).*\n(\s+sha256: ).*\n(\s+size: ).*\n")
novo, n = bloco.subn(lambda m: f"{m[1]}{url}\n{m[2]}{sha256}\n{m[3]}{tamanho}\n", texto, count=1)
if n != 1:
    sys.exit("não achei o bloco do instalador no manifesto")
open(p, "w", encoding="utf-8").write(novo)

# Metainfo: a versão nova vira o primeiro <release>, que é o que a FlatPark compara.
p = f"{raiz}/{app}.metainfo.xml"
texto = open(p, encoding="utf-8").read()
novo, n = re.subn(r"(<releases>\n)(\s*)",
                  lambda m: f'{m[1]}{m[2]}<release version="{versao}" date="{data}"/>\n{m[2]}',
                  texto, count=1)
if n != 1:
    sys.exit("não achei <releases> no metainfo")
open(p, "w", encoding="utf-8").write(novo)

# CHANGELOG: uma linha em [Unreleased] > Changed.
p = f"{raiz}/CHANGELOG.md"
texto = open(p, encoding="utf-8").read()
inicio = texto.index("## [Unreleased]")
fim = texto.find("\n## [", inicio + 1)
fim = len(texto) if fim == -1 else fim
secao = texto[inicio:fim]
linha = f"- PJe-Calc Cidadão {versao}, publicado pelo TRT8 em {data}.\n"
if "### Changed\n" in secao:
    secao = secao.replace("### Changed\n\n", "### Changed\n\n" + linha, 1)
else:
    secao = secao.rstrip("\n") + "\n\n### Changed\n\n" + linha
texto = texto[:inicio] + secao + texto[fim:]
open(p, "w", encoding="utf-8").write(texto)
PY
echo "manifesto na $versao"
