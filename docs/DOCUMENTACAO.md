# Escala Coroinhas — Documentação do projeto

> **Documento vivo.** Atualize-o ao fim de cada etapa. Estado: 21 de novembro de 2026.
>
> **Nota de honestidade:** todo o código deste projeto foi escrito em conversa com o Claude. Tudo o que está marcado como "funcionando" foi **rodado e confirmado por você** (testes verdes, telas vistas no navegador). Em algumas conversas o Claude também validou o SQL num Postgres local simulado (com um `auth` de mentira), o que reduz erros mas **não substitui** a sua confirmação no Supabase. Dart e Flutter o Claude nunca roda: o resultado de `dart test` e `flutter test` é sempre o que você cola na conversa. O que não foi conferido está listado na seção 11.

---

## Sumário

1. [Resumo em uma página](#1-resumo-em-uma-página)
2. [Mapa do projeto](#2-mapa-do-projeto)
3. [Linha do tempo](#3-linha-do-tempo)
4. [Regras de negócio](#4-regras-de-negócio)
5. [Decisões importantes e por quê](#5-decisões-importantes-e-por-quê)
6. [Banco de dados (Supabase)](#6-banco-de-dados-supabase)
7. [Núcleo Dart (escala_core)](#7-núcleo-dart-escala_core)
8. [App Flutter (escala_app)](#8-app-flutter-escala_app)
9. [Login com Google](#9-login-com-google)
10. [Receitas: como rodar e como trabalhar](#10-receitas-como-rodar-e-como-trabalhar)
11. [Pendências e lacunas conhecidas](#11-pendências-e-lacunas-conhecidas)
12. [Próximos passos](#12-próximos-passos)
13. [Segurança e privacidade](#13-segurança-e-privacidade)
14. [Lições aprendidas](#14-lições-aprendidas)
15. [Glossário](#15-glossário)
16. [Apêndice: testes e arquivos](#16-apêndice-testes-e-arquivos)

---

## 1. Resumo em uma página

**O que é.** Um app para organizar a escala de coroinhas de uma paróquia com **duas igrejas**: consultar a escala, confirmar presença, pedir e aceitar trocas, e o coordenador escalar os coroinhas. É de uso real numa paróquia pequena e também um **projeto de aprendizado**.

**De onde veio.** Partimos da análise de um app existente ("Escala Coroinhas", da S4TI) apenas para entender o **fluxo de telas**. O nosso é independente: não copia código, imagens nem identidade visual, e **não usa o servidor** do app original.

**Como foi feito.** Com **TDD** (escrever o teste, vê-lo falhar, escrever o mínimo para passar, refatorar) e em **pair programming** com o Claude: você decide, o Claude escreve e questiona.

**Tecnologias.**

| Camada | Tecnologia |
|---|---|
| App | Flutter, publicado como app web instalável (PWA) |
| Banco, login e regras | Supabase (Postgres + Auth com Google), plano gratuito, projeto `escala-dev` |
| Regras testáveis sem banco | Dart puro (`escala_core`) |

**Onde estamos.**

| Pronto e validado por você | Falta |
|---|---|
| Banco completo: escalar, presença, trocas, convites, cadastro e gestão, permissões e leitura (RLS), **escala livre** (a própria pessoa se escala e sai); área do administrador no app com escala por missa, pendências em atraso e **gestão de pessoas** | Ajustes menores (seção 11) |
| Núcleo Dart com as regras e o tradutor de erros do banco | Publicar o app (endereço HTTPS) e fazer o piloto com a turma |
| Login Google funcionando (testado em navegador e no Flutter) | Teste do Family Link com um menor de verdade |
| App: login, convite, **Minha escala**, **confirmar presença**, **pedir e cancelar troca**, **trocas abertas e aceitar**, **área do administrador (entrada, convites, locais, missas com escala livre, escala por missa, pendências em atraso e pessoas)**, **Missas abertas** (entrar na escala) e **Sair da escala** | Notificações, iPhone e lojas (adiados) |

**Números.** 20 arquivos de migração SQL (19 numerados mais o 1b), 18 arquivos de teste SQL, **228 testes de Flutter** e 71 testes do núcleo Dart, todos confirmados por você em 21/11/2026.

**Se você só tem 5 minutos:** leia esta seção e as seções 11 e 12.

---

## 2. Mapa do projeto

### 2.1 Pastas

Reorganizado em 18/11/2026 (script `organizar_projeto.sh`). A pasta `escala/` é a raiz do repositório Git.

```
escala/                            (raiz do Git; fora de Downloads)
├── README.md                      visão geral e como começar
├── .gitignore                     chaves, dados pessoais e arquivos gerados
├── docs/
│   └── DOCUMENTACAO.md            este documento
├── escala_core/                 núcleo Dart puro
│   ├── lib/src/dominio.dart          modelos, constantes de tempo, exceções
│   ├── lib/src/escala_service.dart   regras de escala em memória
│   ├── lib/src/erros_do_banco.dart   tradutor: código do banco -> exceção
│   └── test/                         escala_service_test.dart, traducao_erros_test.dart
├── escala_app/                  app Flutter (web/PWA)
│   ├── lib/main.dart, config.dart, formatacao.dart, ordenacao.dart, mensagem_de_erro.dart
│   ├── lib/data/                     repositório (interface, Supabase), ItemEscala, TrocaDisponivel, Local, MissaCadastrada, Coroinha, Pessoa e EscaladoNaMissa
│   ├── lib/telas/                    raiz, convite_page, minha_escala_page, trocas_disponiveis_page,
│   │                                 admin_page, convites_page, locais_page, missas_page, nova_missa_page, escala_missa_page,
│   │                                 pessoas_page, missas_abertas_page
│   ├── test/                         testes e fakes/
│   └── env.json                      chaves locais (NÃO vai para o Git)
├── supabase/
│   ├── migrations/                20 migrações (19 numeradas + a 1b), na ordem do nome do arquivo
│   ├── testes/                    testes SQL 001 a 018
│   └── scripts/                   scripts avulsos, para colar no SQL Editor
│       ├── admin.exemplo.sql          modelo para criar o primeiro administrador
│       ├── admin.sql                  o seu (tem e-mail; FORA do Git)
│       ├── auditoria_seguranca.sql    consultas de segurança (só leitura)
│       ├── dados_teste_escala.sql     missas de teste (seção 10.4)
│       ├── dados_teste_trocas.sql     pedidos de troca de teste (seção 10.4b)
│       └── limpar_dados_teste.sql     apaga todos os dados de teste
└── ferramentas/
    └── teste_login_google.html    página local de teste do login
```

### 2.2 Como as camadas se falam

```
 Telas (Flutter)
      |  só conhecem a interface
      v
 EscalaRepository  (interface)  <---- FakeEscalaRepository (testes, sem internet)
      |
      v
 SupabaseEscalaRepository  ----chama---->  Funções SQL (rpc) + leitura com RLS
                                                  |
                                                  v
                                       Postgres: tabelas, restrições, gatilhos
```

O `escala_core` (Dart puro) guarda as **regras testáveis** e o **tradutor de erros**. O banco é a **autoridade final**: mesmo que um app adulterado tente burlar as regras, o banco recusa.

### 2.3 Exemplo de ponta a ponta: confirmar presença

1. A pessoa toca em **Confirmar presença** na tela *Minha escala*.
2. A tela chama `repositorio.confirmarPresenca(id)`.
3. O repositório chama a função do banco `confirmar_presenca` (identificando a pessoa **pelo login**, nunca por um parâmetro).
4. A função confere: a escalação existe? é do usuário logado? já estava confirmada? Então grava `confirmado` e calcula se foi com atraso (2h antes da missa).
5. Se algo falhar, o banco devolve um **código** (ex.: `NAO_AUTORIZADO`), o repositório o traduz numa exceção do domínio, e a tela mostra uma mensagem em português.
6. A tela recarrega a lista.

---

## 3. Linha do tempo

| Fase | O que aconteceu |
|---|---|
| **0. Análise do app original** | Leitura de um XAPK decompilado (Flutter, código ofuscado, cerca de 60 telas). Extraímos só os **nomes das telas** para entender o fluxo. Decisão: escopo mínimo, nada de copiar código/identidade, nada de usar o servidor deles. |
| **1. Planejamento** | Definimos papéis (coroinha e administrador), as quatro regras principais (conflito, presença, troca, convite), duas igrejas, cuidados com menores (LGPD) e a stack (Flutter + Supabase). |
| **2. Núcleo Dart com TDD** | Ciclos: escalar com conflito, presença e prazo, trocas (abrir, aceitar, cancelar), ids inexistentes, convites. Mais tarde você acrescentou testes (confirmar duas vezes, convite com e sem responsável). |
| **3. Banco no Supabase (online)** | Escolhemos o projeto online `escala-dev` (sem Docker). Criamos uma técnica de testes SQL que simula usuários logados. Migrações 1 a 17, todas escritas em conversa com o Claude; as 14 a 16 (cadastro, pendentes em atraso e gestão) foram validadas antes num Postgres local simulado e depois por você no Supabase. |
| **4. Login Google** | Configuração no Google Cloud e no Supabase, teste com uma página HTML local, pesquisa sobre contas de menores (Family Link). |
| **5. Distribuição** | Decisão: **app web instalável (PWA)**. Android instala pelo Chrome. iPhone e lojas ficam para depois. |
| **6. Tradutor de erros** | `traduzirErroDoBanco` no Dart, com teste de contrato que lê as migrações. |
| **7. App Flutter** | Fatia 1: esqueleto com login. Fatia 2: formulário de convite. Fatia 3: Minha escala e confirmar presença. Fatia 4a: pedir e cancelar troca. Fatia 4b: trocas abertas dos outros e aceitar. Fatia 5a: entrada da **Administração** e **gerar convite**. Fatia 5b: **locais** (listar e cadastrar). Fatia 5c: **missas** (listar). Fatia 5d: **criar missa** (local, data e hora). Fatia 5e: **editar e remover missa**. Fatia 5f: **administrar a escala por missa** (listar coroinhas disponíveis e escalados, adicionar com função livre e remover com confirmação). Fatia 5g: **refinar a escala da missa** (contador de participantes, cabeçalho com data/local em blocos e estado vazio informativo). Fatia 5h: **pendências em atraso** (modelo, repositório, fake, tela, menu administrativo e testes). Fatia 5i: **pessoas** (listar, ativar/desativar, tornar administrador ou coroinha); administradores também podem ser escalados. Fatia 5j: **escala livre** no banco (migration 18), no núcleo (códigos novos) e no app (chave "Escala livre" ao criar/editar a missa). Fatia 6a: **Missas abertas** e **Entrar na escala** (coroinha). Fatia 6b: **Sair da escala** (só para quem se escalou sozinho). |
| **8. Documentação** | Este documento (PDF e Markdown), atualizado ao fim de cada bloco de telas. |

---

## 4. Regras de negócio

| # | Regra | Garantida em |
|---|---|---|
| 1 | **Conflito de horário.** O mesmo coroinha não pode ter duas escalações com início a **menos de 1h** de diferença. Exatamente 1h é permitido. Vale entre as duas igrejas (sem tempo de deslocamento). | Banco (restrição de exclusão) e Dart |
| 2 | **Mesma missa duas vezes** é bloqueada (`JA_ESCALADO_NA_MISSA`). Essa verificação vem **antes** do conflito de horário. | Função `escalar` e Dart |
| 3 | **Escalar** só o administrador, em missa existente, e coroinha **existente e ativo**. | Função `escalar` |
| 4 | **Presença.** Nasce *pendente*. O prazo é **2h antes da missa**. Confirmar depois do prazo é **permitido** e fica marcado como *com atraso*. Só o titular confirma. Confirmar de novo **não altera** nada. | `confirmar_presenca`, Dart |
| 5 | **Pendentes em atraso.** Escalação pendente a partir de 2h antes (inclusive o instante exato) até o início da missa. Só o administrador vê a lista. | `pendentes_em_atraso`, Dart |
| 6 | **Troca.** O titular abre (só de missa que ainda não começou). **Uma troca aberta** por escalação. Qualquer membro ativo pode aceitar. Aceitar transfere a escalação **e já confirma** a presença. O substituto não pode ser o próprio titular, nem já estar na mesma missa, nem ter conflito de horário. O **primeiro aceite vence**. | Funções de troca e restrições |
| 7 | **Cancelar troca.** Pelo titular **atual** ou por um administrador. Troca aceita ou cancelada não volta a abrir. | `cancelar_troca` |
| 8 | **Missa muda de horário.** O período das escalações acompanha. As **presenças já confirmadas continuam confirmadas**. Se o novo horário conflitar com outra escalação de alguém, a mudança é bloqueada. | Gatilho e `editar_missa` |
| 9 | **Convite.** Só o administrador gera. Código de **8 caracteres** (sem 0, O, 1, I). Validade de **7 dias**, **uso único**, guardado só como *hash*. Exige o responsável por padrão (menores). Um convite de adulto pode dispensá-lo. Um nome vazio **não gasta** o convite. | `gerar_convite`, `resgatar_convite` |
| 10 | **Acesso.** Login pelo Google **mais** um perfil (obtido pelo convite). Sem perfil ativo, a pessoa não vê nada. Todos os membros leem a escala; **escrever só pelas funções**. | RLS e funções |
| 11 | **Gestão.** Desescalar só missa futura. Remover missa só se não houver escalados. Desativar alguém só se não tiver missas futuras. O sistema **nunca fica sem administrador ativo**. | Funções de gestão |
| 12 | **Dados de menores.** Guarda-se o mínimo: nome do responsável e a data do consentimento. Sem data de nascimento, telefone ou endereço. | Tabela `dados_responsavel` |
| 13 | **Escala livre.** O administrador marca a missa como livre (ao criar ou editar). Então qualquer membro ativo pode se escalar sozinho: **sem limite de vagas**, função fixa **"A definir"**, entra **já confirmado**. Só vale até o início da missa; vale a mesma regra de conflito de horário e de "mesma missa duas vezes". | `auto_escalar` |
| 14 | **Sair da escala.** Quem se escalou sozinho (`auto_escalada`) pode sair até o início da missa, só da própria escalação. Quem foi escalado pelo administrador sai só por **pedir troca**. Desligar a escala livre depois **não tira** quem já entrou. | `auto_desescalar` |

---

## 5. Decisões importantes e por quê

1. **Flutter + Supabase.** Os dados são relacionais (missa, escalação, coroinha, troca), e o Postgres com RLS resolve bem "cada um vê só o que é seu".
2. **O banco é a autoridade; o Dart é a especificação.** Um celular adulterado não pode burlar regras, e dois aceites simultâneos precisam de garantia do banco. O Dart continua útil como especificação executável e para validar rápido na interface.
3. **Quem chama vem do login (`auth.uid()`), nunca de parâmetro.** Senão alguém poderia passar o id de outra pessoa.
4. **Funções `security definer` com `search_path` vazio.** A RLS sem políticas de escrita nega tudo; as funções são o único caminho e conferem a permissão por dentro. O `search_path` vazio impede que alguém plante uma função falsa com o mesmo nome.
5. **Permissão sempre antes do estado.** Quem não pode agir não descobre se a coisa existe nem em que estado está.
6. **Restrições no banco para o que não pode existir.** O conflito de horário é uma restrição de exclusão sobre um intervalo `[início, início + 1h)`. "Exatamente 1h" não conflita porque o intervalo é meio aberto. "Duas trocas abertas" é impossível por um índice parcial.
7. **A função confere antes e a restrição garante depois.** A função dá a mensagem amigável; a restrição pega o caso raro de pedidos simultâneos.
8. **Projeto online em vez de Docker local.** Mais simples para começar. O custo: os testes SQL rodam manualmente no SQL Editor.
9. **Testes SQL "silenciosos no sucesso".** Verde é `Success. No rows returned`; vermelho é um erro `FALHOU [..]`. Cada teste limpa os próprios dados e, se falhar, o bloco inteiro é desfeito sozinho.
10. **Convite + login Google.** O Google prova **quem** a pessoa é; o convite prova que ela **pode** entrar. Muitos coroinhas já têm conta Google.
11. **Responsável obrigatório por padrão (adulto dispensa).** O erro cai do lado que protege. O banco não sabe a idade de ninguém, então é controle de processo do administrador.
12. **Só o hash do convite é guardado.** Quem lê o banco não consegue usar um convite pendente.
13. **Plano gratuito do Supabase.** O projeto pausa após cerca de uma semana sem uso e não tem backups diários. Aceitável para aprender; reavaliar quando a paróquia depender do app.
14. **Dois projetos Supabase.** `escala-dev` agora; um `escala-prod` depois, para os dados reais. **Os testes nunca rodam no de produção.**
15. **Distribuição por PWA.** Sem lojas, sem taxas. A instalação direta de APK no Android passou a ter verificação de desenvolvedor no Brasil, e as lojas custam e exigem um período de testes.
16. **Telas só conhecem a interface `EscalaRepository`.** Permite testar as telas com uma versão falsa, sem internet.
17. **Poucas dependências no app.** Só `supabase_flutter`, sem pacote de estado nem de datas, para você enxergar o que acontece.
18. **A hora atual entra por parâmetro** (`agora`) no Dart, nas funções puras do banco e na tela, para os testes controlarem o prazo.
19. **Ações que afetam outras pessoas pedem confirmação** (pedir troca, aceitar troca): são visíveis ou comprometem alguém, e são fáceis de tocar sem querer. **Cancelar o próprio pedido não pede**, porque se desfaz sozinho (dá para pedir de novo).
20. **A mesma exceção do domínio, mensagens diferentes conforme quem fala.** O tradutor escreve em geral ("Esse coroinha já está escalado..."); a tela de aceitar troca troca por primeira pessoa ("Você já está escalado..."). O tradutor não muda.
21. **Filtro que não dá para conferir no banco vira função pura com teste.** As trocas abertas chegam do banco só filtradas por status; tirar as próprias e as missas já começadas é feito em Dart (`TrocaDisponivel.listaDeJson`), onde há teste.
22. **Uma só função executa as ações da tela** (`_executar`): bloqueia os botões, mostra a mensagem de erro e recarrega **só se deu certo**, fora do `try`. Evita o erro "falha ao recarregar" aparecer como "falha da ação".
23. **A área de administração é um caminho, não uma proteção.** O app só mostra o botão **Administração** a quem o banco diz ser administrador (`eh_admin()`, que vira o estado `EstadoAcesso.administrador`). Quem protege de verdade é cada função do banco, que confere o papel de quem chama; um app adulterado que abra a tela recebe `NAO_AUTORIZADO`.
24. **A tela não adivinha o que o banco tem.** Ao cadastrar um local, a tela não o insere na lista por conta própria: chama o banco e **recarrega** a lista. Assim ela mostra o que o banco realmente guardou (inclusive o que outra pessoa cadastrou ao mesmo tempo).
25. **Data e hora entram por parâmetro na tela de nova missa.** O calendário e o relógio do sistema são difíceis de simular em teste; a tela recebe a função que pergunta (`escolherDataHora`), como o `copiar` da tela de Convites. O padrão usa `showDatePicker` e `showTimePicker`. Criar uma missa **não pede confirmação** (não compromete ninguém; a decisão 19 vale para ações que afetam outras pessoas).
26. **A hora é a do aparelho; o banco guarda em UTC.** O app envia `inicio.toUtc()` e mostra `toLocal()`. Conferido no navegador: a hora escolhida volta igual na lista. No Table Editor do Supabase a mesma hora aparece em UTC (18:00 em Recife aparece como 21:00).

27. **Escala livre sem limite de vagas, função "A definir", entrada já confirmada, saída até o início da missa.** Respostas dadas por você antes de implementar. Menos regras no banco e na tela; o administrador pode ajustar a função depois removendo e escalando de novo.
28. **O app lembra quem se escalou sozinho (`auto_escalada`).** É a marca que decide se a pessoa vê **Sair da escala** (entrou sozinha) ou **Pedir troca** (foi escalada pelo administrador). A regra é conferida de novo no banco (`SAIDA_NAO_PERMITIDA`).
29. **Missas abertas é uma lista filtrada no app.** `missasAbertas()` traz as missas livres futuras e tira aquelas em que a própria pessoa já está; o banco continua sendo a autoridade (`ESCALA_NAO_LIVRE`, `JA_ESCALADO_NA_MISSA`).
30. **Quem decide o "A definir" é o banco.** O app manda a função como a pessoa digitou (ou vazia) e o `escalar` grava "A definir" quando sobra vazio. Uma regra em um lugar só; a tela só avisa o que acontece ("Se ficar em branco, a função será \"A definir\".").

---

## 6. Banco de dados (Supabase)

### 6.1 Tabelas

| Tabela | Para quê | Colunas principais |
|---|---|---|
| `locais` | As igrejas | `id`, `nome` (único) |
| `perfis` | Quem tem acesso | `id` (igual ao do login), `nome`, `papel` (admin ou coroinha), `ativo` |
| `dados_responsavel` | Consentimento dos menores | `perfil_id`, `responsavel_nome`, `consentimento_em` |
| `missas` | As missas | `id`, `inicio`, `local_id`, `escala_livre` (padrão falso) |
| `escalacoes` | Quem serve em qual missa | `id`, `missa_id`, `coroinha_id`, `funcao`, `status` (pendente ou confirmado), `confirmado_com_atraso`, `periodo`, `auto_escalada` (padrão falso) |
| `trocas` | Pedidos de troca | `id`, `escalacao_id`, `status` (aberta, aceita, cancelada), `substituto_id`, `criada_em`, `resolvida_em` |
| `convites` | Convites de acesso | `id`, `codigo_hash`, `criado_por`, `criado_em`, `expira_em`, `usado_em`, `usado_por`, `exige_responsavel` |

### 6.2 Garantias do próprio banco

- **Restrição de exclusão** `escalacoes_sem_conflito_de_horario`: mesmo `coroinha_id` com `periodo` sobreposto é recusado. O `periodo` é `[início da missa, início + 1h)`, calculado por gatilho.
- **Índice parcial** `trocas_uma_aberta_por_escalacao`: só uma troca com status *aberta* por escalação.
- **Coerência em `trocas`**: só uma troca *aceita* tem substituto, e toda aceita tem.
- **Gatilhos**: o `periodo` acompanha a missa quando o horário dela muda.
- **Chaves estrangeiras** com remoção em cascata onde faz sentido (trocas somem junto com a escalação).

### 6.3 Migrações (rodar uma vez, em ordem)

A coluna "Nº" é o número que aparece no cabeçalho de cada arquivo.

| Nº | Arquivo | O que faz | Teste |
|---|---|---|---|
| 1 | `20261114120000_esqueleto.sql` | Tabelas locais, perfis, missas, escalações; gatilho do `periodo`; RLS ligada | 001 |
| 1b | `20261114120100_conflito_horario.sql` | Extensão `btree_gist` e a restrição de conflito de horário | 001 |
| 2 | `20261114130000_escalar_esqueleto.sql` | Função `escalar` sem regras (fase vermelha) | 002 |
| 3 | `20261114130100_escalar_regras.sql` | Regras da `escalar`: mesma missa e conflito | 002 |
| 4 | `20261114140000_periodo_acompanha_missa.sql` | `periodo_missa()` e gatilho quando a missa muda de horário | 003, 004 |
| 5 | `20261114150000_escalar_permissao.sql` | `escalar` só para admin, `security definer`, `revoke`/`grant` | 005 |
| 6 | `20261114160000_confirmar_presenca.sql` | `passou_do_prazo()` e `confirmar_presenca` | 006 |
| 7 | `20261114170000_abrir_troca.sql` | Tabela `trocas`, índice parcial e `abrir_troca` | 007 |
| 8 | `20261114180000_cancelar_troca.sql` | `cancelar_troca` (titular ou admin) | 008 |
| 9 | `20261114190000_aceitar_troca.sql` | `aceitar_troca` | 009 |
| 10 | `20261114200000_dados_responsavel.sql` | Tabela `dados_responsavel` | 010 |
| 11 | `20261114200100_politicas_leitura.sql` | `eh_membro()`, `eh_admin()` e as políticas de leitura | 010 |
| 12 | `20261114210000_convite.sql` | `pgcrypto`, tabela `convites`, `hash_convite`, `gerar_convite`, `resgatar_convite` | 011 |
| 13 | `20261114220000_convite_adulto.sql` | Coluna `exige_responsavel` e as funções ajustadas | 011 (v2), 012 |
| 14 | `20261114230000_cadastro_missas.sql` | `criar_local`, `criar_missa`, `editar_missa` | 013 |
| 15 | `20261115000000_pendentes_em_atraso.sql` | `pendentes_em_atraso` | 014 |
| 16 | `20261115010000_gestao_escala.sql` | `desescalar`, `definir_ativo`, `definir_papel`, `remover_missa`, `exigir_outro_admin` | 015 |
| 17 | `20261115020000_escalar_validacoes.sql` | `escalar` valida missa e coroinha (existente e ativo) | 016 |
| 18 | `20261120210000_escala_livre.sql` | Colunas `escala_livre` e `auto_escalada`; `criar_missa` e `editar_missa` com o parâmetro novo (assinatura trocada: remover e recriar); `auto_escalar` e `auto_desescalar` | 017, 013 (C6 atualizado) |
| 19 | `20261121140000_funcao_padrao.sql` | `escalar` limpa a função (tira espaços das pontas) e grava "A definir" quando vem vazia ou nula; mesma assinatura (`create or replace`) | 018 |

**Importante:** as migrações **1 a 19 e a 1b já foram aplicadas** no `escala-dev`. Não rode de novo. Para montar um banco novo (ex.: `escala-prod`), rode **todos os arquivos da pasta `migrations/` em ordem** (a 1b é o `20261114120100_conflito_horario.sql`, logo depois da 1).

### 6.4 Funções que o app pode chamar

Todas usam o login (`auth.uid()`). Quem não está logado não executa nenhuma.

| Função | Quem pode | O que faz |
|---|---|---|
| `escalar(missa, coroinha, funcao)` | admin | Escala alguém numa missa; função vazia ou nula vira "A definir" |
| `desescalar(escalacao)` | admin | Retira a escalação (só missa futura) |
| `confirmar_presenca(escalacao)` | titular | Confirma a presença |
| `abrir_troca(escalacao)` | titular | Abre um pedido de troca |
| `cancelar_troca(troca)` | titular atual ou admin | Cancela uma troca aberta |
| `aceitar_troca(troca)` | membro ativo | Assume a escalação de outra pessoa |
| `gerar_convite(exige_responsavel)` | admin | Devolve o código (uma única vez) |
| `resgatar_convite(codigo, nome, responsavel)` | logado sem perfil | Cria o perfil |
| `criar_local(nome)` | admin | Cadastra um local |
| `criar_missa(inicio, local, escala_livre = false)`, `editar_missa(id, inicio, local, escala_livre = null)` | admin | Cadastro; em `editar_missa`, nulo mantém o valor atual |
| `auto_escalar(missa)` | membro ativo | A própria pessoa se escala numa missa livre (função "A definir", confirmado) |
| `auto_desescalar(missa)` | titular | A própria pessoa sai, só de uma escalação que ela mesma fez e antes do início |
| `remover_missa(id)` | admin | Só se não houver escalados |
| `definir_ativo(perfil, ativo)`, `definir_papel(perfil, papel)` | admin | Gestão de pessoas |

**Contrato da gestão de pessoas (migration 16):** `definir_ativo(p_perfil_id, p_ativo)` e `definir_papel(p_perfil_id, p_papel)` retornam o registro atualizado de `perfis`. Ambas exigem administrador. `p_ativo` não pode ser nulo; `p_papel` aceita somente `admin` ou `coroinha`. Desativar um perfil com escalações em missas futuras é bloqueado (`TEM_ESCALACOES_FUTURAS`); antes é necessário desescalar. Desativar ou rebaixar um administrador ativo é bloqueado se ele for o último (`ULTIMO_ADMIN`). O bloqueio é protegido por trava dos administradores ativos. A migration não cria uma RPC de listagem de perfis: a tela **Pessoas** lê a tabela `perfis` diretamente, pela política de leitura dos membros.
| `pendentes_em_atraso(agora)` | admin | Lista para o coordenador cobrar |
| `eh_membro()`, `eh_admin()` | logado | Usadas também pelas políticas |

Funções internas (ninguém de fora chama): `hash_convite`, `exigir_outro_admin`, os gatilhos, e as puras `passou_do_prazo` e `periodo_missa`.

### 6.5 Segurança no banco

- **RLS ligada em todas as tabelas.** Sem política, a RLS nega tudo.
- **Políticas só de leitura.** Membros (perfil ativo) leem `locais`, `perfis`, `missas`, `escalacoes` e `trocas`. `dados_responsavel` só o próprio e o admin. `convites` só o admin (e só o hash).
- **Nenhuma política de escrita.** Escrever é só pelas funções.
- **Direitos de execução:** cada função tem `revoke ... from public, anon` e `grant ... to authenticated`.
- **Auditoria:** o arquivo `supabase/scripts/auditoria_seguranca.sql` tem 6 consultas só de leitura (rodar **uma por vez**). Esperado: A1 a A3 e A5 sem nenhuma linha (tabela sem RLS, política que não seja de leitura, política aberta a `anon`, função `security definer` sem `search_path`); A4 só com 4 auxiliares sem efeito (`definir_periodo_escalacao`, `periodo_missa`, `atualizar_periodo_escalacoes`, `passou_do_prazo`); A6 sem `exigir_outro_admin` nem `hash_convite`. Rodar depois de cada migração.
- **Primeiro administrador:** criado à mão, uma vez, com o `supabase/scripts/admin.sql` (insere o perfil de uma conta Google que já entrou no app). Depois disso, `definir_papel` cuida dos outros.

### 6.6 Códigos de erro

O banco devolve o **texto** do erro igual ao código. O Dart traduz para exceções (`traduzirErroDoBanco`).

| Grupo | Códigos |
|---|---|
| Geral | `NAO_AUTORIZADO` |
| Escala | `CONFLITO_DE_HORARIO`, `JA_ESCALADO_NA_MISSA`, `MISSA_JA_COMECOU`, `MISSA_INEXISTENTE`, `COROINHA_INEXISTENTE`, `COROINHA_INATIVO`, `ESCALACAO_NAO_ENCONTRADA`, `ESCALA_NAO_LIVRE`, `SAIDA_NAO_PERMITIDA` |
| Trocas | `TROCA_JA_ABERTA`, `TROCA_JA_RESOLVIDA`, `SUBSTITUTO_INVALIDO`, `TROCA_NAO_ENCONTRADA` |
| Convites | `CONVITE_INVALIDO`, `CONVITE_USADO`, `CONVITE_EXPIRADO`, `JA_TEM_PERFIL`, `NOME_INVALIDO`, `RESPONSAVEL_OBRIGATORIO` |
| Cadastro | `LOCAL_DUPLICADO`, `LOCAL_INEXISTENTE`, `HORARIO_INVALIDO` |
| Gestão | `VALOR_INVALIDO`, `PERFIL_INEXISTENTE`, `PAPEL_INVALIDO`, `TEM_ESCALACOES_FUTURAS`, `MISSA_COM_ESCALADOS`, `ULTIMO_ADMIN` |

Qualquer outro texto (rede, erro técnico do Postgres) vira `ErroDesconhecido`, e **nunca** é mostrado cru à pessoa.

### 6.7 Testes SQL

**Como funcionam.** Cada arquivo em `supabase/testes/` é um bloco `do $$ ... $$` que você cola no **SQL Editor** e executa.

- **Sucesso:** `Success. No rows returned`. Nenhum dado de teste fica no banco.
- **Falha:** erro vermelho começando com `FALHOU [rótulo]: ...`.
- **Qualquer outro erro** não é do teste (cole a mensagem na conversa).

**Técnica para "entrar" como alguém:**

```sql
perform set_config('request.jwt.claims',
  json_build_object('sub', <uuid>, 'role', 'authenticated')::text, true);
set local role authenticated;
-- ... chamar a função ...
reset role;
```

Os testes 013, 015 e 016 usam um ajudante temporário, `pg_temp.tentar(sql, uuid)`, que faz isso e devolve a mensagem de erro (ou nulo).

**Ordem de trabalho (TDD no banco):**

1. Rodar o **teste** e ver o **vermelho**.
2. Rodar a **migração**.
3. Rodar o teste de novo: **verde**.
4. Rodar **todos os testes anteriores** (regressão).

**Versões que mudaram:** o `002` e o `011` têm a **versão 2** (usar sempre a mais recente).

**Tabela de testes:** veja o Apêndice (seção 16).

---

## 7. Núcleo Dart (escala_core)

**O que é:** um pacote Dart **puro** (sem Flutter, sem banco), com as regras em memória. Serve de **especificação executável** das regras do núcleo da escala.

| Arquivo | Conteúdo |
|---|---|
| `lib/src/dominio.dart` | Constantes `duracaoMissa` (1h) e `prazoConfirmacao` (2h); modelos `Coroinha`, `Missa`, `Escalacao`, `Troca`, `Convite`; a exceção-base `RegraDeNegocio` e as exceções do núcleo |
| `lib/src/escala_service.dart` | `EscalaService`: `escalar`, `confirmar`, `pendentesEmAtraso`, `abrirTroca`, `aceitarTroca`, `cancelarTroca`, `cancelarTrocaComoAdmin`, `gerarConvite` |
| `lib/src/erros_do_banco.dart` | As 20 exceções de códigos do banco (incluindo `EscalaNaoLivre` e `SaidaNaoPermitida`), `ErroDesconhecido` e a função `traduzirErroDoBanco` |
| `test/escala_service_test.dart` | Testes das regras do núcleo (a numeração vai de 1 a 27b, com extras) |
| `test/traducao_erros_test.dart` | Um teste por código, de robustez e **de contrato** |

**Teste de contrato.** Lê as migrações em `../supabase/migrations`, extrai todo `raise exception 'CODIGO'` e confere que cada código tem tradução. Se uma migração futura criar um código novo, ele falha e lembra de atualizar o Dart. Se a pasta não existir ao lado do pacote, o teste é **pulado** com um aviso.

**Divergências conhecidas entre o Dart e o banco.** O Dart **não** tem: resgate de convite, cadastro de missas, gestão de pessoas, validação de coroinha ativo, permissão por login. Decisão: **não duplicar a administração no Dart**; ele fica como especificação do núcleo da escala e do tradutor de erros.

**Rodar:** `cd escala_core && dart test` (71 testes aprovados em 21/11/2026).

---

## 8. App Flutter (escala_app)

### 8.1 Arquitetura

- **Telas** só conhecem a interface `EscalaRepository`.
- **`SupabaseEscalaRepository`** é o único arquivo (junto com o `main.dart`) que conhece o pacote `supabase_flutter`.
- **`FakeEscalaRepository`** (nos testes) permite testar as telas sem internet.
- **Configuração por `--dart-define-from-file=env.json`**: nenhuma chave escrita no código.

### 8.2 Arquivos

| Arquivo | O que faz |
|---|---|
| `lib/main.dart` | Inicializa o Supabase e abre a `Raiz`; mostra aviso se faltar a configuração |
| `lib/config.dart` | Lê `SUPABASE_URL` e `SUPABASE_KEY` |
| `lib/formatacao.dart` | `formatarDataMissa`: "dom 22/11 às 18:00" |
| `lib/ordenacao.dart` | `compararNomes`: ordem alfabética sem diferenciar maiúsculas nem acentos ("Érica" entre "Davi" e "Fábio"); usada por todos os modelos que ordenam por nome |
| `lib/mensagem_de_erro.dart` | `mensagemDoErro(erro)` e `mensagemGenerica`: a mensagem do erro de regra, ou "Algo deu errado. Tente de novo." para qualquer outro erro; usada por todas as telas |
| `lib/data/escala_repository.dart` | A interface (acesso, convite, escala pessoal, confirmar, abrir/cancelar/aceitar troca e administração: gerar convite, locais, missas, escala por missa e pendências em atraso) e o `EstadoAcesso` (semLogin, semPerfil, membro, administrador) |
| `lib/data/supabase_escala_repository.dart` | A versão real. `missasAbertas()` tira as missas em que a pessoa já está; `coroinhas()` lista todos os perfis ativos (administradores também) |
| `lib/data/item_escala.dart` | Uma linha da escala (com o id da missa, o id da troca aberta e a marca `autoEscalada`); lê o JSON (`missa_id` e `auto_escalada` vêm da escalação, não da missa embutida); ordena por horário |
| `lib/data/troca_disponivel.dart` | Um pedido de troca de outra pessoa; tira os próprios e as missas já começadas; ordena |
| `lib/data/local.dart` | Um local (igreja ou capela); lê o JSON; ordena por nome, sem diferenciar maiúsculas nem acentos |
| `lib/data/missa_cadastrada.dart` | Uma missa como o administrador a vê (horário, local e `escalaLivre`); lê o JSON; ordena por horário. Chama-se `MissaCadastrada` porque `Missa` já existe no `escala_core` |
| `lib/data/pessoa_escalavel.dart` | `PessoaEscalavel`: quem pode ser escalado na administração da escala por missa (coroinha ou administrador); antigo `Coroinha`, renomeado em 21/11 (com isso o import do núcleo não precisa mais de `hide`) |
| `lib/data/pessoa.dart` | Uma pessoa na tela de gestão (nome, papel, ativo); lê o JSON; ordena por nome (sem diferenciar maiúsculas nem acentos) |
| `lib/data/escalado_na_missa.dart` | Modelo de uma escalação da missa: id da escalação, id e nome do coroinha e função; converte JSON e ordena pelo nome |
| `lib/data/pendencia_em_atraso.dart` | Modelo de uma escalação pendente dentro da janela de atraso; converte JSON, ajusta o horário para o fuso local e ordena por missa e nome |
| `lib/telas/raiz.dart` | Decide: login, convite ou Minha escala (como membro ou como administrador); se a verificação do acesso falhar, mostra o erro com **Tentar de novo** (`verificarAcessoDeNovo` do repositório) |
| `lib/telas/convite_page.dart` | Formulário de convite (código, nome, responsável) |
| `lib/telas/minha_escala_page.dart` | Próximas missas, prazo, confirmar, pedir e cancelar troca, **Sair da escala** (só em missa que a própria pessoa escolheu), botão **Missas abertas** e os botões **Trocas abertas** e **Administração** (só para administradores) |
| `lib/telas/missas_abertas_page.dart` | (Coroinha) Missas livres futuras em que a pessoa ainda não está, com **Entrar na escala** |
| `lib/telas/trocas_disponiveis_page.dart` | Pedidos de troca dos outros, com **Aceitar** |
| `lib/telas/admin_page.dart` | Menu da área de administração (Convites, Locais, Missas, Pendências em atraso e Pessoas) |
| `lib/telas/pessoas_page.dart` | (Admin) Lista as pessoas e permite ativar/desativar e tornar administrador ou coroinha, com confirmação nas ações que pesam |
| `lib/telas/convites_page.dart` | (Admin) Gera o convite: "menor de idade" marcado por padrão, código mostrado uma vez, botão de copiar |
| `lib/telas/locais_page.dart` | (Admin) Lista os locais e cadastra um novo; recarrega a lista depois de criar |
| `lib/telas/missas_page.dart` | (Admin) As próximas missas (horário e local), botão **Adicionar missa**, menu **Editar / Remover** e toque na linha para abrir a administração da escala daquela missa |
| `lib/telas/escala_missa_page.dart` | (Admin) Mostra os coroinhas escalados e suas funções; permite adicionar uma pessoa ativa (coroinha **ou administrador**) ainda não escalada, com função em texto livre, e remover uma escalação com confirmação; recarrega com `ignore()` (lição 14) |
| `lib/telas/pendencias_em_atraso_page.dart` | (Admin) Lista as escalações ainda pendentes a partir de duas horas antes da missa e antes do início; tem estados de carregamento, vazio e erro, botão de atualizar e gesto de atualização |
| `lib/telas/nova_missa_page.dart` | (Admin) Cadastra uma missa: local (lista de locais), data e hora (seletores do sistema, por parâmetro, abertos no horário atual ao editar) a chave **Escala livre** e **Salvar missa**; fecha devolvendo `true`. Com uma missa recebida por parâmetro vira **Editar missa** (local e horário atuais já escolhidos, botão **Salvar alterações**) |

### 8.3 O que as telas fazem hoje

- **Login:** botão **Entrar com Google**. O método `entrarComGoogle()` envia `queryParams: {'prompt': 'select_account'}` ao fluxo OAuth, solicitando ao Google a tela de escolha de conta.
- **Convite:** quem entrou mas não tem perfil digita código, nome e (se menor) o responsável. Erros aparecem em português. Há **Usar outra conta**.
- **Minha escala:** próximas missas com data, local, função e situação. Pendente tem **Confirmar presença** e o prazo; depois do prazo o texto avisa que ainda dá para confirmar. **Pedir troca** (com aviso de que todos poderão ver) e, com a troca aberta, a etiqueta **Troca aberta** e o botão **Cancelar pedido de troca**. **Tentar de novo** se a carga falhar. Quando foi a própria pessoa que se escalou, o cartão mostra **Você se escalou** e **Sair da escala** (com confirmação), no lugar de **Pedir troca**. Botão flutuante **Missas abertas**. Botões **Trocas abertas**, **Administração** (só aparece para administradores) e **Sair**.
- **Trocas abertas:** pedidos de troca de outras pessoas (data, local, função e quem pediu). **Aceitar** pede confirmação e avisa que a presença já fica confirmada. Os erros aparecem em primeira pessoa ("Você já está escalado em uma missa com horário próximo."). Se a troca mudou enquanto a pessoa olhava, a lista é atualizada. Ao voltar, a escala é recarregada.
- **Missas abertas:** lista as missas livres futuras em que a pessoa ainda não está (data, local). **Entrar na escala** escala a pessoa na hora ("Você entrou na escala."). Se a missa mudou enquanto a pessoa olhava (já não é livre, já começou, já está nela), a mensagem aparece e a lista é recarregada. Vazio: "Nenhuma missa aberta no momento."
- **Pessoas:** lista com nome e papel; menu para ativar/desativar e para tornar administrador ou coroinha. Desativar e mudar o papel pedem confirmação. Erros do banco (último administrador, escalações futuras) aparecem traduzidos.
- **Administração:** menu com **Convites**, **Locais**, **Missas**, **Pendências em atraso** e **Pessoas**. Só administradores veem o botão; o banco confere o papel em cada ação.
- **Pendências em atraso:** consulta `pendentes_em_atraso` pelo `EscalaRepository`, sem enviar horário do aparelho: a RPC usa `now()` do banco. Mostra nome, função e horário da missa; contempla carregamento, lista vazia, erro com nova tentativa, atualização pelo botão e gesto de puxar para atualizar. A janela é inclusiva no limite de duas horas antes e termina imediatamente antes do início da missa. A autorização é conferida no banco por `eh_admin()`; a tela não substitui a proteção da RPC.
- **Convites:** a opção "Menor de idade (exige o nome do responsável)" vem **marcada**; desmarcar gera um convite de adulto. O código aparece uma única vez (vale 7 dias) com o botão **Copiar código**.
- **Locais:** lista em ordem alfabética, campo **Nome do local** e botão **Adicionar local**. Nome em branco é recusado na tela; nome repetido mostra "Já existe um local com esse nome." e mantém o que foi digitado.
- **Missas:** as próximas missas (a partir de agora), em ordem de horário, com o local. O botão **Adicionar missa** abre a tela **Nova missa**: escolher o **local**, a **data e hora** e **Salvar missa**. Sem local escolhido ou sem data, a tela avisa; sem nenhum local cadastrado, pede para cadastrar um antes. Ao salvar, volta para a lista, que se recarrega. A chave **Escala livre** ("Os coroinhas podem se escalar sozinhos nesta missa.") fica na criação e na edição; na lista, a missa livre mostra "Local · Escala livre". Cada missa tem um menu **⋮** com **Editar** e **Remover**. **Editar** reabre a mesma tela com o local e o horário atuais; mover o horário é permitido mesmo com coroinhas escalados, e só o conflito de horário bloqueia (mensagem do banco). **Remover** pede confirmação; se a missa tiver coroinhas escalados, o banco impede a remoção e a tela mostra a mensagem traduzida. Se só o recarregamento falhar depois de remover, a tela mostra a falha de carga e não diz que a remoção falhou.
- **Escala da missa:** tocar na linha de uma missa abre `EscalaMissaPage`. A tela mostra data, horário e local, lista os escalados com nome e função e permite atualizar a lista. O cabeçalho da lista mostra a quantidade de participantes (com singular/plural); o cartão da missa separa visualmente data/horário e local. Quando não há ninguém escalado, aparece um estado vazio explicativo. A lista de quem pode ser escalado inclui também os administradores. **Adicionar coroinha** consulta os coroinhas e as escalações atuais, exclui da seleção quem já está naquela missa e abre um formulário com seleção de pessoa e campo de função livre. A função é obrigatória e tem espaços das pontas removidos. Ao salvar, chama `escalar` e recarrega a lista. A remoção usa o id da escalação, pede confirmação e chama `desescalar`; em caso de sucesso, a lista é recarregada. Os erros de regra do banco são apresentados na tela. A proteção contra repetição na mesma missa, conflito de horário, coroinha inativo e missa já iniciada continua sendo responsabilidade das funções do banco.
- **Validação manual das fatias 5f e 5g:** você confirmou que a navegação da lista de missas para a escala abre corretamente; o formulário carrega e permite selecionar coroinha e função; uma escalação de teste foi gravada e apareceu com nome/função; ao removê-la e confirmar, desapareceu da lista. Depois do refinamento visual, `flutter analyze` terminou sem problemas. As operações de adicionar e remover já haviam sido conferidas manualmente; a última alteração foi visual e o contador deriva da lista carregada. O teste unitário de `EscaladoNaMissa` também passou. Não registrar como executado um `flutter test` completo desta fatia, pois isso não foi confirmado nesta etapa.

### 8.4 Testes do app (228)

| Arquivo | Rótulos | O que cobre |
|---|---|---|
| `raiz_test.dart` | R1 a R14 | Carregando, login, convite, escala, erro, troca de tela, sair, botão Administração (só administrador), **Tentar de novo** depois de uma falha (R12 a R14) |
| `convite_page_test.dart` | V1 a V9 | Campos, envio, validação, erro de regra, progresso, outra conta |
| `item_escala_test.dart` | M1 a M10 | Leitura do JSON, status, troca aberta (e o id dela), ordenação, prazo, id da missa (M9) e marca de auto-escalada (M10) |
| `troca_disponivel_test.dart` | TD1 a TD5 | Leitura, sem os próprios pedidos, sem missas começadas, ordenação |
| `formatacao_test.dart` | F1 a F3 | Formato da data |
| `minha_escala_page_test.dart` | P1 a P35 | Lista, confirmar, prazo, pedir e cancelar troca, ir para as trocas abertas, botão Administração, erros, sair; **Missas abertas** (P27, P28); **Sair da escala**: botão só para quem se escalou, confirmação, sair e recarregar, "Agora não", erro de regra (P29 a P34); **guarda** da recarga que falha rápido (P35) |
| `trocas_disponiveis_page_test.dart` | TP1 a TP13 | Lista, aviso de aceite, mensagens em primeira pessoa, atualização, bloqueio do botão, **guarda** da recarga que falha rápido (TP13) |
| `admin_page_test.dart` | AD1 a AD6 | Menu da administração; abrir Convites, Locais e Missas; abrir Pendências em atraso; abrir Pessoas |
| `pendencia_em_atraso_test.dart` | PE1 a PE4 | Conversão do JSON, horário local e ordenação das pendências |
| `pendencias_em_atraso_page_test.dart` | PA1 a PA6 | Lista vazia, dados dos coroinhas, erro de carga, botão atualizar e recuperação após falha, **guarda**: falha imediata ao atualizar (PA6) |
| `convites_page_test.dart` | CV1 a CV9 | Opção de menor, código, copiar, erros, bloqueio durante a geração, novo código substitui o antigo |
| `local_test.dart` | LC1 a LC4 | Leitura do JSON, ordem alfabética sem diferenciar maiúsculas, lista vazia, ordem sem acentos |
| `locais_page_test.dart` | LO1 a LO9 | Lista, vazio, adicionar (sem espaços nas pontas, limpa o campo, recarrega), nome em branco, erro de regra mantém o texto, erro genérico, bloqueio do botão, falha ao carregar, **guarda**: se só a recarga falhar, não diz que a criação falhou |
| `missa_cadastrada_test.dart` | MC1 a MC5 | Leitura do JSON (horário no mesmo instante), ordem por horário, lista vazia, `escala_livre` (e padrão falso se faltar) |
| `pessoa_test.dart` | PS1 a PS5 | Leitura do JSON, papel, ordenação por nome, lista vazia, ordem sem acentos |
| `pessoas_page_test.dart` | PG1 a PG17 | Lista, ativar/desativar (com confirmação ao desativar), mudar papel (com confirmação), erros de regra e genérico, bloqueio durante a ação, falha ao carregar, guarda de recarga |
| `missas_abertas_page_test.dart` | AB1 a AB11 | Lista, vazio, falha ao carregar com "Tentar de novo", entrar (mensagem de sucesso, recarga), botão bloqueado durante a ação, erros que **guarda** da recarga que falha rápido (AB11), erros que recarregam a lista (não é mais livre, já começou, já está, missa inexistente) |
| `mensagem_de_erro_test.dart` | ME1 a ME3 | Erro de regra mostra a própria mensagem; qualquer outro erro vira o texto genérico; o texto técnico nunca aparece |
| `ordenacao_test.dart` | OR1 a OR5 | `compararNomes`: acentos, maiúsculas, cedilha e til, desempate "Jose" antes de "José", nomes iguais |
| `escalado_na_missa_test.dart` | EM1 a EM4 | Leitura da escalação, ordenação alfabética pelo nome lista vazia e ordem sem acentos |
| `escala_missa_page_test.dart` | EQ1 a EQ17 | Escala da missa (a função ao adicionar é opcional: EQ13, EQ16 e EQ17): lista e contagem, vazio, carga e falha com "Tentar novamente"; retirar (confirmação com o nome, confirmar, Cancelar, erro de regra, erro genérico) e **guarda**: se só a recarga falhar, não diz que a retirada falhou; adicionar (só quem ainda não está escalado, função sem espaços nas pontas, sem coroinha disponível, validações do diálogo, conflito de horário sem recarregar, botão bloqueado durante o envio) |
| `missas_page_test.dart` | MP1 a MP18 | Lista (horário e local), vazio, indicador de carga, falha ao carregar com "Tentar de novo", botão Adicionar missa; menu Editar e Remover, edição (local e horário atuais, novo horário, sem mudar nada, conflito de horário), remoção (confirmação, confirmar, Voltar, missa com escalados, erro genérico) e **guarda**: se só a recarga falhar, não diz que a remoção falhou; missa livre aparece marcada na lista e a chave chega pronta à edição (MP17, MP18) |
| `nova_missa_page_test.dart` | NM1 a NM16 | Campos, horário escolhido, avisos (sem local, sem data), salvar com horário e local e fechar, erro de regra, erro genérico, bloqueio do botão, sem locais, falha ao carregar locais, o caminho completo a partir da lista, e **o seletor de data e hora recebe o horário atual** (o da missa ao editar; nada ao criar; o último escolhido ao escolher de novo); a chave **Escala livre** (criar e editar) vai para o repositório (NM15, NM16) |

**Rodar:** `cd escala_app && flutter test`. O total confirmado no terminal em 21/11/2026 foi de **228 testes aprovados**. Histórico: 150 (20/11) → 160 (tela de escala da missa, EQ1 a EQ15, e retirada do teste do fake) → 182 (Pessoas) → 188 → 200 (Missas abertas e escala livre) → 208 (Sair da escala: M9, M10 e P29 a P34; eu anunciei 209 por erro de conta, e vale o que o comando informa, lição 13) → 211 (guardas P35, TP13 e AB11) → 215 (PA6 e ME1 a ME3) → 218 (R12 a R14) → 220 (EQ13, EQ16 e EQ17 com a função opcional) → **228** (ordem sem acentos: LC4, PS5, EM4 e OR1 a OR5). A contagem correta da rodada foi: **144 testes já existentes + PA1 a PA5 (cinco testes da tela de pendências) + AD5 (um teste adicional do menu administrativo) = 150**. Os testes foram construídos e executados durante o desenvolvimento conjunto; não há cinco testes pendentes de identificação. A tabela resume os grupos e rótulos, enquanto o total oficial é o informado pelo comando completo.

### 8.5 Como abrir o app

```bash
cd escala_app
flutter run -d chrome --web-port=3000 --dart-define-from-file=env.json
```

A porta **3000** precisa ser essa: ela está liberada no Supabase para o retorno do login. O `env.json` tem:

```json
{
  "SUPABASE_URL": "https://SEU-PROJETO.supabase.co",
  "SUPABASE_KEY": "a-chave-publica"
}
```

Use **só a chave pública** (publishable/anon). Nunca a `service_role`.

---

## 9. Login com Google

### 9.1 Configuração (feita uma vez)

**No Google Cloud Console:**

1. Criar um projeto e configurar o **Google Auth Platform**: nome do app, e-mail, público **Externo**.
2. Escopos: só `openid`, `email` e `profile`.
3. Criar um **ID de cliente OAuth** do tipo **Aplicativo da Web**, com:
   - URI de redirecionamento: o *Callback URL* do Supabase (`https://<projeto>.supabase.co/auth/v1/callback`);
   - Origem JavaScript: `http://localhost:3000`.
4. Guardar o **ID** e o **segredo**.

**No Supabase:**

1. *Authentication, Providers, Google*: ativar e colar o ID e o segredo.
2. *Authentication, URL Configuration, Redirect URLs*: adicionar `http://localhost:3000/**`.

O **segredo do Google fica só no painel do Supabase**: nunca em arquivo, nem no Git, nem na conversa.

### 9.2 O que aprendemos

- Com o app do Google em modo de teste e **só os escopos básicos**, qualquer conta consegue entrar (aparece um aviso de teste).
- **Trocar de conta:** o método `entrarComGoogle()` envia `queryParams: {'prompt': 'select_account'}` para `signInWithOAuth`. Em 20/11/2026, você confirmou no navegador que o Google apresentou as opções de contas para escolha. O parâmetro solicita a seleção; não encerra sessões nem remove contas já autenticadas.
- **Contas de menores supervisionadas (Family Link)** podem exigir **aprovação do responsável** para entrar em apps de terceiros. **Isso ainda não foi testado** com uma conta real (ver seção 11).

---

## 10. Receitas: como rodar e como trabalhar

### 10.1 Rodar tudo (conferência geral)

```bash
# 1) Núcleo Dart
cd escala_core && dart test

# 2) App Flutter
cd ../escala_app && flutter test
```

Depois, no **SQL Editor** do Supabase, rodar os testes `001` a `016` (cada um numa consulta nova). Todos devem dar `Success. No rows returned`.

### 10.2 Abrir o app no navegador

```bash
cd escala_app
flutter run -d chrome --web-port=3000 --dart-define-from-file=env.json
```

### 10.3 Criar o primeiro administrador (uma vez)

Entre no app com a sua conta Google (vai cair na tela de convite) e rode no SQL Editor:

```sql
insert into public.perfis (id, nome, papel)
select id, 'Seu Nome', 'admin'
from auth.users
where email = 'SEU_EMAIL_DO_GOOGLE';

select id, nome, papel, ativo from public.perfis where papel = 'admin';
```

> Não versione esse arquivo com o seu e-mail em repositório público.

### 10.4 Dados de teste para ver a escala

Este script **pode ser rodado várias vezes**: primeiro apaga os restos.

```sql
-- 1) limpa
delete from public.escalacoes
where missa_id in (
  select m.id from public.missas m
  join public.locais l on l.id = m.local_id
  where l.nome = 'Matriz (teste)');
delete from public.missas
where local_id in (select id from public.locais where nome = 'Matriz (teste)');
delete from public.locais where nome = 'Matriz (teste)';

-- 2) cria: uma missa daqui a 26h e outra daqui a 90 min (prazo já passou)
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
```

Para só **limpar**, rode apenas o bloco `1)`.

### 10.4b Dados de teste para as trocas

Cria a **Maria (teste)**, uma pessoa de mentira (sem e-mail, ninguém entra como ela), com dois pedidos de troca abertos. **Rode antes o script do 10.4** e logo depois este: um dos pedidos fica 30 minutos depois da sua missa de teste (mostra a mensagem de conflito) e o outro fica livre (mostra o aceite).

```sql
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
```

Para só **limpar**, rode apenas o bloco `0)`.

> **Os scripts 10.4 e 10.4b e o de limpeza existem como arquivos** em `supabase/scripts/` (`dados_teste_escala.sql`, `dados_teste_trocas.sql` e `limpar_dados_teste.sql`). Abra o arquivo, copie tudo e cole no SQL Editor: assim não é preciso procurar nesta documentação.

### 10.4c Conferir os locais no app

O repositório do Supabase não tem teste automático, então confira à mão (com o app aberto como administrador):

1. **Administração, Locais**: adicione `Capela (teste app)`. Ela deve aparecer na lista. (O nome é diferente de `Capela (teste)`, que o script 10.4b usa.)
2. Adicione o mesmo nome de novo: deve aparecer **"Já existe um local com esse nome."**.
3. Para limpar, no SQL Editor: `delete from public.locais where nome = 'Capela (teste app)';` (ou rode o `limpar_dados_teste.sql`).

### 10.4d Conferir as missas no app

Com o app aberto como administrador:

1. **Administração, Missas, Adicionar missa**: escolha um local (o "Matriz (teste)" do script 10.4, ou crie um em Locais), uma data e uma hora, e salve.
2. A missa deve aparecer na lista **com a mesma hora que você escolheu**. Se escolher 18:00 e aparecer 21:00 ou 15:00, é erro de conversão de fuso.
3. No Table Editor do Supabase a mesma missa aparece em UTC (18:00 em Recife vira 21:00): é o esperado.
4. **Editar:** menu ⋮ da missa, Editar. A tela abre com o local e o horário atuais. Mude a hora e salve: a lista mostra a hora escolhida. Mover para perto de outra missa do mesmo coroinha mostra "Esse coroinha já está escalado em uma missa com horário próximo.".
5. **Remover:** menu ⋮, Remover, confirmar. Uma missa **sem** escalados some da lista. Uma missa **com** escalados (as do script 10.4 têm o administrador escalado) mostra "Esta missa tem coroinhas escalados. Retire-os antes de removê-la." e continua na lista.
6. Para limpar, rode o bloco `1)` do script da seção 10.4.

### 10.5 Limpar contas e convites de teste

- **Usuários de teste:** painel do Supabase, *Authentication, Users*, apagar o usuário (o perfil e os dados do responsável saem junto). **Nunca apague a conta admin.**
- **Convites:** tabela `convites` (Table Editor, esquema `public`). `delete from public.convites where codigo_hash = public.hash_convite('TESTE123');`

### 10.6 Receita para acrescentar uma regra nova (TDD)

1. Escrever o **teste SQL** com a regra e rodá-lo: tem que dar o **vermelho certo**.
2. Escrever a **migração** com o mínimo para passar.
3. Rodar o teste: **verde**. Rodar **todos os anteriores**.
4. Se o banco ganhou um código de erro novo: acrescentar no `erros_do_banco.dart` (o teste de contrato avisa).
5. Se a regra aparece no app, nesta ordem:
   1. criar o **modelo** (se houver) e o teste dele: um arquivo novo dá erro de compilação no vermelho, e o modelo precisa existir antes de o fake importá-lo;
   2. acrescentar ao **fake** os campos e os métodos **sem `@override`** (a interface ainda não os tem; com `@override` quebraria a compilação de todos os testes que usam o fake);
   3. escrever o **teste de tela** e ver o vermelho;
   4. criar a tela, acrescentar os métodos na interface e no repositório do Supabase, e pôr o `@override` no fake;
   5. conferir à mão no navegador (receita 10.4c).
6. **Atualizar este documento.**

---

## 11. Pendências e lacunas conhecidas

**Revisão de 20/11/2026.** Conferido: a hora das missas é enviada ao banco em UTC (`toUtc().toIso8601String()`) e lida de volta em horário local; o `env.json` guarda uma chave *publishable* (a pública, como deve ser). A funcionalidade de pendências em atraso foi validada com a RPC e o teste SQL 014 já executado; a tela também foi aberta e conferida no app com a conta administradora. Em 20/11/2026, `flutter analyze` não apontou problemas e os 150 testes do app passaram (144 anteriores + PA1–PA5 + AD5). A validação manual com uma segunda conta não foi feita; a autorização de usuário comum é coberta pelo teste SQL D1 (`NAO_AUTORIZADO`). A migration 16 e o teste SQL 015 cobrem as operações de gestão de escala e pessoas no banco.

**Revisão de 21/11/2026.** Entraram a tela **Pessoas** (conferida no navegador: ativar e desativar funcionaram), a **escala livre** (migration 18, testes SQL 017 e 013 atualizado, auditoria de segurança sem achados) e as telas **Missas abertas** e **Sair da escala** (conferidas no navegador). `dart analyze` e `flutter analyze` sem problemas; 208 testes do app e 71 do núcleo aprovados.

**Limpeza de 21/11/2026 (antes de publicar).** (1) `Future.ignore()` nas recargas de Minha escala, Trocas abertas e Pendências em atraso, com testes de guarda (P35, TP13, PA6; AB11 já nascia verde). (2) A mensagem de erro das telas virou `mensagemDoErro` (testes ME1 a ME3). (3) A Raiz ganhou **Tentar de novo** (R12 a R14). (4) **Função em branco ao escalar** vira "A definir" no banco (migration 19, teste SQL 018) e o diálogo de adicionar coroinha deixa o campo opcional. (5) README do `escala_app` e `Coroinha` renomeado para `PessoaEscalavel`. (6) Rótulos do teste SQL 013 renomeados (CM1 a CM6) e ordem alfabética sem acentos (`compararNomes`). O Flutter foi atualizado e o `analyze` passou a avisar que `package:flutter/material.dart` está obsoleto; o app foi migrado para o pacote `material_ui` por você, com `analyze` e testes limpos depois. 228 testes do app aprovados.

### Alta prioridade (antes de usar com a turma)

| Item                          | Detalhe                                                                                                                                                                                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Teste do Family Link**      | Nenhuma conta de menor supervisionada foi testada. Fazer no **piloto**, com o responsável presente. Plano B: login por e-mail e senha.                                                                                                      |
| **Publicar o app**            | Hospedagem gratuita de páginas estáticas, endereço HTTPS, e acrescentar esse endereço no Google e no Supabase.                                                                                                                              |
| **Produção separada**         | Criar `escala-prod`, rodar as migrações em ordem, **nunca** os testes. Rotina de exportação de dados (plano gratuito sem backup diário e com pausa por inatividade).                                                                        |
| **Apagar um coroinha (LGPD)** | Hoje `escalacoes.coroinha_id` e `trocas.substituto_id` impedem apagar quem tem histórico. Decidir: anonimizar ou apagar em cascata.                                                                                                         |

### Média prioridade

- **Área do administrador no app**: completa (convites, locais, missas com escala livre, escala por missa, pendências em atraso e pessoas). Ao tornar alguém administrador, a função dele ainda é digitada à mão em cada escalação.
- **Notificações** (fase 2): aviso ao coordenador a 2h da missa, avisos de troca e de mudança de horário.
- **Escalar em missa que já começou** é permitido (decisão em aberto).
- **A lista pisca** ao recarregar depois de confirmar.
- **Missa em andamento some da lista** (o filtro é "a partir de agora").
- **O repositório do Supabase não tem teste automático** (só verificação manual; as consultas aninhadas da escala, das trocas e das missas abertas foram conferidas à mão). Em 21/11 isso mostrou o custo: um texto de `select` cortado só apareceu no navegador (lição 21).
- **O app não avisa antes** que um pedido de troca vai conflitar com a sua escala: você só descobre ao tocar em **Aceitar**.
- **Aceite simultâneo** (dois celulares ao mesmo tempo) só foi coberto por testes em sequência e pelo bloqueio de linha no banco; falta um teste real com dois aparelhos.
- **Todo membro vê os nomes de todos** (necessário para a troca, mas são nomes de menores).
- **Locais só se cadastram no app**: renomear ou remover um local não tem função no banco (só pelo painel).


### Baixa prioridade

- Dois administradores se rebaixando ao mesmo tempo podem causar um *deadlock* raro (o Postgres derruba um deles com erro; nada se corrompe).
- Nome de local com maiúsculas diferentes ("Matriz" e "matriz") conta como diferente.
- `editar_missa` aceita missa que já passou (reescreve o histórico).
- A tela **Nova missa** aceita data passada (como o banco). Uma missa criada no passado não aparece na lista, que mostra só a partir de agora.

- **Formatação:** `dart format` não foi confirmado nesta etapa. `flutter analyze` foi executado após as fatias 5f/5g e após a inclusão de `prompt=select_account`, terminando sem problemas; o aviso antigo de `anonKey` foi corrigido trocando o argumento de inicialização para `publishableKey`.

### Adiado de propósito

iPhone (login em app instalado precisa de teste num aparelho real), Google Play e App Store, notificações push.

---

## 12. Próximos passos

Ordem combinada:

1. ~~**Organizar:** pasta fora de `Downloads`, estrutura de pastas e Git (repositório, `.gitignore` da raiz e commits)~~ **feito**.
2. ~~**Trocas no app**~~ **Feito:** pedir, cancelar, ver as trocas abertas e aceitar.
3. **Área do administrador no app**, em partes: ~~entrada da área e **gerar convite**~~ **feito**; ~~**locais**~~ **feito**; **missas**: ~~listar~~ **feito**, ~~criar~~ **feito**, ~~**editar e remover**~~ **feito**; ~~**escalar e desescalar por missa**~~ **feito e conferido manualmente**; ~~**pendências em atraso**~~ **feito: RPC, tela, menu e testes; tela conferida no app com a conta administradora**; ~~**gestão de pessoas**~~ **feito**; ~~**escala livre** (administrador libera, coroinha entra e sai)~~ **feito**. O banco ainda não tem editar/remover local.
4. **Publicar o PWA** e fazer o **piloto** com poucas famílias (inclui o teste do Family Link).
5. **Fase 2:** notificações.
6. **Depois:** iPhone e lojas, se fizer sentido.

**Concluído em 21/11/2026:** tela **Pessoas**; administradores passam a poder ser escalados; **escala livre** do banco ao app (chave na missa, **Missas abertas**, **Entrar na escala**, **Sair da escala**). Limpeza de pendências pequenas (ver a revisão da seção 11): `ignore()` nas recargas, mensagem de erro única, Tentar de novo na Raiz, função em branco vira "A definir", `PessoaEscalavel`, ordem sem acentos e migração para `material_ui`. 228 testes do app aprovados.

**Concluído em 20/11/2026:** refinamento visual da tela `EscalaMissaPage` (contador, cabeçalho e estado vazio); correção da seleção de conta Google com `prompt=select_account`; e implementação de **Pendências em atraso** (consulta via RPC, modelo, repositório, fake, tela administrativa e testes). A tela de pendências foi aberta e conferida no app com a conta administradora. `flutter analyze` terminou sem problemas e `flutter test` passou com 150 testes. A escolha de contas Google também foi confirmada no navegador.

---

## 13. Segurança e privacidade

**Checklist:**

- [ ] A chave **`service_role`** nunca está no app, na página de teste, no Git ou na conversa.
- [ ] O **segredo do Google** só existe no painel do Supabase.
- [x] `env.json` e `supabase/scripts/admin.sql` fora do Git.
- [x] A chave pública (*publishable/anon*) é pública por desenho; a segurança vem da **RLS**. *(Conferido em 20/11: o `env.json` guarda a chave publishable; a RLS é coberta pelos testes SQL 010 e 017 e pela auditoria.)*
- [x] **Testes só no `escala-dev`.** Eles criam usuários em `auth.users` e mexem em administradores. *(Até aqui, sim: só existe o `escala-dev`. Vale de novo ao criar o `escala-prod`.)*
- [ ] O servidor local da página de teste usa `--bind 127.0.0.1`.
- [ ] Pedir o consentimento do responsável (o convite registra o nome e a data).
- [ ] Combinar com o coordenador que todos os membros veem os nomes dos outros.
- [ ] Rotina de exportação dos dados enquanto estiver no plano gratuito.
- [x] Repetir `supabase/scripts/auditoria_seguranca.sql` (A1 a A6) depois de cada migração. **Última rodada: 21/11/2026, no `escala-dev` (migrações 1 a 19), tudo como esperado.** *(Repetir a cada migração nova e no `escala-prod`.)*

**Limites assumidos:** o banco não conhece a idade de ninguém; **não há limite de tentativas** ao digitar códigos de convite (o espaço de códigos, cerca de 1,1 trilhão, e a validade de 7 dias tornam o acerto por tentativa desprezível).

---

## 14. Lições aprendidas

1. **Duas restrições violadas ao mesmo tempo:** a ordem em que o Postgres as checa não é garantida. Por isso a distinção "mesma missa" versus "conflito" fica na **função**, e a restrição é só a rede de segurança.
2. **Uma seta `=>` devolve o valor da expressão.** `setState(() => _x = futuro)` devolve o `Future` e o `setState` recusa. Use um bloco `{ ... }`.
3. **Um teste que passa por acaso não protege nada.** O `P5` passou com o bug do `setState` porque só olhava a lista; foi preciso exigir também que **nenhum aviso de erro** aparecesse.
4. **Testes de guarda** nascem verdes (2b, 7d, M4, L2 a L5): protegem decisões contra mudanças futuras.
5. **Script de dados de teste precisa poder rodar duas vezes** (limpar antes de criar).
6. **`now()` é fixo dentro de uma transação**, e por isso o tempo entra por parâmetro nas regras testáveis.
7. **Uma função `security definer` mal escrita vira brecha.** Defesa: permissão primeiro, `search_path` vazio, `revoke` de `anon`, e teste de permissão para cada função.
8. **O Google reaproveita a conta já logada.** Para solicitar a escolha de outra conta no OAuth, enviar `prompt=select_account` em `queryParams` de `signInWithOAuth`; a apresentação da seleção foi confirmada no navegador.
9. **Mudar a assinatura de uma função exige remover e recriar**, e atualizar os testes que a citam (foi o caso do `011`).
10. **Rodar todos os testes anteriores a cada migração** é o que pega regressões.
11. **Mensagem de erro depende de quem fala.** O domínio escreve em geral; a tela, que sabe quem está agindo, troca para primeira pessoa.
12. **Quando não dá para conferir a consulta do banco, mova o filtro para uma função pura e teste-a.** Foi assim com as trocas abertas.
13. **Conferir a contagem de testes.** Em uma etapa eu anunciei 49 testes e eram 50; o total deve ser o que o comando completo informa. Na conferência de 20/11/2026, `flutter test` terminou com 150 testes aprovados: 144 anteriores, cinco testes PA1–PA5 e o teste AD5. Essa composição foi conferida durante o trabalho conjunto; não há testes faltantes.
14. **Um erro que chega antes de alguém ouvir o `Future` derruba o teste.** O LO9 achou isso: ao recarregar logo depois de criar, o fake falhou na hora, antes de o `FutureBuilder` começar a ouvir, e o Dart tratou como erro não capturado. A correção é `futuro.ignore()` ao criar o `Future`; o `FutureBuilder` continua recebendo o erro. No app de verdade a rede demora e isso raramente aparece, mas o teste de guarda existe para este caminho.
15. **Há dois tipos de vermelho.** Um arquivo novo dá erro de compilação (o arquivo inteiro não carrega); um arquivo que já existe pode falhar por asserção. Por isso o modelo vem antes do fake, e o fake recebe os métodos novos **sem `@override`** até a interface existir.
16. **Um erro de compilação em um arquivo pode derrubar outro na mesma rodada.** Apareceu "The Dart compiler exited unexpectedly" em `convite_page_test.dart`, que não tinha mudado, e sumiu depois de a tela nova existir. Se acontecer, rode o arquivo sozinho antes de suspeitar do código.
17. **Um trecho solto confunde.** Ao alterar um arquivo que já existe, mostre o **antes e o depois** (ou devolva o arquivo inteiro). "Acrescente isto no `build`" sem mostrar onde deixou uma dúvida real na tela de Missas.
18. **Ao trocar linhas de um arquivo, diga também quais ficam.** Na tela de edição, "troque as duas linhas de estado" levou à remoção de duas linhas vizinhas (`_mensagem` e `_salvando`), e os outros erros vieram de caminhos de import e de um `appBar:` perdidos na colagem. Quando o arquivo ficar com mais de um ou dois trechos mudados, o certo é devolver o **arquivo inteiro**, e `dart analyze` é o primeiro passo depois de colar.
19. **OAuth pode solicitar explicitamente a seleção de conta.** `prompt=select_account` em `queryParams` de `signInWithOAuth` resolveu a reutilização automática da conta no navegador; a confirmação prática deve ser feita no fluxo real do Google.
20. **Teste escrito depois do código ainda precisa nascer vermelho em algum ponto.** A tela de escala por missa foi feita sem teste; ao escrevê-los depois, o EQ10 falhou e achou o `ignore()` que faltava (lição 14), e o EQ14 falhou por erro do próprio teste (abrir o diálogo já consulta a lista, então o total de cargas não é 1: o que importa é que o erro **não acrescente** uma carga). **Não teste o fake**: o arquivo `escala_por_missa_fake_test.dart` (FA1 a FA5) foi apagado, porque verificava o dublê e não o app.

21. **O `select` do Supabase não tem teste.** O fake devolve o que o teste manda, então um texto de `select` quebrado, ou uma coluna que o app lê e o banco não tem, só aparece no navegador. Em 21/11 o `select` da Minha escala ficou cortado depois de `auto_escalada,` (a linha seguinte se perdeu na edição) e a tela mostrou "Não foi possível carregar a sua escala". A resposta do Supabase (`PGRST100`) dizia exatamente o trecho. Depois de mexer em `supabase_escala_repository.dart`, abra a tela afetada antes de dar a etapa por encerrada.
22. **O helper do teste e o código precisam concordar sobre o formato do JSON.** No `ItemEscala`, `json[...]` é a escalação (`id`, `missa_id`, `funcao`, `auto_escalada`) e `missa[...]` é o objeto embutido `missas(...)` (só `inicio` e `locais`). Ler `missa['id']` em vez de `json['missa_id']` deu `Null is not a subtype of String` em todo teste que usa o helper `linha()`. Ao acrescentar um campo ao modelo, o helper de teste é o primeiro lugar a atualizar.
23. **Achou um tipo de erro, procure todos os casos.** O `ignore()` faltava em três telas além da primeira que mostrou o problema (Minha escala, Trocas abertas e Pendências em atraso). O teste da carga inicial (PA5) não pegava, porque a falha chegava com a tela já ouvindo; o furo só aparece quando a **recarga** falha de imediato. Para fechar um tipo de erro: um `grep` pelo padrão em todas as telas e um teste de guarda em cada uma.
24. **Trocou um trecho em vários arquivos? Cada arquivo precisa do import novo.** Em 21/11 a troca para `mensagemDoErro` deu dezenas de erros de compilação porque faltava o `import` em sete telas. Quando a mudança tem mais de um ponto por arquivo, rode `dart analyze` antes do `flutter test` (reforça a lição 18).
25. **Rótulos de teste precisam ser únicos no projeto.** Os testes SQL 006 e 013 usavam C1 a C6, e o `EM3` do Flutter foi usado duas vezes. Uma falha "[C3]" não diz de qual arquivo vem. Use um prefixo por arquivo (CM, FP, EL...) e confira o último rótulo existente antes de numerar.
26. **Atualizar o Flutter pode trazer avisos novos.** A saída de `analyze` limpa virou 27 avisos `info` (o `material.dart` obsoleto) depois de atualizar o SDK. Não é erro: faça a migração num passo separado, com os testes como rede de segurança, e confira a documentação oficial antes (o comando é `dart fix --apply --code=migrate_design_widgets`).

---

## 15. Glossário

| Termo | Significado |
|---|---|
| **TDD** | Escrever o teste antes: vermelho (falha), verde (passa), refatorar |
| **Migração** | Arquivo SQL que altera o banco, rodado uma vez, em ordem |
| **RLS** | *Row Level Security*: regras do banco sobre quem lê/escreve cada linha |
| **`security definer`** | A função roda com os poderes do dono, ignorando a RLS; por isso confere a permissão por dentro |
| **`auth.uid()`** | O id de quem está logado, preenchido pelo Supabase a partir do login |
| **RPC** | Chamar uma função do banco pelo app |
| **Restrição de exclusão** | Regra do banco que recusa linhas com intervalos sobrepostos |
| **Hash** | Versão embaralhada de um texto, sem volta; o convite é guardado assim |
| **Repositório** | A camada que esconde de onde vêm os dados (aqui: a interface `EscalaRepository`) |
| **Fake** | Versão falsa de uma peça, usada em testes |
| **PWA** | Site instalável como app |
| **Family Link** | Controle parental do Google para contas de crianças |
| **LGPD** | Lei Geral de Proteção de Dados |
| **Plano gratuito (Supabase)** | Pausa após cerca de uma semana sem uso e sem backup diário |
| **Escala livre** | Missa em que o administrador permite que os próprios coroinhas se escalem |
| **Auto-escalada** | Escalação que a própria pessoa criou numa missa livre; só essa ela pode desfazer sozinha |

---

## 16. Apêndice: testes e arquivos

### 16.1 Testes SQL

| Arquivo | Rótulos | O que cobre |
|---|---|---|
| `001_conflito_horario.sql` | 2, 2b, 2c | Conflito de horário, borda de 1h, outro coroinha |
| `002_escalar_funcao.sql` (v2) | 1, 3, 2d | `escalar`: caminho feliz, mesma missa, conflito (entra como admin) |
| `003_horario_missa.sql` | M1, M2, M3 | O período acompanha a missa; mover para conflito é bloqueado; borda |
| `004_presenca_mantida.sql` | M4 | Mudar o horário não desfaz presença confirmada |
| `005_escalar_permissao.sql` | P1, P2, P3 | Só admin escala; direitos de execução |
| `006_confirmar_presenca.sql` | B1, B2, C1 a C6 | Prazo exato; confirmar; atraso; permissão; idempotência |
| `007_abrir_troca.sql` | T1 a T8 | Abrir troca e suas validações; índice parcial |
| `008_cancelar_troca.sql` | X1 a X7 | Cancelar troca; permissão antes do estado |
| `009_aceitar_troca.sql` | A1 a A14 | Aceitar troca e todos os bloqueios |
| `010_leitura_rls.sql` | L1 a L5c | Quem lê o quê; escrita direta negada |
| `011_convite.sql` (v2) | V1 a V10 | Gerar e resgatar convite |
| `012_convite_adulto.sql` | W1 a W6 | Convite que dispensa o responsável |
| `013_cadastro_missas.sql` | CM1 a CM6 | Locais e missas (rótulos renomeados de C1 a C6 em 21/11, porque repetiam os do 006); o CM6 usa as assinaturas novas de `criar_missa` e `editar_missa` (migration 18) |
| `014_pendentes_em_atraso.sql` | D1 a D4 | Lista de pendentes em atraso |
| `015_gestao_escala.sql` | E1 a E5 | Desescalar somente antes do início da missa; ativar/desativar perfil; alterar papel; impedir que o sistema fique sem administrador ativo; remover missa somente sem escalados. Inclui os bloqueios de desativação com escalações futuras e de remoção de missa com escalações. |
| `016_escalar_validacoes.sql` | S1 a S5 | `escalar` valida missa e coroinha |
| `017_escala_livre.sql` | EL1 a EL8 | EL1/EL2: `criar_missa` e `editar_missa` com e sem a chave (nulo mantém), só admin cria; EL3: `auto_escalar` grava "A definir", confirmado, auto-escalada; EL4: recusas (missa inexistente, não livre, já começou, já escalado, conflito, perfil inativo) sem gravar nada; EL5: sair, entrar de novo, sem limite de vagas; EL6: saída recusada (não escalado, escalada pelo admin, já começou, inativo); EL7: desligar a escala livre mantém quem entrou, que ainda pode sair; EL8: direitos de execução (`anon` não, `authenticated` sim) |
| `018_funcao_padrao.sql` | FP1 a FP4 | `escalar` sem função: vazia, só espaços e nula viram "A definir"; função informada é mantida, sem os espaços das pontas |

### 16.2 Testes do núcleo Dart

- `escala_service_test.dart`: regras do núcleo da escala (conflito, presença, trocas, convites, confirmação idempotente, convite com e sem responsável).
- `traducao_erros_test.dart`: um teste por código do banco (incluindo `ESCALA_NAO_LIVRE` e `SAIDA_NAO_PERMITIDA`), robustez e contrato com as migrações.

### 16.3 Testes do app Flutter

Veja a tabela da seção 8.4 (228 testes, incluindo PS, PG, AB, EQ, PA, ME, OR e as séries novas de M, P, MP, NM, R e AD).

### 16.4 Outros arquivos

| Arquivo | Para quê |
|---|---|
| `ferramentas/teste_login_google.html` | Página local para testar login, RLS e convite sem o app. Rodar com `python3 -m http.server 3000 --bind 127.0.0.1` |
| `supabase/scripts/admin.sql` | Cria o primeiro administrador (contém e-mail: não versionar) |
| `env.json` | Chaves públicas do app (não versionar) |
| `supabase/scripts/auditoria_seguranca.sql` | Seis consultas só de leitura (rodar uma por vez) que conferem a segurança do banco; o esperado de cada uma está na seção 6.5 |

---

*Fim do documento. Ao terminar cada etapa, atualize as seções 1 (onde estamos), 6.3 (migrações), 11 (pendências) e 12 (próximos passos).*
