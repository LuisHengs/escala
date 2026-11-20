/// Um pedido de troca de OUTRA pessoa que está aberto e pode ser aceito.
class TrocaDisponivel {
  final String trocaId;

  /// Horário no fuso do aparelho (o banco guarda em UTC).
  final DateTime inicio;
  final String local;
  final String funcao;

  /// Quem pediu a troca (o titular da escalação).
  final String titularNome;

  const TrocaDisponivel({
    required this.trocaId,
    required this.inicio,
    required this.local,
    required this.funcao,
    required this.titularNome,
  });

  /// Lê uma linha como o Supabase a devolve: a troca com a escalação, quem é
  /// o titular e a missa embutidos.
  factory TrocaDisponivel.deJson(Map<String, dynamic> json) {
    final escalacao = json['escalacoes'] as Map<String, dynamic>;
    final missa = escalacao['missas'] as Map<String, dynamic>;
    final local = missa['locais'] as Map<String, dynamic>;
    final perfil = escalacao['perfis'] as Map<String, dynamic>;

    return TrocaDisponivel(
      trocaId: json['id'] as String,
      inicio: DateTime.parse(missa['inicio'] as String).toLocal(),
      local: local['nome'] as String,
      funcao: escalacao['funcao'] as String,
      titularNome: perfil['nome'] as String,
    );
  }

  /// As trocas que a pessoa [meuId] pode aceitar agora: sem as dela mesma e
  /// sem as missas que já começaram, em ordem de horário.
  static List<TrocaDisponivel> listaDeJson(
    List<dynamic> linhas, {
    required String meuId,
    required DateTime agora,
  }) {
    final resultado = <TrocaDisponivel>[];

    for (final linha in linhas.cast<Map<String, dynamic>>()) {
      final escalacao = linha['escalacoes'] as Map<String, dynamic>;
      // Um pedido da própria pessoa não é para ela aceitar.
      if (escalacao['coroinha_id'] == meuId) continue;

      final troca = TrocaDisponivel.deJson(linha);
      // A missa começou quando agora >= início (mesma regra do banco).
      if (!troca.inicio.isAfter(agora)) continue;

      resultado.add(troca);
    }

    resultado.sort((a, b) => a.inicio.compareTo(b.inicio));
    return resultado;
  }
}
