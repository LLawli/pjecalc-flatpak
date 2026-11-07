# Como o pacote funciona

## O que vem de onde

O manifesto não leva nada do PJe-Calc. Dois arquivos chegam como extra-data, na
máquina de quem instala:

- o instalador oficial de Windows, `pjecalc-<versão>-instalador-x64.exe`, do
  espelho nos releases deste repositório (ver Atualizações);
- o Zulu 8 JRE para Linux, da Azul.

O instalador é um 7-Zip autoextraível. `src/apply_extra.sh` o lê com o `bsdtar`
do runtime, sem executar nada, e guarda em `/app/extra/pjecalc` tudo menos o
Java de Windows (`bin/jre`) e o Firefox Portable (`navegador`). O Zulu vai para
`/app/extra/java`.

## Por que Java de Linux e não Wine

O PJe-Calc é Java: Tomcat 7 com a aplicação web (Seam 2, JSF), banco H2 e um
lançador, `bin/pjecalc.jar`. O lançador já tem caminho para Linux
(`OSValidator`), e no Linux procura o navegador em
`navegador/linux/Firefox-45.0.1-x86_64.AppImage`. Com o Java 8 de Linux ele roda
sem mudança. O Java precisa ser o 8: o `.bat` passa `-XX:MaxPermSize`, e o
Tomcat 7 com Seam 2 não foi feito para os módulos do Java 9 em diante.

## As opções do Java

Saem do `iniciarPjeCalc.bat` do próprio instalador, no `apply_extra`, para
`/app/extra/java-options`. Uma delas é obrigatória:
`-Dseguranca.pjekz.servico.contexto`. Sem ela, a tela de entrada dá "Erro
Interno no Servidor" (NullPointerException em `Aplicacao.getUrlPJe`). O
instalador da BigLinux, que copia as opções à mão, não a tem. Ler do `.bat` faz
uma versão nova que mude o token de serviço ou o contexto funcionar sem mudança
aqui. Se o formato do `.bat` mudar, o `apply_extra` falha em vez de gerar
opções erradas.

## A pasta de trabalho

O lançador usa a pasta atual como pasta de instalação: sobe o Tomcat nela e
guarda o banco em `.dados/`. `/app/extra` é somente leitura, então
`src/pjecalc.sh` monta essa pasta em `$XDG_DATA_HOME/pjecalc`
(`~/.var/app/br.jus.trt8.PJeCalc/data/pjecalc`):

| Caminho | O que é |
|---|---|
| `bin`, `tomcat/lib`, `tomcat/webapps`, `pjecalc_splash.gif` | links para `/app/extra/pjecalc` |
| `tomcat/conf` | cópia, refeita a cada versão; o Tomcat escreve em `conf/Catalina` |
| `tomcat/work`, `tomcat/logs` | do Tomcat; `work` é apagado a cada versão |
| `.dados/pjecalc.h2.db` | o banco, copiado do inicial só na primeira vez |
| `.dados.anterior` | cópia do banco antes da última atualização |
| `navegador/linux/Firefox-45.0.1-x86_64.AppImage` | link para `pjecalc-browser` |
| `version` | a versão que montou a pasta |

O banco é migrado pelo próprio PJe-Calc, que traz `migrations/<versão>` no jar
de negócio. Uma versão nova abre o banco antigo e o atualiza.

O lançador transforma `persistence.xml.tmp` em `persistence.xml` na primeira
subida, dentro de `tomcat/webapps`, que aqui é somente leitura. Medido: o
arquivo gerado é idêntico ao modelo, então o `apply_extra` só troca o nome. É a
única mudança nos arquivos do TRT8, declarada como `file-change` na FlatPark.

## O navegador

Com bandeja do sistema (KDE, XFCE), o lançador abre a página sozinho. Sem ela
(GNOME, a maioria dos Wayland), mostra uma janelinha com "Abrir o PjeCalc" e
"Sair". `pjecalc.sh` abre a página quando o Tomcat responde, e
`pjecalc-browser` descarta um segundo pedido em 5 segundos, para não abrir duas
abas. A página abre pelo portal OpenURI (`xdg-open` do runtime), no navegador do
usuário, fora do sandbox; ele alcança o Tomcat porque `--share=network` divide a
rede com o host.

Se o PJe-Calc já está rodando, abrir de novo só abre a página: o lançador
perguntaria se deve reaproveitar a instância, e a resposta útil é sempre sim.

## Certificados

O PJe-Calc Cidadão entra como usuário `offline`, sem certificado. As telas de
login com certificado (PJeOffice, Shodo) são do PJe-Calc institucional e falam
com o PJeOffice pelo navegador, não pelo processo do PJe-Calc. Nenhum jar do
PJe-Calc abre PKCS#11. Por isso o pacote não pede o socket do p11-kit: quem
assina é o PJeOffice Pro, que já funciona com o Tessera.

## Atualizações

O `www.trt8.jus.br` bloqueia por país (medido em 2026-11-07, com e sem
User-Agent de navegador): 403 de uma VPS em Viena e dos runners do GitHub, 200
de banda larga no Brasil e de uma VPS num datacenter de São Paulo, que baixou
os mesmos bytes. Com a URL do TRT8 no manifesto, ninguém fora do Brasil
instalaria, e o CI da FlatPark não conseguiria fixar nem conferir uma versão.

Por isso cada instalador é espelhado, sem alteração, num release deste
repositório, com a tag `v<versão>`. O PJe-Calc é software público gratuito da
Justiça do Trabalho. `scripts/espelhar.sh` roda uma vez por dia numa máquina no
Brasil, por um timer systemd de usuário (`packaging/systemd/`):

1. lê a página de instalação do TRT8 e pega a maior versão x64, o MD5 publicado
   ao lado do link e a data de publicação;
2. sai se o release dessa versão já existe;
3. baixa o instalador e para se o MD5 não bater;
4. roda o `apply_extra.sh` do pacote sobre o arquivo real, com o JRE do
   manifesto, e para se ele falhar ou se a pasta não for da versão anunciada;
5. cria o release com o instalador e, nas notas, a origem, o MD5, o SHA-256 e a
   data de publicação no TRT8.

Uma falha aparece como notificação na área de trabalho e no
`journalctl --user -u pjecalc-espelho`. O release dispara
`.github/workflows/release.yml`, que baixa o asset do GitHub, confere o SHA-256
das notas, passa de novo pelo `apply_extra` e avisa a FlatPark com o
`publish-action`. O `resolve-update.sh` da FlatPark lê o último release daqui.
O Zulu fica fixo no resolvedor: trocá-lo é um PR, porque a versão comparada é a
do PJe-Calc.

Para instalar o timer nesta máquina:

```sh
ln -sf ~/Personal/pjecalc-flatpak/packaging/systemd/pjecalc-espelho.* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now pjecalc-espelho.timer
```

O manifesto daqui fica na versão testada à mão; quem acompanha os releases é a
cópia na FlatPark.

## Medido

Em 2026-11-07, PJe-Calc 2.16.0 e Zulu 8.0.512:

- no host (Omarchy, Flatpak 1.18.2, instalação `--user`): página principal,
  criação e gravação de um cálculo, reinício com o cálculo na lista de recentes;
  o botão "Abrir o PjeCalc" abre o navegador pelo portal;
- numa VM Fedora 44 (Flatpak 1.18.4), instalação `--system` a partir de um
  repositório assinado: o `apply_extra` como root sem capabilities, o app como
  usuário comum em Xvfb, as páginas com 200, o banco migrado e gravado, e de
  novo depois de `flatpak kill`;
- `check-apply-extra.sh` e `publish.sh --verify` da FlatPark.

Subida a frio: cerca de 15 s no host, 50 s na VM com 2 núcleos.
