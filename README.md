# PJe-Calc Cidadão em Flatpak

O PJe-Calc Cidadão, o sistema de cálculos trabalhistas da Justiça do Trabalho,
só tem instalador para Windows. Este pacote é para advogados, contadores e
peritos que usam Linux, inclusive sistemas imutáveis como Silverblue e Bluefin,
e querem o PJe-Calc sem Wine e sem instalar nada fora do sandbox.

> Pacote da comunidade, sem vínculo com o TRT8 ou o CSJT. O programa é baixado
> do site do TRT8 na instalação. O identificador `br.jus.trt8.PJeCalc` segue o
> domínio do TRT8, que desenvolve o PJe-Calc, e não indica autoria do pacote.

## Instalar

Pela [FlatPark](https://flatpark.org):

```sh
flatpak remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak install flatpark br.jus.trt8.PJeCalc
```

A instalação baixa o instalador oficial (cerca de 280 MB) do site do TRT8 e um
Java 8 para Linux da Azul (cerca de 40 MB), e confere o sha256 dos dois.

## Usar

Abra **PJe-Calc Cidadão** no menu de aplicativos. Ele sobe em segundo plano e
abre `http://localhost:9257/pjecalc` no seu navegador. A janelinha do PJe-Calc
fica aberta enquanto ele roda: **Abrir o PjeCalc** abre a página de novo e
**Sair** encerra.

Os cálculos ficam em `~/.var/app/br.jus.trt8.PJeCalc/data/pjecalc`. Quando uma
versão nova abre pela primeira vez, o PJe-Calc atualiza o banco, e a cópia do
banco anterior fica em `.dados.anterior`, na mesma pasta, até a próxima versão.
Exporte os cálculos importantes pelo próprio PJe-Calc antes de atualizar, como
no Windows.

## Certificado digital

O PJe-Calc Cidadão não usa certificado: ele entra sozinho, no modo offline. Onde
um sistema do tribunal pede assinatura, quem assina é o
[PJeOffice Pro da FlatPark](https://flatpark.org/apps/br.jus.cnj.PJeOfficePro/),
que funciona com token A3 pelo
[Tessera](https://flatpark.org/apps/io.github.pedrohqb.Tessera/). Este pacote
não precisa de nenhuma permissão de token.

## Para quem contribui

[docs/arquitetura.md](docs/arquitetura.md) explica como o pacote funciona e o
que foi medido. `./scripts/ci.sh` roda todas as verificações, as mesmas do CI.
Para construir e instalar a partir do código:

```sh
flatpak install flathub org.flatpak.Builder
./scripts/construir.sh
```

`./scripts/flatpark.sh <clone da FlatPark>` monta o diretório do app no registry
da FlatPark a partir daqui.

## Licença

O empacotamento é GPL-3.0. O PJe-Calc é da Justiça do Trabalho, e nada dele
está neste repositório.
