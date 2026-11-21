import 'dart:async';

import 'package:escala_core/escala_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local.dart';
import 'item_escala.dart';
import 'escala_repository.dart';
import 'troca_disponivel.dart';
import 'missa_cadastrada.dart';
import 'pessoa_escalavel.dart';
import 'escalado_na_missa.dart';
import 'pendencia_em_atraso.dart';
import 'pessoa.dart';

/// A versão de verdade: fala com o Supabase. É o ÚNICO arquivo (junto com o
/// main.dart) que conhece o pacote supabase_flutter.
class SupabaseEscalaRepository implements EscalaRepository {
  final SupabaseClient _client;

  // O estado é recalculado quando alguém começa a ouvir, quando o login muda
  // e depois de resgatar um convite (que muda o perfil, mas não o login).
  // Um erro vira um evento do stream e NÃO o encerra: a próxima mudança
  // tenta de novo.
  late final StreamController<EstadoAcesso> _controle =
      StreamController<EstadoAcesso>.broadcast(onListen: _atualizar);

  SupabaseEscalaRepository(this._client) {
    _client.auth.onAuthStateChange.listen((_) => _atualizar());
  }

  @override
  Stream<EstadoAcesso> get estadoAcesso => _controle.stream;

  Future<void> _atualizar() async {
    if (!_controle.hasListener) return;
    try {
      _controle.add(await _calcular());
    } catch (e, s) {
      _controle.addError(e, s);
    }
  }

  @override
  Future<void> verificarAcessoDeNovo() => _atualizar();

  Future<EstadoAcesso> _calcular() async {
    if (_client.auth.currentSession == null) return EstadoAcesso.semLogin;
    // eh_membro() e eh_admin() são as mesmas funções que as políticas de
    // acesso usam no banco.
    final membro = await _client.rpc('eh_membro') as bool;
    if (!membro) return EstadoAcesso.semPerfil;
    final admin = await _client.rpc('eh_admin') as bool;
    return admin ? EstadoAcesso.administrador : EstadoAcesso.membro;
  }

  /// Chama uma função do banco. O banco devolve o código da regra violada
  /// (ex.: CONVITE_USADO) no texto do erro; aqui ele vira uma exceção do
  /// domínio.
  Future<dynamic> _chamarRegra(
    String funcao,
    Map<String, dynamic> parametros,
  ) async {
    try {
      return await _client.rpc(funcao, params: parametros);
    } on PostgrestException catch (e) {
      throw traduzirErroDoBanco(e.message);
    }
  }

  @override
  Future<void> entrarComGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: '${Uri.base.origin}/',
      queryParams: {'prompt': 'select_account'},
    );
  }

  @override
  Future<void> sair() => _client.auth.signOut();

  @override
  Future<void> resgatarConvite({
    required String codigo,
    required String nome,
    String? responsavel,
  }) async {
    await _chamarRegra('resgatar_convite', {
      'p_codigo': codigo,
      'p_nome': nome,
      'p_responsavel_nome': responsavel,
    });
    await _atualizar(); // agora eh_membro() é verdadeiro: a raiz troca de tela
  }

  @override
  Future<List<ItemEscala>> minhaEscala() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) throw StateError('Ninguém logado.');

    // A RLS já garante que só membros leem. "!inner" faz o filtro por horário
    // valer para a escalação inteira (e não só para a missa embutida).
    final linhas = await _client
        .from('escalacoes')
        .select(
          'id, missa_id, funcao, status, confirmado_com_atraso, auto_escalada, '
          'missas!inner(inicio, locais(nome)), trocas(id, status)',
        )
        .eq('coroinha_id', usuario.id)
        .gte('missas.inicio', DateTime.now().toUtc().toIso8601String());

    return ItemEscala.listaDeJson(linhas);
  }

  @override
  Future<void> confirmarPresenca(String escalacaoId) async {
    await _chamarRegra('confirmar_presenca', {'p_escalacao_id': escalacaoId});
  }

  @override
  Future<void> abrirTroca(String escalacaoId) async {
    await _chamarRegra('abrir_troca', {'p_escalacao_id': escalacaoId});
  }

  @override
  Future<void> cancelarTroca(String trocaId) async {
    await _chamarRegra('cancelar_troca', {'p_troca_id': trocaId});
  }

  @override
  Future<List<TrocaDisponivel>> trocasDisponiveis() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) throw StateError('Ninguém logado.');

    // A RLS deixa os membros lerem as trocas, as escalações, as missas e os
    // nomes. A consulta só filtra pelo status; o resto (tirar as minhas e as
    // missas que já começaram, ordenar) é feito em TrocaDisponivel.listaDeJson,
    // que tem teste.
    final linhas = await _client
        .from('trocas')
        .select(
          'id, escalacoes(funcao, coroinha_id, perfis(nome), '
          'missas(inicio, locais(nome)))',
        )
        .eq('status', 'aberta');

    return TrocaDisponivel.listaDeJson(
      linhas,
      meuId: usuario.id,
      agora: DateTime.now(),
    );
  }

  @override
  Future<void> aceitarTroca(String trocaId) async {
    await _chamarRegra('aceitar_troca', {'p_troca_id': trocaId});
  }

  @override
  Future<String> gerarConvite({required bool exigeResponsavel}) async {
    final codigo = await _chamarRegra('gerar_convite', {
      'p_exige_responsavel': exigeResponsavel,
    });
    return codigo as String;
  }

  @override
  Future<List<Local>> locais() async {
    // A RLS deixa qualquer membro ler os locais.
    final linhas = await _client.from('locais').select('id, nome');
    return Local.listaDeJson(linhas);
  }

  @override
  Future<void> criarLocal(String nome) async {
    await _chamarRegra('criar_local', {'p_nome': nome});
  }

  @override
  Future<List<MissaCadastrada>> missas() async {
    // A RLS deixa qualquer membro ler as missas e os locais.
    final linhas = await _client
        .from('missas')
        .select('id, inicio, local_id, escala_livre, locais(nome)')
        .gte('inicio', DateTime.now().toUtc().toIso8601String());
    return MissaCadastrada.listaDeJson(linhas);
  }

  @override
  Future<void> criarMissa({
    required DateTime inicio,
    required String localId,
    bool escalaLivre = false,
  }) async {
    await _chamarRegra('criar_missa', {
      // O banco guarda em UTC; a hora escolhida é a do aparelho.
      'p_inicio': inicio.toUtc().toIso8601String(),
      'p_local_id': localId,
      'p_escala_livre': escalaLivre,
    });
  }

  @override
  Future<void> editarMissa({
    required String missaId,
    required DateTime inicio,
    required String localId,
    bool escalaLivre = false,
  }) async {
    await _chamarRegra('editar_missa', {
      'p_missa_id': missaId,
      'p_inicio': inicio.toUtc().toIso8601String(),
      'p_local_id': localId,
      'p_escala_livre': escalaLivre,
    });
  }

  @override
  Future<void> removerMissa(String missaId) async {
    await _chamarRegra('remover_missa', {'p_missa_id': missaId});
  }

  @override
  Future<List<PessoaEscalavel>> coroinhas() async {
    // Qualquer pessoa ativa pode ser escalada (coroinha ou administrador).
    final linhas = await _client
        .from('perfis')
        .select('id, nome')
        .eq('ativo', true);
    return PessoaEscalavel.listaDeJson(linhas);
  }

  @override
  Future<List<EscaladoNaMissa>> escaladosDaMissa(String missaId) async {
    final linhas = await _client
        .from('escalacoes')
        .select('id, coroinha_id, funcao, perfis(nome)')
        .eq('missa_id', missaId);
    return EscaladoNaMissa.listaDeJson(linhas);
  }

  @override
  Future<List<PendenciaEmAtraso>> pendenciasEmAtraso() async {
    // A função verifica as pendências usando now() do próprio banco.
    // A autorização de administrador também é validada no PostgreSQL.
    final linhas = await _client.rpc('pendentes_em_atraso');

    return PendenciaEmAtraso.listaDeJson(linhas as List<dynamic>);
  }

  @override
  Future<void> escalar({
    required String missaId,
    required String coroinhaId,
    required String funcao,
  }) async {
    await _chamarRegra('escalar', {
      'p_missa_id': missaId,
      'p_coroinha_id': coroinhaId,
      'p_funcao': funcao,
    });
  }

  @override
  Future<void> desescalar(String escalacaoId) async {
    await _chamarRegra('desescalar', {'p_escalacao_id': escalacaoId});
  }

  @override
  Future<List<Pessoa>> pessoas() async {
    // A RLS deixa qualquer membro ler os perfis.
    final linhas = await _client
        .from('perfis')
        .select('id, nome, papel, ativo');
    return Pessoa.listaDeJson(linhas);
  }

  @override
  Future<void> definirAtivo({
    required String pessoaId,
    required bool ativo,
  }) async {
    await _chamarRegra('definir_ativo', {
      'p_perfil_id': pessoaId,
      'p_ativo': ativo,
    });
  }

  @override
  Future<void> definirPapel({
    required String pessoaId,
    required String papel,
  }) async {
    await _chamarRegra('definir_papel', {
      'p_perfil_id': pessoaId,
      'p_papel': papel,
    });
  }

  @override
  Future<List<MissaCadastrada>> missasAbertas() async {
    final meuId = _client.auth.currentUser!.id;
    final linhas = await _client
        .from('missas')
        .select(
          'id, inicio, local_id, escala_livre, locais(nome), '
          'escalacoes(coroinha_id)',
        )
        .eq('escala_livre', true)
        .gte('inicio', DateTime.now().toUtc().toIso8601String());
    // Tira as missas em que eu já estou escalado.
    final abertas = linhas.where((linha) {
      final escalados = (linha['escalacoes'] as List<dynamic>?) ?? const [];
      return !escalados.cast<Map<String, dynamic>>().any(
        (e) => e['coroinha_id'] == meuId,
      );
    }).toList();
    return MissaCadastrada.listaDeJson(abertas);
  }

  @override
  Future<void> entrarNaEscala(String missaId) async {
    await _chamarRegra('auto_escalar', {'p_missa_id': missaId});
  }

  @override
  Future<void> sairDaEscala(String missaId) async {
    await _chamarRegra('auto_desescalar', {'p_missa_id': missaId});
  }
}
