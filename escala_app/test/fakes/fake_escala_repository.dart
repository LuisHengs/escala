import 'dart:async';

import 'package:escala_app/data/local.dart';
import 'package:escala_app/data/item_escala.dart';
import 'package:escala_app/data/troca_disponivel.dart';
import 'package:escala_app/data/missa_cadastrada.dart';
import 'package:escala_app/data/escala_repository.dart';

/// Versão falsa do repositório, só para testes: o teste manda o estado que
/// quiser, conta as chamadas que a tela fez e simula erro ou demora.
class FakeEscalaRepository implements EscalaRepository {
  final _controle = StreamController<EstadoAcesso>.broadcast();

  int chamadasEntrar = 0;
  int chamadasSair = 0;

  // ---------- convite ----------

  /// Cada chamada de resgatarConvite fica registrada aqui.
  final resgates = <({String codigo, String nome, String? responsavel})>[];

  /// Se preenchido, o próximo resgate lança este erro.
  Object? erroNoResgate;

  /// Se preenchido, o resgate espera até o teste completar (simula demora).
  Completer<void>? travarResgate;

  /// Roda depois de um resgate bem-sucedido (ex.: emitir o estado "membro").
  void Function()? aoResgatar;

  // ---------- administração: locais ----------

  /// O que locais() devolve. O teste pode trocar a lista a qualquer hora.
  List<Local> locaisCadastrados = [];
  int cargasLocais = 0;

  /// Se preenchido, locais() lança este erro.
  Object? erroAoCarregarLocais;

  /// Os nomes enviados a criarLocal(), na ordem.
  final locaisCriados = <String>[];

  /// Se preenchido, criarLocal() lança este erro.
  Object? erroAoCriarLocal;

  /// Se preenchido, criarLocal() espera até o teste completar.
  Completer<void>? travarCriarLocal;

  /// Roda depois de um criarLocal() bem-sucedido (ex.: atualizar a lista).
  void Function(String nome)? aoCriarLocal;

  @override
  Future<List<Local>> locais() async {
    cargasLocais++;
    if (erroAoCarregarLocais != null) throw erroAoCarregarLocais!;
    return List.of(locaisCadastrados);
  }

  @override
  Future<void> criarLocal(String nome) async {
    locaisCriados.add(nome);
    if (travarCriarLocal != null) await travarCriarLocal!.future;
    if (erroAoCriarLocal != null) throw erroAoCriarLocal!;
    aoCriarLocal?.call(nome);
  }

  // ---------- administração: missas ----------

  /// O que missas() devolve. O teste pode trocar a lista a qualquer hora.
  List<MissaCadastrada> missasCadastradas = [];
  int cargasMissas = 0;

  /// Se preenchido, missas() lança este erro.
  Object? erroAoCarregarMissas;

  /// Se preenchido, missas() espera até o teste completar.
  Completer<void>? travarCargaMissas;

  @override
  Future<List<MissaCadastrada>> missas() async {
    cargasMissas++;
    if (travarCargaMissas != null) await travarCargaMissas!.future;
    if (erroAoCarregarMissas != null) throw erroAoCarregarMissas!;
    return List.of(missasCadastradas);
  }

  // ---------- administração: criar missa ----------

  /// Cada missa criada (horário e id do local), na ordem.
  final missasCriadas = <({DateTime inicio, String localId})>[];

  /// Se preenchido, criarMissa() lança este erro.
  Object? erroAoCriarMissa;

  /// Se preenchido, criarMissa() espera até o teste completar.
  Completer<void>? travarCriarMissa;

  /// Roda depois de um criarMissa() bem-sucedido (ex.: atualizar a lista).
  void Function(DateTime inicio, String localId)? aoCriarMissa;

  @override
  Future<void> criarMissa({
    required DateTime inicio,
    required String localId,
  }) async {
    missasCriadas.add((inicio: inicio, localId: localId));
    if (travarCriarMissa != null) await travarCriarMissa!.future;
    if (erroAoCriarMissa != null) throw erroAoCriarMissa!;
    aoCriarMissa?.call(inicio, localId);
  }

  // --- editar / remover missa ---
  final missasEditadas =
      <({String missaId, DateTime inicio, String localId})>[];
  Object? erroAoEditarMissa;
  final missasRemovidas = <String>[];
  Object? erroAoRemoverMissa;
  void Function()? aoRemoverMissa; // roda depois de remover, antes de voltar

  @override
  Future<void> editarMissa({
    required String missaId,
    required DateTime inicio,
    required String localId,
  }) async {
    if (erroAoEditarMissa != null) throw erroAoEditarMissa!;
    missasEditadas.add((missaId: missaId, inicio: inicio, localId: localId));
  }

  @override
  Future<void> removerMissa(String missaId) async {
    if (erroAoRemoverMissa != null) throw erroAoRemoverMissa!;
    missasRemovidas.add(missaId);
    aoRemoverMissa?.call();
  }

  // ---------- escala ----------

  /// O que minhaEscala() devolve. O teste pode trocar a lista a qualquer hora.
  List<ItemEscala> escala = [];

  /// Se preenchido, minhaEscala() lança este erro.
  Object? erroAoCarregar;

  /// Se preenchido, minhaEscala() espera até o teste completar.
  Completer<void>? travarCarga;

  int cargas = 0;

  /// Ids confirmados, na ordem.
  final confirmacoes = <String>[];

  /// Se preenchido, confirmarPresenca() lança este erro.
  Object? erroAoConfirmar;

  /// Roda depois de uma confirmação bem-sucedida (ex.: atualizar [escala]).
  void Function(String escalacaoId)? aoConfirmar;

  // ---------- trocas ----------

  /// Ids das escalações cuja troca foi pedida, na ordem.
  final trocasAbertas = <String>[];

  /// Se preenchido, abrirTroca() lança este erro.
  Object? erroAoAbrirTroca;

  /// Roda depois de abrir uma troca com sucesso (ex.: atualizar [escala]).
  void Function(String escalacaoId)? aoAbrirTroca;

  /// Ids das trocas canceladas, na ordem.
  final trocasCanceladas = <String>[];

  /// Se preenchido, cancelarTroca() lança este erro.
  Object? erroAoCancelarTroca;

  /// Roda depois de cancelar uma troca com sucesso (ex.: atualizar [escala]).
  void Function(String trocaId)? aoCancelarTroca;

  // ---------- trocas dos outros (para aceitar) ----------

  /// O que trocasDisponiveis() devolve.
  List<TrocaDisponivel> disponiveis = [];

  /// Se preenchido, trocasDisponiveis() lança este erro.
  Object? erroAoCarregarDisponiveis;

  /// Se preenchido, trocasDisponiveis() espera até o teste completar.
  Completer<void>? travarCargaDisponiveis;

  int cargasDisponiveis = 0;

  /// Ids das trocas aceitas, na ordem.
  final aceites = <String>[];

  /// Se preenchido, aceitarTroca() lança este erro.
  Object? erroAoAceitar;

  /// Se preenchido, aceitarTroca() espera até o teste completar.
  Completer<void>? travarAceite;

  /// Roda depois de aceitar com sucesso (ex.: esvaziar [disponiveis]).
  void Function(String trocaId)? aoAceitar;

  // ---------- administração: convites ----------

  /// O valor de exigeResponsavel de cada convite gerado, na ordem.
  final convitesGerados = <bool>[];

  /// O código que gerarConvite() devolve. O teste pode trocá-lo a qualquer hora.
  String codigoGerado = 'ABCD2345';

  /// Se preenchido, gerarConvite() lança este erro.
  Object? erroAoGerarConvite;

  /// Se preenchido, gerarConvite() espera até o teste completar.
  Completer<void>? travarGeracao;

  // ---------- controle do estado de acesso ----------

  void emitir(EstadoAcesso estado) => _controle.add(estado);
  void emitirErro(Object erro) => _controle.addError(erro);
  Future<void> fechar() => _controle.close();

  @override
  Stream<EstadoAcesso> get estadoAcesso => _controle.stream;

  @override
  Future<void> entrarComGoogle() async => chamadasEntrar++;

  @override
  Future<void> sair() async => chamadasSair++;

  @override
  Future<void> resgatarConvite({
    required String codigo,
    required String nome,
    String? responsavel,
  }) async {
    resgates.add((codigo: codigo, nome: nome, responsavel: responsavel));
    if (travarResgate != null) await travarResgate!.future;
    if (erroNoResgate != null) throw erroNoResgate!;
    aoResgatar?.call();
  }

  @override
  Future<List<ItemEscala>> minhaEscala() async {
    cargas++;
    if (travarCarga != null) await travarCarga!.future;
    if (erroAoCarregar != null) throw erroAoCarregar!;
    return List.of(escala);
  }

  @override
  Future<void> confirmarPresenca(String escalacaoId) async {
    confirmacoes.add(escalacaoId);
    if (erroAoConfirmar != null) throw erroAoConfirmar!;
    aoConfirmar?.call(escalacaoId);
  }

  @override
  Future<void> abrirTroca(String escalacaoId) async {
    trocasAbertas.add(escalacaoId);
    if (erroAoAbrirTroca != null) throw erroAoAbrirTroca!;
    aoAbrirTroca?.call(escalacaoId);
  }

  @override
  Future<void> cancelarTroca(String trocaId) async {
    trocasCanceladas.add(trocaId);
    if (erroAoCancelarTroca != null) throw erroAoCancelarTroca!;
    aoCancelarTroca?.call(trocaId);
  }

  @override
  Future<List<TrocaDisponivel>> trocasDisponiveis() async {
    cargasDisponiveis++;
    if (travarCargaDisponiveis != null) await travarCargaDisponiveis!.future;
    if (erroAoCarregarDisponiveis != null) throw erroAoCarregarDisponiveis!;
    return List.of(disponiveis);
  }

  @override
  Future<void> aceitarTroca(String trocaId) async {
    aceites.add(trocaId);
    if (travarAceite != null) await travarAceite!.future;
    if (erroAoAceitar != null) throw erroAoAceitar!;
    aoAceitar?.call(trocaId);
  }

  @override
  Future<String> gerarConvite({required bool exigeResponsavel}) async {
    convitesGerados.add(exigeResponsavel);
    if (travarGeracao != null) await travarGeracao!.future;
    if (erroAoGerarConvite != null) throw erroAoGerarConvite!;
    return codigoGerado;
  }
}
