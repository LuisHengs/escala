# escala_app

O app Flutter (web/PWA) da escala de coroinhas.

- Visão geral do projeto: [../README.md](../README.md)
- Documentação completa: [../docs/DOCUMENTACAO.md](../docs/DOCUMENTACAO.md)

## Como rodar

```bash
flutter pub get
flutter test
flutter run -d chrome --web-port=3000 --dart-define-from-file=env.json
```

A porta 3000 é a que está liberada no Google e no Supabase para o retorno do
login.

## Configuração

O app lê as chaves do arquivo `env.json`, que **não vai para o Git**. Crie-o
nesta pasta:

```json
{
  "SUPABASE_URL": "https://SEU-PROJETO.supabase.co",
  "SUPABASE_KEY": "SUA-CHAVE-PUBLISHABLE"
}
```

Use só a chave **publishable** (a pública). Nunca coloque a chave `secret`.

## Estrutura

```text
lib/
  data/      repositório (interface e Supabase) e modelos
  telas/     as telas
  config.dart, formatacao.dart, mensagem_de_erro.dart, main.dart
test/
  fakes/     o repositório falso usado nos testes das telas
```

O `supabase_escala_repository.dart` é o único arquivo (junto com o `main.dart`)
que conhece o pacote do Supabase. As telas só conversam com a interface
`EscalaRepository`.

## Testes

```bash
dart analyze
flutter analyze
flutter test
```

O projeto é feito em TDD: o teste vem primeiro e falha (vermelho); só depois
vem o código que o faz passar (verde). Os testes de tela usam o repositório
falso e não acessam a rede. O banco tem testes próprios em
`../supabase/tests/`, rodados no SQL Editor.