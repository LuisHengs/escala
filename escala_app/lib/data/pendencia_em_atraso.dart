/// Uma escalação cuja confirmação ainda está pendente e cujo prazo
/// de confirmação já foi atingido.
class PendenciaEmAtraso {
  final String escalacaoId;
  final String missaId;

  /// Horário da missa no fuso do aparelho.
  final DateTime inicio;

  final String coroinhaId;
  final String coroinhaNome;
  final String funcao;

  const PendenciaEmAtraso({
    required this.escalacaoId,
    required this.missaId,
    required this.inicio,
    required this.coroinhaId,
    required this.coroinhaNome,
    required this.funcao,
  });

  /// Lê uma linha retornada pela RPC `pendentes_em_atraso`.
  factory PendenciaEmAtraso.deJson(Map<String, dynamic> json) {
    return PendenciaEmAtraso(
      escalacaoId: json['escalacao_id'] as String,
      missaId: json['missa_id'] as String,
      inicio: DateTime.parse(json['inicio'] as String).toLocal(),
      coroinhaId: json['coroinha_id'] as String,
      coroinhaNome: json['coroinha_nome'] as String,
      funcao: json['funcao'] as String,
    );
  }

  /// Converte a lista retornada pela RPC.
  /// Ordena por horário da missa e, em caso de empate, pelo nome.
  static List<PendenciaEmAtraso> listaDeJson(List<dynamic> linhas) {
    final resultado = linhas
        .map((linha) => PendenciaEmAtraso.deJson(linha as Map<String, dynamic>))
        .toList();

    resultado.sort((a, b) {
      final comparacaoHorario = a.inicio.compareTo(b.inicio);

      if (comparacaoHorario != 0) return comparacaoHorario;

      return a.coroinhaNome.compareTo(b.coroinhaNome);
    });

    return resultado;
  }
}
