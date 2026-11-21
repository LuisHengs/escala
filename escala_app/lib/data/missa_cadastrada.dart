/// Uma missa cadastrada, como o administrador a vê: horário e local.
class MissaCadastrada {
  final String id;

  /// Horário no fuso do aparelho (o banco guarda em UTC).
  final DateTime inicio;
  final String localId;
  final String localNome;

  /// Se os coroinhas podem se escalar sozinhos nesta missa.
  final bool escalaLivre;

  const MissaCadastrada({
    required this.id,
    required this.inicio,
    required this.localId,
    required this.localNome,
    this.escalaLivre = false,
  });

  /// Lê uma linha como o Supabase a devolve: a missa com o local embutido.
  factory MissaCadastrada.deJson(Map<String, dynamic> json) {
    final local = json['locais'] as Map<String, dynamic>;
    return MissaCadastrada(
      id: json['id'] as String,
      inicio: DateTime.parse(json['inicio'] as String).toLocal(),
      localId: json['local_id'] as String,
      localNome: local['nome'] as String,
      escalaLivre: json['escala_livre'] as bool? ?? false,
    );
  }

  /// A lista inteira, ordenada pelo horário.
  static List<MissaCadastrada> listaDeJson(List<dynamic> linhas) =>
      linhas
          .map((l) => MissaCadastrada.deJson(l as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));
}
