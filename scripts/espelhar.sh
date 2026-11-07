#!/bin/sh
# Espelha num Release deste repositório o instalador x64 mais novo do PJe-Calc
# Cidadão, idêntico ao do TRT8. O TRT8 só responde a conexões do Brasil, então
# isto roda numa máquina no Brasil, todo dia, por um timer systemd
# (packaging/systemd). O Release dispara a Action que avisa a FlatPark.
#
# Nada é publicado sem que o arquivo bata com o MD5 que o próprio TRT8 mostra
# ao lado do link, tenha a pasta esperada e passe pelo apply_extra do pacote.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
repo=${PJECALC_REPO:-LLawli/pjecalc-flatpak}
site=${PJECALC_SITE:-https://www.trt8.jus.br}
pagina=${PJECALC_PAGINA:-$site/pjecalc-cidadao/instalando-o-pje-calc-cidadao}
cache=${PJECALC_CACHE:-/mnt/dados/caches/pjecalc-flatpak/espelho}
jre_url=${PJECALC_JRE_URL:-$(sed -n 's/^ *url: \(.*jre.*\)$/\1/p' "$raiz/br.jus.trt8.PJeCalc.yml")}

# Uma falha precisa chegar a alguém: o timer roda sem terminal.
falhou() {
    status=$?
    [ "$status" -ne 0 ] || return 0
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical 'Espelho do PJe-Calc falhou' \
            'journalctl --user -u pjecalc-espelho' 2>/dev/null || true
    fi
}
trap falhou EXIT

erro() { echo "espelhar: $*" >&2; exit 1; }

html=$(curl -fsSL --retry 3 --retry-all-errors -m 60 -A 'Mozilla/5.0' "$pagina") \
    || erro "não consegui ler $pagina"
versao=$(printf '%s\n' "$html" | grep -oE 'pjecalc-[0-9]+(\.[0-9]+)+-instalador-x64\.exe' \
    | sed -E 's/^pjecalc-(.*)-instalador-x64\.exe$/\1/' | sort -Vu | tail -n 1)
[ -n "$versao" ] || erro "nenhum instalador x64 em $pagina"
nome=pjecalc-$versao-instalador-x64.exe
tag=v$versao

# O MD5 é o primeiro depois do link desse arquivo.
md5=$(printf '%s\n' "$html" | grep -A 3 -F "$nome" | grep -oE 'MD5\): *[0-9A-Fa-f]{32}' \
    | head -n 1 | grep -oE '[0-9A-Fa-f]{32}' | tr 'A-F' 'a-f')
[ -n "$md5" ] || erro "a página não mostra o MD5 de $nome"
data=$(printf '%s\n' "$html" | grep -oE 'Data de Publica[^:]{1,10}: *[0-9]{2}/[0-9]{2}/[0-9]{4}' \
    | head -n 1 | grep -oE '[0-9]{2}/[0-9]{2}/[0-9]{4}' \
    | awk -F / '{ print $3 "-" $2 "-" $1 }')

if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
    echo "$tag já está espelhado"
    exit 0
fi
echo "versão nova no TRT8: $versao (MD5 $md5, publicada em ${data:-data desconhecida})"

mkdir -p "$cache"
arquivo=$cache/$nome
if [ ! -f "$arquivo" ] || [ "$(md5sum < "$arquivo" | cut -c1-32)" != "$md5" ]; then
    curl -fsSL --retry 3 --retry-all-errors -A 'Mozilla/5.0' -o "$arquivo.part" \
        "$site/sites/portal/files/roles/pje-calc/$nome" || erro "download de $nome falhou"
    mv "$arquivo.part" "$arquivo"
fi
[ "$(md5sum < "$arquivo" | cut -c1-32)" = "$md5" ] || erro "$nome não bate com o MD5 do TRT8"

# O apply_extra do pacote, sobre o arquivo real: é o que roda na máquina de quem
# instala, e falha se o instalador mudar de forma.
jre=$cache/$(basename "$jre_url")
[ -f "$jre" ] || curl -fsSL --retry 3 -o "$jre" "$jre_url" || erro "download do JRE falhou"
prova=$(mktemp -d "$cache/prova.XXXXXX")
cp "$arquivo" "$prova/pjecalc-installer.exe"
cp "$jre" "$prova/jre.tar.gz"
(cd "$prova" && sh "$raiz/src/apply_extra.sh") || { rm -rf "$prova"; erro "o apply_extra recusou $nome"; }
[ "$(cat "$prova/version")" = "$versao" ] || { rm -rf "$prova"; erro "a pasta de $nome não é da versão $versao"; }
rm -rf "$prova"

sha256=$(sha256sum < "$arquivo" | cut -c1-64)
tamanho=$(stat -c %s "$arquivo")
notas=$(mktemp)
cat > "$notas" <<EOF
Espelho do instalador oficial do PJe-Calc Cidadão $versao para Windows x64, idêntico ao publicado pelo TRT8, sem nenhuma alteração.

- Origem: $site/sites/portal/files/roles/pje-calc/$nome
- Página: $pagina
- Data de publicação no TRT8: ${data:-desconhecida}
- MD5 publicado pelo TRT8: \`$md5\` (conferido)
- SHA-256: \`$sha256\`
- Tamanho: $tamanho bytes

O TRT8 só atende conexões do Brasil; este espelho existe para que o pacote Flatpak possa ser instalado e verificado de qualquer lugar.
EOF
gh release create "$tag" "$arquivo" --repo "$repo" --target main \
    --title "PJe-Calc Cidadão $versao" --notes-file "$notas"
rm -f "$notas"
# Só o instalador atual fica no cache.
find "$cache" -maxdepth 1 -name 'pjecalc-*-instalador-x64.exe' ! -name "$nome" -delete
echo "$tag publicado"
