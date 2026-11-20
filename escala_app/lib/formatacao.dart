const _dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

String _dois(int numero) => numero.toString().padLeft(2, '0');

/// Ex.: "dom 22/11 às 18:00". Usa o horário do próprio [DateTime] recebido
/// (a tela passa o horário local do aparelho).
String formatarDataMissa(DateTime data) {
  // DateTime.weekday vai de 1 (segunda) a 7 (domingo).
  final dia = _dias[data.weekday - 1];
  return '$dia ${_dois(data.day)}/${_dois(data.month)} '
      'às ${_dois(data.hour)}:${_dois(data.minute)}';
}
