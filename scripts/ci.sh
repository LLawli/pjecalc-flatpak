#!/bin/sh
# Todas as verificações. O CI roda este mesmo comando.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
id=br.jus.trt8.PJeCalc
cd "$raiz"

scripts="src/*.sh scripts/*.sh tests/*.sh resolve-update.sh"

# Sem o binário, a imagem oficial: a mesma ferramenta, sem instalar nada.
echo '== shellcheck'
if shellcheck --version >/dev/null 2>&1; then
    # shellcheck disable=SC2086 # a lista de globs se expande aqui
    shellcheck -S warning $scripts
else
    motor=$(command -v podman || command -v docker)
    # shellcheck disable=SC2086
    "$motor" run --rm -v "$raiz:/mnt:z" -w /mnt docker.io/koalaman/shellcheck:stable \
        -S warning $scripts
fi

echo '== metadados'
desktop-file-validate --no-hints "$id.desktop"
# Sem --pedantic: ele recusa maiúsculas no id, e o id segue o domínio e o
# nome do fornecedor, como o br.jus.cnj.PJeOfficePro da FlatPark.
appstreamcli validate --no-net "$id.metainfo.xml"

# A versão do metainfo é a que a FlatPark compara; tem que ser a do manifesto.
versao=$(sed -n 's/.*<release version="\([^"]*\)".*/\1/p' "$id.metainfo.xml" | head -1)
grep -qF "/pjecalc-$versao-instalador-x64.exe" "$id.yml" || {
    echo "o metainfo diz $versao, o manifesto aponta outro instalador" >&2
    exit 1
}

echo '== testes'
./tests/testar.sh

# As únicas dependências externas são os dois downloads: o espelho nos releases
# daqui e o JRE da Azul. Um site fora do ar não é defeito daqui; um tamanho
# diferente é.
echo '== downloads'
sed -n 's/^ *url: //p' "$id.yml" > "${TMPDIR:-/tmp}/pjecalc-urls"
sed -n 's/^ *size: //p' "$id.yml" > "${TMPDIR:-/tmp}/pjecalc-tamanhos"
paste "${TMPDIR:-/tmp}/pjecalc-urls" "${TMPDIR:-/tmp}/pjecalc-tamanhos" | while read -r url esperado; do
    # Uma página de erro também tem Content-Length: o tamanho só vale com 200.
    cabecalhos=$(curl -sIL -m 30 -A 'Mozilla/5.0' "$url" | tr -d '\r' || true)
    status=$(printf '%s\n' "$cabecalhos" | sed -n 's/^HTTP\/[0-9.]* \([0-9]*\).*/\1/p' | tail -1)
    tamanho=$(printf '%s\n' "$cabecalhos" | sed -n 's/^[Cc]ontent-[Ll]ength: //p' | tail -1)
    if [ "$status" = 404 ]; then
        echo "$url não existe (404): a instalação quebraria" >&2
        exit 1
    elif [ "$status" != 200 ]; then
        echo "  aviso: $url inacessível daqui (${status:-sem resposta})"
    elif [ "$tamanho" != "$esperado" ]; then
        echo "$url mudou: $tamanho bytes, o manifesto diz $esperado" >&2
        exit 1
    else
        echo "  ok   $tamanho bytes  $url"
    fi
done
rm -f "${TMPDIR:-/tmp}/pjecalc-urls" "${TMPDIR:-/tmp}/pjecalc-tamanhos"
