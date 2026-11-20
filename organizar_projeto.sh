#!/usr/bin/env bash
# organizar_projeto.sh: arruma as pastas do projeto "escala".
#
# Rode DENTRO da pasta que contém escala_app, escala_core e supabase:
#
#   bash organizar_projeto.sh             só MOSTRA o que faria (nada muda)
#   bash organizar_projeto.sh --aplicar   faz de verdade
#
# Regras de segurança do script:
#   - nunca apaga nada;
#   - nunca sobrescreve: se o destino já existe, avisa e deixa como está;
#   - se a pasta for um repositório Git, usa "git mv" (o histórico acompanha);
#   - pode ser rodado de novo sem estragar nada.

set -euo pipefail

APLICAR=0
if [ "${1:-}" = "--aplicar" ]; then APLICAR=1; fi

# ---------- 1) estou na pasta certa? ----------
for pasta in escala_app escala_core supabase; do
  if [ ! -d "$pasta" ]; then
    echo "ERRO: não achei a pasta '$pasta' aqui."
    echo "Entre na pasta 'escala' (a que contém escala_app, escala_core e supabase) e rode de novo."
    exit 1
  fi
done

EM_GIT=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then EM_GIT=1; fi

if [ $APLICAR -eq 1 ]; then
  echo "== APLICANDO as mudanças =="
else
  echo "== SIMULAÇÃO: nada será alterado. Para aplicar: bash organizar_projeto.sh --aplicar =="
fi
echo "Pasta: $(pwd)"
if [ $EM_GIT -eq 1 ]; then echo "Git: sim (uso 'git mv' nos arquivos que já estão no Git)"; else echo "Git: não detectado (uso 'mv' simples)"; fi
echo

# ---------- funções auxiliares ----------
dizer() { printf '%s\n' "$*"; }

mover() { # mover ORIGEM DESTINO
  local de="$1" para="$2"
  if [ ! -e "$de" ]; then dizer "  - não existe, pulei:      $de"; return; fi
  if [ -e "$para" ]; then dizer "  ! JÁ EXISTE, não mexi:    $para (origem: $de)"; return; fi
  dizer "  mover   $de  ->  $para"
  if [ $APLICAR -eq 1 ]; then
    mkdir -p "$(dirname "$para")"
    if [ $EM_GIT -eq 1 ] && git ls-files --error-unmatch "$de" >/dev/null 2>&1; then
      git mv "$de" "$para"
    else
      mv "$de" "$para"
    fi
  fi
}

criar() { # criar CAMINHO   (o conteúdo vem da entrada padrão)
  local alvo="$1"
  if [ -e "$alvo" ]; then dizer "  - já existe, mantive:     $alvo"; cat >/dev/null; return; fi
  dizer "  criar   $alvo"
  if [ $APLICAR -eq 1 ]; then mkdir -p "$(dirname "$alvo")"; cat > "$alvo"; else cat >/dev/null; fi
}

garantir_no_gitignore() { # garantir_no_gitignore LINHA
  local linha="$1"
  if [ -f .gitignore ] && grep -qxF -- "$linha" .gitignore; then return; fi
  dizer "  .gitignore: acrescentar  $linha"
  if [ $APLICAR -eq 1 ]; then echo "$linha" >> .gitignore; fi
}

# ---------- 2) mover o que está fora do lugar ----------
dizer "[1/4] Mover arquivos"
mover DOCUMENTACAO.md                  docs/DOCUMENTACAO.md
mover supabase/admin.sql               supabase/scripts/admin.sql
mover supabase/auditoria_seguranca.sql supabase/scripts/auditoria_seguranca.sql
mover teste_login_google.html          ferramentas/teste_login_google.html
echo

# ---------- 3) criar o que falta ----------
dizer "[2/4] Criar arquivos que ajudam a não se perder"

criar supabase/scripts/admin.exemplo.sql << 'EOF'
-- MODELO do script que cria o primeiro administrador.
-- Copie este arquivo para admin.sql (que fica FORA do Git), troque os dois
-- valores em maiúsculas e rode no SQL Editor do Supabase.
--
-- Antes: entre no app UMA vez com a sua conta Google (vai cair na tela de
-- convite). É isso que cria a sua linha em auth.users.

insert into public.perfis (id, nome, papel)
select id, 'SEU NOME', 'admin'
from auth.users
where email = 'SEU_EMAIL_DO_GOOGLE';

select id, nome, papel, ativo from public.perfis where papel = 'admin';
EOF

criar supabase/scripts/dados_teste_escala.sql << 'EOF'
-- Dados de teste: duas missas na "Matriz (teste)", com o primeiro administrador
-- escalado nas duas: uma daqui a 26 horas e outra daqui a 90 minutos (o prazo
-- de confirmação dessa já passou).
--
-- Pode ser rodado várias vezes: primeiro apaga os restos da vez anterior.
-- Para só LIMPAR, use limpar_dados_teste.sql.

-- 1) limpa
delete from public.escalacoes
where missa_id in (
  select m.id from public.missas m
  join public.locais l on l.id = m.local_id
  where l.nome = 'Matriz (teste)');
delete from public.missas
where local_id in (select id from public.locais where nome = 'Matriz (teste)');
delete from public.locais where nome = 'Matriz (teste)';

-- 2) cria
insert into public.locais (nome) values ('Matriz (teste)');

insert into public.missas (inicio, local_id)
select x.inicio, l.id
from public.locais l,
     (values (now() + interval '26 hours'), (now() + interval '90 minutes')) as x(inicio)
where l.nome = 'Matriz (teste)';

insert into public.escalacoes (missa_id, coroinha_id, funcao)
select m.id,
       (select id from public.perfis where papel = 'admin' order by nome limit 1),
       'turiferário'
from public.missas m
join public.locais l on l.id = m.local_id
where l.nome = 'Matriz (teste)';
EOF

criar supabase/scripts/dados_teste_trocas.sql << 'EOF'
-- Dados de teste para as trocas: cria a "Maria (teste)", uma pessoa de mentira
-- (sem e-mail: ninguém entra como ela), com dois pedidos de troca abertos.
--
-- Rode ANTES o dados_teste_escala.sql e logo depois este: um dos pedidos fica
-- 30 minutos depois da sua missa de teste (mostra a mensagem de conflito) e o
-- outro fica livre (mostra o aceite).
-- Pode ser rodado várias vezes: o bloco 0) apaga os restos.

-- 0) limpa restos de tentativas anteriores
delete from public.escalacoes where coroinha_id = '00000000-0000-0000-0000-00000000aaaa';
delete from public.missas where local_id in (select id from public.locais where nome = 'Capela (teste)');
delete from public.locais where nome = 'Capela (teste)';
delete from auth.users where id = '00000000-0000-0000-0000-00000000aaaa';

-- 1) uma pessoa de mentira
insert into auth.users (id) values ('00000000-0000-0000-0000-00000000aaaa');
insert into public.perfis (id, nome) values ('00000000-0000-0000-0000-00000000aaaa', 'Maria (teste)');

-- 2) duas missas na "Capela (teste)": uma que conflita com a sua e outra livre
insert into public.locais (nome) values ('Capela (teste)');

insert into public.missas (inicio, local_id)
select x.inicio, l.id
from public.locais l,
     (values (now() + interval '26 hours 30 minutes'), (now() + interval '72 hours')) as x(inicio)
where l.nome = 'Capela (teste)';

-- 3) a Maria escalada nas duas, cada uma com um pedido de troca aberto
insert into public.escalacoes (missa_id, coroinha_id, funcao)
select m.id, '00000000-0000-0000-0000-00000000aaaa', 'cruciferário'
from public.missas m join public.locais l on l.id = m.local_id
where l.nome = 'Capela (teste)';

insert into public.trocas (escalacao_id)
select e.id from public.escalacoes e
where e.coroinha_id = '00000000-0000-0000-0000-00000000aaaa';
EOF

criar supabase/scripts/limpar_dados_teste.sql << 'EOF'
-- Apaga TODOS os dados de teste dos scripts desta pasta e dos testes manuais
-- do app: os locais "Matriz (teste)", "Capela (teste)" e "Capela (teste app)",
-- as missas deles, as escalações e trocas ligadas a eles, e a "Maria (teste)".
--
-- Não mexe em nada que não seja de teste. Pode ser rodado várias vezes.

delete from public.escalacoes
where coroinha_id = '00000000-0000-0000-0000-00000000aaaa'
   or missa_id in (
     select m.id from public.missas m
     join public.locais l on l.id = m.local_id
     where l.nome in ('Matriz (teste)', 'Capela (teste)', 'Capela (teste app)'));

delete from public.missas
where local_id in (
  select id from public.locais
  where nome in ('Matriz (teste)', 'Capela (teste)', 'Capela (teste app)'));

delete from public.locais
where nome in ('Matriz (teste)', 'Capela (teste)', 'Capela (teste app)');

delete from auth.users where id = '00000000-0000-0000-0000-00000000aaaa';
EOF

criar README.md << 'EOF'
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
EOF
echo

# README do app: só troca se ainda for o texto padrão do Flutter
if [ -f escala_app/README.md ] && grep -q "A new Flutter project" escala_app/README.md; then
  dizer "  trocar  escala_app/README.md (era o texto padrão do Flutter)"
  if [ $APLICAR -eq 1 ]; then
    cat > escala_app/README.md << 'EOF'
# escala_app

O app Flutter (web/PWA) da escala de coroinhas.

- Visão geral do projeto: [../README.md](../README.md)
- Documentação completa: [../docs/DOCUMENTACAO.md](../docs/DOCUMENTACAO.md)

```bash
flutter test
flutter run -d chrome --web-port=3000 --dart-define-from-file=env.json
```

A porta 3000 é a que está liberada no Google e no Supabase para o retorno do login.
EOF
  fi
else
  dizer "  - README do app já é seu, mantive"
fi
echo

# ---------- 4) .gitignore da raiz ----------
dizer "[3/4] .gitignore da raiz (chaves, dados pessoais e arquivos gerados)"
garantir_no_gitignore '**/env.json'
garantir_no_gitignore 'supabase/scripts/admin.sql'
garantir_no_gitignore '**/.dart_tool/'
garantir_no_gitignore '**/build/'
garantir_no_gitignore '**/.idea/'
garantir_no_gitignore '*.iml'
garantir_no_gitignore '.flutter-plugins-dependencies'
echo

# ---------- 5) avisos ----------
dizer "[4/4] Conferências"
if [ $EM_GIT -eq 1 ]; then
  for segredo in supabase/admin.sql supabase/scripts/admin.sql escala_app/env.json; do
    if git ls-files --error-unmatch "$segredo" >/dev/null 2>&1; then
      dizer "  ATENÇÃO: '$segredo' JÁ está no Git. Ele tem dados pessoais ou chaves."
      dizer "           Para tirar do controle de versão (o arquivo continua no seu disco):"
      dizer "             git rm --cached $segredo"
      dizer "           Mas o conteúdo antigo continua no HISTÓRICO do Git. Se o repositório for"
      dizer "           ficar público, me avise para combinarmos o que fazer."
    fi
  done
else
  dizer "  Este projeto ainda não é um repositório Git. Para começar:"
  dizer "    git init && git add . && git commit -m 'Primeiro commit'"
  dizer "  (rode 'git status' antes de commitar e confira que env.json e admin.sql NÃO aparecem)"
fi
echo
if [ $APLICAR -eq 1 ]; then
  echo "Pronto. Confira com:  git status   (ou olhe a árvore de pastas)."
  echo "Depois de conferir, faça um commit: 'Reorganiza a estrutura de pastas'."
else
  echo "Fim da simulação. Se estiver de acordo:  bash organizar_projeto.sh --aplicar"
fi
