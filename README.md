# Escala Coroinhas

App para organizar a escala de coroinhas de uma paróquia com duas igrejas:
consultar a escala, confirmar presença, pedir e aceitar trocas, e o
coordenador cadastrar missas e escalar. Feito com Flutter (web/PWA) e Supabase.

**Documentação completa:** [docs/DOCUMENTACAO.md](docs/DOCUMENTACAO.md)
(onde estamos, regras de negócio, banco, testes, pendências).

## Pastas

| Pasta | O que é |
|---|---|
| `escala_core/` | Regras em Dart puro (sem Flutter nem banco) e o tradutor de erros do banco |
| `escala_app/` | O app Flutter (web/PWA) |
| `supabase/migrations/` | As migrações do banco, em ordem |
| `supabase/testes/` | Testes SQL (colar no SQL Editor) |
| `supabase/scripts/` | Scripts avulsos: administrador, auditoria de segurança, dados de teste |
| `ferramentas/` | Página local de teste do login Google |
| `docs/` | A documentação |

## Como rodar

```bash
# regras (Dart puro)
cd escala_core && dart test

# app
cd ../escala_app
flutter test
flutter run -d chrome --web-port=3000 --dart-define-from-file=env.json
```

O `env.json` (fora do Git) tem a URL do projeto Supabase e a chave **pública**:

```json
{
  "SUPABASE_URL": "https://SEU-PROJETO.supabase.co",
  "SUPABASE_KEY": "a-chave-publica"
}
```

Nunca coloque a chave `service_role` nem o segredo do Google em arquivos do projeto.
