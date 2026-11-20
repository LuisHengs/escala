/// Regras de tempo (decisões combinadas: ficam aqui para serem fáceis de mudar).
const Duration duracaoMissa = Duration(hours: 1);
const Duration prazoConfirmacao = Duration(hours: 2);

enum Papel { admin, coroinha }

enum StatusPresenca { pendente, confirmado }

enum StatusTroca { aberta, aceita, cancelada }

class Coroinha {
  final String id;
  final String nome;
  final Papel papel;

  const Coroinha({required this.id, required this.nome, required this.papel});
}

class Missa {
  final String id;
  final DateTime inicio;

  const Missa({required this.id, required this.inicio});
}

class Escalacao {
  final String id;
  final Missa missa;
  final String funcao;

  /// Titular atual. Muda quando uma troca é aceita.
  String coroinhaId;
  StatusPresenca status;

  /// true se foi confirmada depois do prazo (2h antes da missa).
  bool confirmadoComAtraso;

  Escalacao({
    required this.id,
    required this.missa,
    required this.funcao,
    required this.coroinhaId,
    this.status = StatusPresenca.pendente,
    this.confirmadoComAtraso = false,
  });
}

class Troca {
  final String id;
  final String escalacaoId;
  StatusTroca status;
  String? substitutoId;

  Troca({
    required this.id,
    required this.escalacaoId,
    this.status = StatusTroca.aberta,
    this.substitutoId,
  });
}

class Convite {
  final String codigo;

  /// true quando quem resgatar o convite precisa informar o responsável
  /// (menor de idade). O padrão é EXIGIR: se alguém esquecer de decidir, o
  /// erro cai do lado que protege (mesma regra do banco).
  final bool exigeResponsavel;

  const Convite({required this.codigo, this.exigeResponsavel = true});
}

/// Base de toda violação de regra de negócio.
abstract class RegraDeNegocio implements Exception {
  final String mensagem;
  const RegraDeNegocio(this.mensagem);

  @override
  String toString() => '$runtimeType: $mensagem';
}

class PermissaoNegada extends RegraDeNegocio {
  const PermissaoNegada(super.mensagem);
}

class ConflitoDeHorario extends RegraDeNegocio {
  const ConflitoDeHorario(super.mensagem);
}

class JaEscaladoNaMissa extends RegraDeNegocio {
  const JaEscaladoNaMissa(super.mensagem);
}

class MissaJaComecou extends RegraDeNegocio {
  const MissaJaComecou(super.mensagem);
}

class TrocaJaResolvida extends RegraDeNegocio {
  const TrocaJaResolvida(super.mensagem);
}

class SubstitutoInvalido extends RegraDeNegocio {
  const SubstitutoInvalido(super.mensagem);
}

class TrocaJaAberta extends RegraDeNegocio {
  const TrocaJaAberta(super.mensagem);
}

class EscalacaoNaoEncontrada extends RegraDeNegocio {
  const EscalacaoNaoEncontrada(super.mensagem);
}

class TrocaNaoEncontrada extends RegraDeNegocio {
  const TrocaNaoEncontrada(super.mensagem);
}
