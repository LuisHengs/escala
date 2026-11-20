/// Um coroinha ativo que pode ser incluído em uma escala.
class Coroinha {
  final String id;
  final String nome;

  const Coroinha({required this.id, required this.nome});

  factory Coroinha.deJson(Map<String, dynamic> json) =>
      Coroinha(id: json['id'] as String, nome: json['nome'] as String);

  /// Lista em ordem alfabética, sem diferenciar maiúsculas.
  static List<Coroinha> listaDeJson(List<dynamic> linhas) =>
      linhas.map((l) => Coroinha.deJson(l as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
}
