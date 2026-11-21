import 'dart:async';

import 'package:escala_app/data/local.dart';
import 'package:escala_app/data/item_escala.dart';
import 'package:escala_app/data/troca_disponivel.dart';
import 'package:escala_app/data/missa_cadastrada.dart';
import 'package:escala_app/data/pessoa_escalavel.dart';
import 'package:escala_app/data/escalado_na_missa.dart';
import 'package:escala_app/data/escala_repository.dart';
import 'package:escala_app/data/pendencia_em_atraso.dart';
import 'package:escala_app/data/pessoa.dart';

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
  final missasCriadas =
      <({DateTime inicio, String localId, bool escalaLivre})>[];

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
    bool escalaLivre = false,
  }) async {
    missasCriadas.add((
      inicio: inicio,
      localId: localId,
      escalaLivre: escalaLivre,
    ));
    if (travarCriarMissa != null) await travarCriarMissa!.future;
    if (erroAoCriarMissa != null) throw erroAoCriarMissa!;
    aoCriarMissa?.call(inicio, localId);
  }

  // --- editar / remover missa ---
  final missasEditadas =
      <({String missaId, DateTime inicio, String localId, bool escalaLivre})>[];
  Object? erroAoEditarMissa;
  final missasRemovidas = <String>[];
  Object? erroAoRemoverMissa;
  void Function()? aoRemoverMissa; // roda depois de remover, antes de voltar

  @override
  Future<void> editarMissa({
    required String missaId,
    required DateTime inicio,
    required String localId,
    bool escalaLivre = false,
  }) async {
    if (erroAoEditarMissa != null) throw erroAoEditarMissa!;
    missasEditadas.add((
      missaId: missaId,
      inicio: inicio,
      localId: localId,
      escalaLivre: escalaLivre,
    ));
  }

  @override
  Future<void> removerMissa(String missaId) async {
    if (erroAoRemoverMissa != null) throw erroAoRemoverMissa!;
    missasRemovidas.add(missaId);
    aoRemoverMissa?.call();
  }

  // ---------- administração: pendências em atraso ----------

  /// Pendências que a consulta deve devolver.
  List<PendenciaEmAtraso> pendenciasCadastradas = [];

  /// Quantidade de consultas realizadas.
  int cargasPendenciasEmAtraso = 0;

  /// Se preenchido, a consulta lança este erro.
  Object? erroAoCarregarPendenciasEmAtraso;

  /// Se preenchido, a consulta espera até o teste liberar.
  Completer<void>? travarCargaPendenciasEmAtraso;

  @override
  Future<List<PendenciaEmAtraso>> pendenciasEmAtraso() async {
    cargasPendenciasEmAtraso++;

    if (travarCargaPendenciasEmAtraso != null) {
      await travarCargaPendenciasEmAtraso!.future;
    }

    if (erroAoCarregarPendenciasEmAtraso != null) {
      throw erroAoCarregarPendenciasEmAtraso!;
    }

    return List.of(pendenciasCadastradas);
  }

  // ---------- administração: escala por missa ----------

  List<PessoaEscalavel> coroinhasCadastrados = [];
  int cargasCoroinhas = 0;
  Object? erroAoCarregarCoroinhas;

  @override
  Future<List<PessoaEscalavel>> coroinhas() async {
    cargasCoroinhas++;
    if (erroAoCarregarCoroinhas != null) throw erroAoCarregarCoroinhas!;
    return List.of(coroinhasCadastrados);
  }

  final escaladosPorMissa = <String, List<EscaladoNaMissa>>{};
  final cargasEscaladosPorMissa = <String, int>{};
  Object? erroAoCarregarEscalados;

  @override
  Future<List<EscaladoNaMissa>> escaladosDaMissa(String missaId) async {
    cargasEscaladosPorMissa.update(
      missaId,
      (quantidade) => quantidade + 1,
      ifAbsent: () => 1,
    );
    if (erroAoCarregarEscalados != null) throw erroAoCarregarEscalados!;
    return List.of(escaladosPorMissa[missaId] ?? []);
  }

  final escalacoesCriadas =
      <({String missaId, String coroinhaId, String funcao})>[];
  Object? erroAoEscalar;
  Completer<void>? travarEscalar;
  void Function(String missaId, String coroinhaId, String funcao)? aoEscalar;

  @override
  Future<void> escalar({
    required String missaId,
    required String coroinhaId,
    required String funcao,
  }) async {
    if (travarEscalar != null) await travarEscalar!.future;
    if (erroAoEscalar != null) throw erroAoEscalar!;
    escalacoesCriadas.add((
      missaId: missaId,
      coroinhaId: coroinhaId,
      funcao: funcao,
    ));
    aoEscalar?.call(missaId, coroinhaId, funcao);
  }

  final escalacoesRemovidas = <String>[];
  Object? erroAoDesescalar;
  Completer<void>? travarDesescalar;
  void Function(String escalacaoId)? aoDesescalar;

  @override
  Future<void> desescalar(String escalacaoId) async {
    if (travarDesescalar != null) await travarDesescalar!.future;
    if (erroAoDesescalar != null) throw erroAoDesescalar!;
    escalacoesRemovidas.add(escalacaoId);
    aoDesescalar?.call(escalacaoId);
  }

  // ---------- administração: pessoas ----------

  List<Pessoa> pessoasCadastradas = [];
  int cargasPessoas = 0;
  Object? erroAoCarregarPessoas;
  Completer<void>? travarCargaPessoas;

  @override
  Future<List<Pessoa>> pessoas() async {
    cargasPessoas++;
    if (travarCargaPessoas != null) await travarCargaPessoas!.future;
    if (erroAoCarregarPessoas != null) throw erroAoCarregarPessoas!;
    return List.of(pessoasCadastradas);
  }

  final ativosDefinidos = <({String pessoaId, bool ativo})>[];
  Object? erroAoDefinirAtivo;
  void Function(String pessoaId, bool ativo)? aoDefinirAtivo;

  @override
  Future<void> definirAtivo({
    required String pessoaId,
    required bool ativo,
  }) async {
    if (erroAoDefinirAtivo != null) throw erroAoDefinirAtivo!;
    ativosDefinidos.add((pessoaId: pessoaId, ativo: ativo));
    aoDefinirAtivo?.call(pessoaId, ativo);
  }

  final papeisDefinidos = <({String pessoaId, String papel})>[];
  Object? erroAoDefinirPapel;

  @override
  Future<void> definirPapel({
    required String pessoaId,
    required String papel,
  }) async {
    if (erroAoDefinirPapel != null) throw erroAoDefinirPapel!;
    papeisDefinidos.add((pessoaId: pessoaId, papel: papel));
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

  int reverificacoes = 0;

  /// Roda quando a tela pede para verificar o acesso de novo (ex.: emitir o
  /// estado "membro", como o banco faria se a rede voltou).
  void Function()? aoReverificar;

  @override
  Future<void> verificarAcessoDeNovo() async {
    reverificacoes++;
    aoReverificar?.call();
  }

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

  // ---------- coroinha: missas abertas (escala livre) ----------

  List<MissaCadastrada> missasAbertasCadastradas = [];
  int cargasMissasAbertas = 0;
  Object? erroAoCarregarMissasAbertas;
  Completer<void>? travarCargaMissasAbertas;

  @override
  Future<List<MissaCadastrada>> missasAbertas() async {
    cargasMissasAbertas++;
    if (travarCargaMissasAbertas != null) {
      await travarCargaMissasAbertas!.future;
    }
    if (erroAoCarregarMissasAbertas != null) throw erroAoCarregarMissasAbertas!;
    return List.of(missasAbertasCadastradas);
  }

  final entradasNaEscala = <String>[];
  Object? erroAoEntrarNaEscala;
  Completer<void>? travarEntrarNaEscala;
  void Function(String missaId)? aoEntrarNaEscala;

  @override
  Future<void> entrarNaEscala(String missaId) async {
    entradasNaEscala.add(missaId);
    if (travarEntrarNaEscala != null) await travarEntrarNaEscala!.future;
    if (erroAoEntrarNaEscala != null) throw erroAoEntrarNaEscala!;
    aoEntrarNaEscala?.call(missaId);
  }

  // ---------- coroinha: sair da escala que ele mesmo escolheu ----------

  final saidasDaEscala = <String>[];
  Object? erroAoSairDaEscala;
  void Function(String missaId)? aoSairDaEscala;

  @override
  Future<void> sairDaEscala(String missaId) async {
    if (erroAoSairDaEscala != null) throw erroAoSairDaEscala!;
    saidasDaEscala.add(missaId);
    aoSairDaEscala?.call(missaId);
  }
}
