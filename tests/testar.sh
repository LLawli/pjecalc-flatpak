#!/bin/sh
# Testa o apply_extra e o lançador com um instalador falso, no mesmo formato do
# oficial (7-Zip com a pasta pjecalc-windows64-<versão>), e um Java falso que só
# anota como foi chamado. Não baixa nada e não abre navegador.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'kill "${servidor:-}" 2>/dev/null || true; rm -rf "$tmp"' EXIT
falhas=0

confere() { # <descrição> <comando...>
    descricao=$1
    shift
    if "$@"; then
        echo "  ok   $descricao"
    else
        echo "  FALHA $descricao" >&2
        falhas=$((falhas + 1))
    fi
}

instalador_falso() { # <versão> <destino>
    origem="$tmp/origem-$1/pjecalc-windows64-$1"
    mkdir -p "$origem/bin/lib" "$origem/bin/jre/bin" "$origem/navegador/windows" \
        "$origem/.dados" "$origem/tomcat/conf" "$origem/tomcat/lib" \
        "$origem/tomcat/webapps/pjecalc/WEB-INF/classes/META-INF"
    echo jar > "$origem/bin/pjecalc.jar"
    echo exe > "$origem/bin/jre/bin/javaw.exe"
    echo exe > "$origem/navegador/windows/FirefoxPortable.exe"
    echo "banco $1" > "$origem/.dados/pjecalc.h2.db"
    echo '<Server/>' > "$origem/tomcat/conf/server.xml"
    echo '<persistence/>' > "$origem/tomcat/webapps/pjecalc/WEB-INF/classes/META-INF/persistence.xml.tmp"
    echo gif > "$origem/pjecalc_splash.gif"
    # O .bat oficial, com CRLF e as aspas que ele tem.
    printf '@echo\r\nset local=%%~dp0\r\ncd %%local%%\r\nstart bin\\jre\\bin\\javaw -splash:pjecalc_splash.gif -Duser.timezone=GMT-3 -Dfile.encoding=ISO-8859-1 -Dseguranca.pjecalc.tokenServicos=TOKEN%s -Dseguranca.pjekz.servico.contexto="https://pje.trtXX.jus.br/pje-seguranca" -Xms1024m -Xmx2048m -XX:MaxPermSize=512m -jar bin\\pjecalc.jar\r\n' \
        "$1" > "$origem/iniciarPjeCalc.bat"
    (cd "$tmp/origem-$1" && bsdtar --format 7zip -cf "$2/pjecalc-installer.exe" "pjecalc-windows64-$1")

    mkdir -p "$tmp/jre-$1/zulu-falso/bin"
    printf '#!/bin/sh\n' > "$tmp/jre-$1/zulu-falso/bin/java"
    chmod +x "$tmp/jre-$1/zulu-falso/bin/java"
    tar -czf "$2/jre.tar.gz" -C "$tmp/jre-$1" zulu-falso
}

echo '== apply_extra'
extra="$tmp/extra"
mkdir -p "$extra"
instalador_falso 9.9.0 "$extra"
(cd "$extra" && sh "$raiz/src/apply_extra.sh")

confere 'versão vem do nome da pasta' test "$(cat "$extra/version")" = 9.9.0
confere 'apaga os arquivos baixados' test ! -e "$extra/pjecalc-installer.exe" -a ! -e "$extra/jre.tar.gz"
confere 'deixa de fora o Java do Windows' test ! -e "$extra/pjecalc/bin/jre"
confere 'deixa de fora o Firefox Portable' test ! -e "$extra/pjecalc/navegador"
confere 'mantém o banco inicial' test -f "$extra/pjecalc/.dados/pjecalc.h2.db"
confere 'persistence.xml no lugar do modelo' test -f "$extra/pjecalc/tomcat/webapps/pjecalc/WEB-INF/classes/META-INF/persistence.xml"
confere 'Java de Linux em java/' test -x "$extra/java/bin/java"
esperado='-splash:pjecalc_splash.gif
-Duser.timezone=GMT-3
-Dfile.encoding=ISO-8859-1
-Dseguranca.pjecalc.tokenServicos=TOKEN9.9.0
-Dseguranca.pjekz.servico.contexto=https://pje.trtXX.jus.br/pje-seguranca
-Xms1024m
-Xmx2048m
-XX:MaxPermSize=512m'
confere 'opções do Java iguais às do .bat' test "$(cat "$extra/java-options")" = "$esperado"

# Um .bat de outro formato tem que parar a instalação, não gerar opções erradas.
quebrado="$tmp/quebrado"
mkdir -p "$quebrado"
instalador_falso 9.9.1 "$quebrado"
(cd "$tmp/origem-9.9.1" && sed -i 's/tokenServicos/outraCoisa/' pjecalc-windows64-9.9.1/iniciarPjeCalc.bat \
    && rm "$quebrado/pjecalc-installer.exe" \
    && bsdtar --format 7zip -cf "$quebrado/pjecalc-installer.exe" pjecalc-windows64-9.9.1)
confere 'recusa um .bat sem o token' sh -c "cd '$quebrado' && ! sh '$raiz/src/apply_extra.sh' 2>/dev/null"

echo '== lançador'
# Java falso: anota a pasta e os argumentos, como o lançador do PJe-Calc os veria.
cat > "$extra/java/bin/java" <<EOF
#!/bin/sh
pwd > "$tmp/java-pasta"
printf '%s\n' "\$@" > "$tmp/java-args"
EOF
navegador="$tmp/navegador"
printf '#!/bin/sh\necho "$1" >> %s/navegador-abriu\n' "$tmp" > "$navegador"
chmod +x "$navegador"

roda() {
    PJECALC_EXTRA="$extra" PJECALC_BROWSER="$navegador" PJECALC_URL="${url:-http://127.0.0.1:1/pjecalc}" \
        XDG_DATA_HOME="$tmp/dados" sh "$raiz/src/pjecalc.sh"
}
dados="$tmp/dados/pjecalc"

roda
confere 'roda o Java na pasta de dados' test "$(cat "$tmp/java-pasta")" = "$dados"
confere 'passa as opções do .bat e o jar' test "$(cat "$tmp/java-args")" = "$esperado
-jar
bin/pjecalc.jar"
confere 'programa ligado a /app/extra' test "$(readlink "$dados/bin")" = "$extra/pjecalc/bin"
confere 'webapps ligado a /app/extra' test "$(readlink "$dados/tomcat/webapps")" = "$extra/pjecalc/tomcat/webapps"
confere 'navegador do lançador aponta para o portal' test "$(readlink "$dados/navegador/linux/Firefox-45.0.1-x86_64.AppImage")" = "$navegador"
confere 'conf do Tomcat copiado e gravável' test -w "$dados/tomcat/conf/server.xml" -a ! -L "$dados/tomcat/conf"
confere 'banco copiado do inicial' test "$(cat "$dados/.dados/pjecalc.h2.db")" = 'banco 9.9.0'
confere 'banco gravável' test -w "$dados/.dados/pjecalc.h2.db"

echo 'cálculos do usuário' > "$dados/.dados/pjecalc.h2.db"
mkdir -p "$dados/tomcat/work/velho"
roda
confere 'mesma versão não mexe no banco' test "$(cat "$dados/.dados/pjecalc.h2.db")" = 'cálculos do usuário'
confere 'mesma versão não faz cópia' test ! -e "$dados/.dados.anterior"
confere 'mesma versão mantém o work' test -d "$dados/tomcat/work/velho"

echo 9.9.2 > "$extra/version"
roda
confere 'versão nova mantém o banco do usuário' test "$(cat "$dados/.dados/pjecalc.h2.db")" = 'cálculos do usuário'
confere 'versão nova guarda cópia do banco' test "$(cat "$dados/.dados.anterior/pjecalc.h2.db")" = 'cálculos do usuário'
confere 'versão nova limpa o work' test ! -e "$dados/tomcat/work/velho"
confere 'versão nova anotada' test "$(cat "$dados/version")" = 9.9.2

# Já aberto: só abre a página, sem outro Java.
mkdir -p "$tmp/www/pjecalc"
echo ok > "$tmp/www/pjecalc/index.html"
porta=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server --bind 127.0.0.1 --directory "$tmp/www" "$porta" >/dev/null 2>&1 &
servidor=$!
i=0
until curl -fs -o /dev/null "http://127.0.0.1:$porta/pjecalc/"; do
    i=$((i + 1))
    [ "$i" -lt 50 ] || break
    sleep 0.1
done
rm -f "$tmp/java-args" "$tmp/navegador-abriu"
url="http://127.0.0.1:$porta/pjecalc" roda
confere 'já aberto: abre a página' test "$(cat "$tmp/navegador-abriu")" = "http://127.0.0.1:$porta/pjecalc"
confere 'já aberto: não sobe outro Java' test ! -e "$tmp/java-args"

echo '== navegador'
mkdir -p "$tmp/bin" "$tmp/run"
printf '#!/bin/sh\necho "$1" >> %s/xdg-abriu\n' "$tmp" > "$tmp/bin/xdg-open"
chmod +x "$tmp/bin/xdg-open"
for _ in 1 2; do
    PATH="$tmp/bin:$PATH" XDG_RUNTIME_DIR="$tmp/run" sh "$raiz/src/pjecalc-browser.sh" http://localhost:9257/pjecalc
done
confere 'dois pedidos seguidos abrem uma aba' test "$(wc -l < "$tmp/xdg-abriu")" -eq 1
touch -d '-1 minute' "$tmp/run/pjecalc-browser"
PATH="$tmp/bin:$PATH" XDG_RUNTIME_DIR="$tmp/run" sh "$raiz/src/pjecalc-browser.sh" http://localhost:9257/pjecalc
confere 'pedido mais tarde abre de novo' test "$(wc -l < "$tmp/xdg-abriu")" -eq 2

if [ "$falhas" -ne 0 ]; then
    echo "$falhas falha(s)" >&2
    exit 1
fi
