import 'dart:math';

import 'dominio.dart';

class EscalaService {
  final List<Escalacao> _escalacoes = [];
  final List<Troca> _trocas = [];
  int _proximoIdEscalacao = 1;
  int _proximoIdTroca = 1;

  // ---------- Escalar ----------

  Escalacao escalar({
    required Coroinha ator,
    required Missa missa,
    required String coroinhaId,
    required String funcao,
  }) {
    if (ator.papel != Papel.admin) {
      throw const PermissaoNegada('Só o administrador pode escalar.');
    }
    _validarDisponibilidade(coroinhaId, missa);

    final escalacao = Escalacao(
      id: 'e${_proximoIdEscalacao++}',
      missa: missa,
      funcao: funcao,
      coroinhaId: coroinhaId,
    );
    _escalacoes.add(escalacao);
    return escalacao;
  }

  // ---------- Presença ----------

  Escalacao confirmar({
    required String escalacaoId,
    required String coroinhaId,
    required DateTime agora,
  }) {
    final escalacao = _buscarEscalacao(escalacaoId);

    if (escalacao.coroinhaId != coroinhaId) {
      throw const PermissaoNegada('Só o titular pode confirmar presença.');
    }

    // Já confirmada: devolve como está. Recalcular marcaria atraso em quem
    // confirmou no prazo só porque o relógio andou (mesma regra do banco).
    if (escalacao.status == StatusPresenca.confirmado) return escalacao;

    escalacao.status = StatusPresenca.confirmado;
    escalacao.confirmadoComAtraso = _chegouNoPrazo(escalacao.missa, agora);
    return escalacao;
  }

  /// Pendentes cuja missa começa em até [prazoConfirmacao] (e ainda não começou).
  List<Escalacao> pendentesEmAtraso(DateTime agora) => _escalacoes
      .where((e) => e.status == StatusPresenca.pendente)
      .where((e) =>
          _chegouNoPrazo(e.missa, agora) && agora.isBefore(e.missa.inicio))
      .toList();

  // ---------- Troca ----------

  Troca abrirTroca({
    required String coroinhaId,
    required String escalacaoId,
    required DateTime agora,
  }) {
    final escalacao = _buscarEscalacao(escalacaoId);

    if (escalacao.coroinhaId != coroinhaId) {
      throw const PermissaoNegada('Só o titular pode abrir a troca.');
    }
    _exigirMissaFutura(escalacao.missa, agora);

    // Só uma troca aberta por escalação. Conta apenas as ABERTAS: uma troca
    // já aceita não impede o novo titular de pedir outra (teste 15b).
    final jaTemAberta = _trocas.any(
      (t) => t.escalacaoId == escalacaoId && t.status == StatusTroca.aberta,
    );
    if (jaTemAberta) {
      throw const TrocaJaAberta(
          'Já existe uma troca aberta para esta escalação.');
    }

    final troca = Troca(
      id: 't${_proximoIdTroca++}',
      escalacaoId: escalacaoId,
    );
    _trocas.add(troca);
    return troca;
  }

  Troca aceitarTroca({
    required String trocaId,
    required String substitutoId,
    required DateTime agora,
  }) {
    final troca = _buscarTroca(trocaId);

    // 1º: troca já resolvida ("o primeiro vence").
    _exigirTrocaAberta(troca);

    final escalacao = _buscarEscalacao(troca.escalacaoId);

    // 2º: a missa não pode ter começado.
    _exigirMissaFutura(escalacao.missa, agora);

    // 3º: o titular não pode ser o próprio substituto (antes da
    // disponibilidade, senão receberia "já está nesta missa").
    if (substitutoId == escalacao.coroinhaId) {
      throw const SubstitutoInvalido(
          'O titular não pode aceitar a própria troca.');
    }

    // 4º: o substituto precisa estar livre naquele horário.
    _validarDisponibilidade(substitutoId, escalacao.missa);

    escalacao.coroinhaId = substitutoId;
    escalacao.status = StatusPresenca.confirmado; // aceitar já é confirmar
    escalacao.confirmadoComAtraso = _chegouNoPrazo(escalacao.missa, agora);
    troca.status = StatusTroca.aceita;
    troca.substitutoId = substitutoId;
    return troca;
  }

  Troca cancelarTroca({
    required String trocaId,
    required String coroinhaId,
  }) {
    final troca = _buscarTroca(trocaId);
    final escalacao = _buscarEscalacao(troca.escalacaoId);

    // 1º: permissão. Quem não é titular não precisa saber o estado da troca.
    if (escalacao.coroinhaId != coroinhaId) {
      throw const PermissaoNegada('Só o titular pode cancelar a troca.');
    }
    return _cancelar(troca);
  }

  Troca cancelarTrocaComoAdmin({
    required Coroinha ator,
    required String trocaId,
  }) {
    // Permissão antes da busca: quem não é admin não descobre se o id existe.
    if (ator.papel != Papel.admin) {
      throw const PermissaoNegada(
        'Só o administrador pode cancelar a troca de outra pessoa.',
      );
    }
    return _cancelar(_buscarTroca(trocaId));
  }

  // ---------- Convite ----------

  Convite gerarConvite({
    required Coroinha ator,
    bool exigeResponsavel = true,
  }) {
    if (ator.papel != Papel.admin) {
      throw const PermissaoNegada('Só o administrador pode gerar convites.');
    }
    return Convite(
      codigo: _gerarCodigo(),
      exigeResponsavel: exigeResponsavel,
    );
  }

  // ---------- Regras compartilhadas (privadas) ----------

  /// Cancelamento em um lugar só: só troca ABERTA pode ser cancelada.
  Troca _cancelar(Troca troca) {
    _exigirTrocaAberta(troca);
    troca.status = StatusTroca.cancelada;
    return troca;
  }

  /// Usada ao aceitar e ao cancelar: só troca ABERTA pode ser alterada.
  void _exigirTrocaAberta(Troca troca) {
    if (troca.status != StatusTroca.aberta) {
      throw const TrocaJaResolvida('Esta troca não está mais aberta.');
    }
  }

  /// Usada ao abrir e ao aceitar troca: a mesma regra nos dois lugares.
  void _exigirMissaFutura(Missa missa, DateTime agora) {
    if (!agora.isBefore(missa.inicio)) {
      throw const MissaJaComecou('A missa já começou.');
    }
  }

  /// Usada ao escalar e ao aceitar troca: a mesma regra nos dois lugares.
  void _validarDisponibilidade(String coroinhaId, Missa missa) {
    final dele = _escalacoes.where((e) => e.coroinhaId == coroinhaId);

    // Mesma missa vem ANTES do conflito: tem diferença zero e cairia nele.
    if (dele.any((e) => e.missa.id == missa.id)) {
      throw const JaEscaladoNaMissa('Coroinha já está escalado nesta missa.');
    }
    if (dele.any((e) => _seSobrepoem(e.missa, missa))) {
      throw const ConflitoDeHorario(
        'Coroinha já escalado em missa com horário próximo.',
      );
    }
  }

  /// Duas missas conflitam se começam com menos de [duracaoMissa] de diferença.
  bool _seSobrepoem(Missa a, Missa b) =>
      a.inicio.difference(b.inicio).abs() < duracaoMissa;

  /// true quando já se chegou em (ou passou de) 2h antes do início da missa.
  bool _chegouNoPrazo(Missa missa, DateTime agora) =>
      !agora.isBefore(missa.inicio.subtract(prazoConfirmacao));

  Escalacao _buscarEscalacao(String id) => _escalacoes.firstWhere(
        (e) => e.id == id,
        orElse: () =>
            throw const EscalacaoNaoEncontrada('Escalação não encontrada.'),
      );

  Troca _buscarTroca(String id) => _trocas.firstWhere(
        (t) => t.id == id,
        orElse: () => throw const TrocaNaoEncontrada('Troca não encontrada.'),
      );

  /// Sem 0/O nem 1/I, para ninguém errar ao digitar um convite no celular.
  String _gerarCodigo() {
    const alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final aleatorio = Random.secure();
    return List.generate(
      8,
      (_) => alfabeto[aleatorio.nextInt(alfabeto.length)],
    ).join();
  }
}
