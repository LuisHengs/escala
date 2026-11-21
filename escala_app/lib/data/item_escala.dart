import 'package:escala_core/escala_core.dart';

/// Uma linha da tela "Minha escala": uma missa em que a pessoa está escalada.
class ItemEscala {
  final String escalacaoId;

  final String missaId;

  /// Horário no fuso do aparelho (o banco guarda em UTC).
  final DateTime inicio;
  final String local;
  final String funcao;
  final StatusPresenca status;
  final bool confirmadoComAtraso;
  final bool autoEscalada;

  /// O id da troca ABERTA desta escalação, ou nulo se não há nenhuma.
  final String? trocaAbertaId;

  const ItemEscala({
    required this.escalacaoId,
    required this.missaId,
    required this.inicio,
    required this.local,
    required this.funcao,
    required this.status,
    this.confirmadoComAtraso = false,
    this.autoEscalada = false,
    this.trocaAbertaId,
  });

  /// Há uma troca ABERTA para esta escalação.
  bool get trocaAberta => trocaAbertaId != null;

  /// A partir daqui a confirmação já conta como atrasada: 2h antes da missa
  /// (a mesma constante do núcleo e a mesma regra do banco).
  DateTime get limiteParaConfirmar => inicio.subtract(prazoConfirmacao);

  /// Lê uma linha como o Supabase a devolve: a escalação com a missa, o local
  /// e as trocas embutidos.
  factory ItemEscala.deJson(Map<String, dynamic> json) {
    final missa = json['missas'] as Map<String, dynamic>;
    final local = missa['locais'] as Map<String, dynamic>;
    final trocas = (json['trocas'] as List<dynamic>?) ?? const [];

    return ItemEscala(
      escalacaoId: json['id'] as String,
      missaId: json['missa_id'] as String,
      inicio: DateTime.parse(missa['inicio'] as String).toLocal(),
      local: local['nome'] as String,
      funcao: json['funcao'] as String,
      status: _status(json['status'] as String),
      confirmadoComAtraso: json['confirmado_com_atraso'] as bool,
      autoEscalada: json['auto_escalada'] as bool? ?? false,
      trocaAbertaId: _idDaTrocaAberta(trocas),
    );
  }

  /// A lista inteira, ordenada pelo horário da missa.
  static List<ItemEscala> listaDeJson(List<dynamic> linhas) =>
      linhas.map((l) => ItemEscala.deJson(l as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

  // Só pode haver UMA troca aberta por escalação (o banco garante).
  static String? _idDaTrocaAberta(List<dynamic> trocas) {
    for (final t in trocas.cast<Map<String, dynamic>>()) {
      if (t['status'] == 'aberta') return t['id'] as String;
    }
    return null;
  }

  // Um status que o app não conhece é um erro: melhor falhar do que mostrar
  // uma situação errada.
  static StatusPresenca _status(String texto) => switch (texto) {
    'pendente' => StatusPresenca.pendente,
    'confirmado' => StatusPresenca.confirmado,
    _ => throw FormatException('Status de presença desconhecido: $texto'),
  };
}
