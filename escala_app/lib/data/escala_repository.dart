import 'local.dart';
import 'item_escala.dart';
import 'troca_disponivel.dart';
import 'missa_cadastrada.dart';
import 'coroinha.dart';
import 'escalado_na_missa.dart';
import 'pendencia_em_atraso.dart';
import 'pessoa.dart';

/// Em que ponto do caminho de acesso a pessoa está.
///  - semLogin:  ainda não entrou com o Google;
///  - semPerfil: entrou, mas ainda não resgatou um convite (o banco nega tudo);
///  - membro:    tem perfil ativo e enxerga a escala;
///  - administrador: membro com papel de administrador (vê a área de
///    administração; o que ele pode fazer quem decide é o banco).
enum EstadoAcesso { semLogin, semPerfil, membro, administrador }

/// Tudo o que o app precisa do "mundo de fora" (banco, login). As telas só
/// conhecem esta interface, nunca o Supabase. Nos testes entra uma versão
/// falsa, e o app roda sem internet.
///
/// Falhas de regra chegam como [RegraDeNegocio] (ex.: ConviteUsado,
/// PermissaoNegada), já traduzidas do código do banco.
abstract class EscalaRepository {
  /// Emite o estado de acesso agora e toda vez que o login ou o perfil mudar.
  Stream<EstadoAcesso> get estadoAcesso;

  Future<void> entrarComGoogle();

  Future<void> sair();

  /// Resgata o convite e cria o perfil de quem está logado.
  ///
  /// [responsavel] é opcional na tela: quem decide se ele é obrigatório é o
  /// convite (o banco responde ResponsavelObrigatorio).
  Future<void> resgatarConvite({
    required String codigo,
    required String nome,
    String? responsavel,
  });

  /// As próximas missas em que a pessoa logada está escalada, em ordem.
  Future<List<ItemEscala>> minhaEscala();

  /// Confirma a presença da pessoa logada numa escalação dela.
  Future<void> confirmarPresenca(String escalacaoId);

  /// Abre um pedido de troca para uma escalação da pessoa logada. Todos os
  /// membros passam a poder aceitá-lo.
  Future<void> abrirTroca(String escalacaoId);

  /// Cancela um pedido de troca ABERTO (o da pessoa logada, ou qualquer um se
  /// for administrador).
  Future<void> cancelarTroca(String trocaId);

  /// Os pedidos de troca ABERTOS de outras pessoas, em missas que ainda não
  /// começaram, em ordem de horário.
  Future<List<TrocaDisponivel>> trocasDisponiveis();

  /// Aceita o pedido de troca: a escalação passa para a pessoa logada, já
  /// com a presença confirmada. Falhas de regra chegam como [RegraDeNegocio]
  /// (ex.: ConflitoDeHorario, TrocaJaResolvida).
  Future<void> aceitarTroca(String trocaId);

  // ---------- administração ----------

  /// (Administrador) Gera um convite e devolve o código, que só existe agora:
  /// o banco guarda apenas o hash. [exigeResponsavel] é verdadeiro para menores
  /// de idade.
  Future<String> gerarConvite({required bool exigeResponsavel});

  /// As igrejas e capelas cadastradas, em ordem alfabética.
  Future<List<Local>> locais();

  /// (Administrador) Cadastra um local. Falhas de regra chegam como
  /// [RegraDeNegocio] (ex.: LocalDuplicado, NomeInvalido).
  Future<void> criarLocal(String nome);

  /// (Administrador) As missas cadastradas a partir de agora, em ordem de
  /// horário, com o nome do local.
  Future<List<MissaCadastrada>> missas();

  /// (Administrador) Cadastra uma missa. [inicio] é a hora do aparelho.
  /// Falhas de regra chegam como [RegraDeNegocio] (ex.: HorarioInvalido,
  /// LocalInexistente).
  Future<void> criarMissa({
    required DateTime inicio,
    required String localId,
    bool escalaLivre = false,
    });

  /// (Administrador) Muda horário e/ou local de uma missa. [inicio] é a hora do
  /// aparelho. Falhas de regra chegam como [RegraDeNegocio] (ex.:
  /// ConflitoDeHorario).
  Future<void> editarMissa({
    required String missaId,
    required DateTime inicio,
    required String localId,
    bool escalaLivre = false,
  });

  /// (Administrador) Remove uma missa. Se ainda houver coroinhas escalados,
  /// chega [MissaComEscalados].
  Future<void> removerMissa(String missaId);

  /// (Administrador) Coroinhas ativos disponíveis para novas escalações.
  Future<List<Coroinha>> coroinhas();

  /// (Administrador) Escalações de uma missa, com nome e função.
  Future<List<EscaladoNaMissa>> escaladosDaMissa(String missaId);

  /// (Administrador) Inclui um coroinha na missa. O banco valida conflitos.
  Future<void> escalar({
    required String missaId,
    required String coroinhaId,
    required String funcao,
  });

  /// (Administrador) Retira uma escalação. O banco bloqueia missa iniciada.
  Future<void> desescalar(String escalacaoId);

  Future<List<PendenciaEmAtraso>> pendenciasEmAtraso();

  /// (Administrador) Todas as pessoas cadastradas, ativas ou não.
  Future<List<Pessoa>> pessoas();

  /// (Administrador) Ativa ou desativa uma pessoa. Desativar é recusado se ela
  /// tem missas futuras (TemEscalacoesFuturas) ou se é o último administrador
  /// ativo (UltimoAdmin).
  Future<void> definirAtivo({required String pessoaId, required bool ativo});

  /// (Administrador) Muda o papel ('admin' ou 'coroinha'). Tirar o papel do
  /// último administrador ativo é recusado (UltimoAdmin).
  Future<void> definirPapel({required String pessoaId, required String papel});

  /// (Coroinha) As missas futuras com escala livre em que a pessoa logada
  /// ainda NÃO está escalada, em ordem de horário.
  Future<List<MissaCadastrada>> missasAbertas();

  /// (Coroinha) Entra na escala de uma missa com escala livre: função "A
  /// definir" e já confirmado. Falhas de regra chegam como [RegraDeNegocio]
  /// (EscalaNaoLivre, MissaJaComecou, JaEscaladoNaMissa, ConflitoDeHorario).
  Future<void> entrarNaEscala(String missaId);

    /// O coroinha sai de uma escala em que ele mesmo se colocou.
  /// Lança [SaidaNaoPermitida], [MissaJaComecou] ou [EscalacaoNaoEncontrada].
  Future<void> sairDaEscala(String missaId);
}
