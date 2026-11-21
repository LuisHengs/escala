import '../ordenacao.dart';

/// Uma escalação existente, exibida na administração de uma missa.
class EscaladoNaMissa {
  final String id;
  final String coroinhaId;
  final String nome;
  final String funcao;

  const EscaladoNaMissa({
    required this.id,
    required this.coroinhaId,
    required this.nome,
    required this.funcao,
  });

  /// Lê a escalação com o perfil do coroinha embutido pelo Supabase.
  factory EscaladoNaMissa.deJson(Map<String, dynamic> json) {
    final perfil = json['perfis'] as Map<String, dynamic>;

    return EscaladoNaMissa(
      id: json['id'] as String,
      coroinhaId: json['coroinha_id'] as String,
      nome: perfil['nome'] as String,
      funcao: json['funcao'] as String,
    );
  }

  /// Lista em ordem alfabética pelo nome do coroinha.
  static List<EscaladoNaMissa> listaDeJson(List<dynamic> linhas) =>
      linhas
          .map((linha) => EscaladoNaMissa.deJson(linha as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => compararNomes(a.nome, b.nome));
}
