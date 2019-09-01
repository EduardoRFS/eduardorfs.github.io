---
title: ReasonML Native - Criando um projeto
tags:
---

## Glossário

## Requerimentos

- yarn instalado

## Instalação

```
yarn global add esy pesy
```

## Criar projeto

Para começar, você precisa criar uma nova pasta e abrir um terminal dentro dela, nesse caso o nome da pasta será `crud-reason`

```sh
pesy
```

<insira-imagem-aqui>

## Executar

Por padrão o `pesy` vai criar um projeto com um executável, para descobrir o nome você executa

```sh
esy
```

<insira-imagem-aqui>

Ele vai mostrar para você um comando para executar sua aplicação, nesse caso

```sh
esy x CrudReasonApp.exe
```

<insira-imagem-aqui>

Após isso no seu terminal vai ter uma saida de `Hello`

## Adicionando dependencia

O esy funciona muito parecido com o yarn, essencialmente as dependencias são controladas no `package.json`, para adicionar uma dependencia, por exemplo o `@reason-native/console` é só rodar:

```sh
esy add @reason-native/console
```

<insira-imagem-aqui>

Porém isso vai apenas adicionar a dependencia e não cadastra-lá para o uso dentro do nosso executável, para fazer isso é necessário editar o `package.json` em `buildDirs.executable.require`, você adiciona na array o nome da lib exportada, nesse caso `console.lib`, o resultado será o seguinte:
<insira-imagem-aqui>

Após isso será necessário atualizar os arquivos de configuração do `dune` para isso só executar

```sh
esy pesy
```

E a lib estará disponivel para uso dentro da nossa pasta `executable`

Por exemplo se editar o `executable/CrudReasonApp.exe` para ficar assim:

```reasonml
CrudReason.Util.foo();
Console.log("World");
```

Ao rodar novamente com

```sh
esy x CrudReasonApp.exe
```

A saida será <insira-imagem_aqui>
