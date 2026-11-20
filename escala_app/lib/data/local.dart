/// Uma igreja ou capela onde há missa.
class Local {
  final String id;
  final String nome;

  const Local({required this.id, required this.nome});

  /// Lê uma linha como o Supabase a devolve.
  factory Local.deJson(Map<String, dynamic> json) =>
      Local(id: json['id'] as String, nome: json['nome'] as String);

  /// A lista inteira, em ordem alfabética (sem diferenciar maiúsculas).
  static List<Local> listaDeJson(List<dynamic> linhas) =>
      linhas.map((l) => Local.deJson(l as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
}
