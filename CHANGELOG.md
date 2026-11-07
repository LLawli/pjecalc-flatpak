# Changelog

Formato do [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Unreleased]

### Added

- Pacote Flatpak do PJe-Calc Cidadão 2.16.0, com o instalador oficial de
  Windows baixado na instalação e o Zulu 8 JRE para Linux, sem Wine.
- Opções do Java lidas do `iniciarPjeCalc.bat` do próprio instalador.
- Banco e configuração do Tomcat na pasta de dados do app, com cópia do banco
  anterior a cada versão nova.
- A página abre no navegador do usuário, pelo portal, também em desktops sem
  bandeja do sistema.
- Espelho do instalador nos releases deste repositório, porque o TRT8 só atende
  conexões do Brasil. `scripts/espelhar.sh`, num timer diário, publica cada
  versão nova depois de conferir o MD5 do TRT8 e passar pelo `apply_extra`.
- Atualização automática pela FlatPark, a partir desses releases.
- A Action de release atualiza o manifesto, o metainfo e o CHANGELOG daqui para
  cada versão espelhada, com um commit do `github-actions[bot]`.
