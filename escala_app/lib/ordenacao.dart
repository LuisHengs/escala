// Letras com acento e a letra base correspondente (mesma posição nas duas
// listas). A comparação troca cada uma pela base ANTES de comparar.
const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';

String _semAcentos(String texto) {
  final saida = StringBuffer();
  for (final rune in texto.runes) {
    final letra = String.fromCharCode(rune);
    final posicao = _comAcento.indexOf(letra);
    saida.write(posicao >= 0 ? _semAcento[posicao] : letra);
  }
  return saida.toString();
}

/// Compara dois nomes em ordem alfabética, sem diferenciar maiúsculas nem
/// acentos ("Érica" fica entre "Davi" e "Fábio"). Se forem iguais sem os
/// acentos, o sem acento vem antes ("Jose" antes de "José"), para a ordem
/// ser sempre a mesma.
int compararNomes(String a, String b) {
  final pelaBase = _semAcentos(a)
      .toLowerCase()
      .compareTo(_semAcentos(b).toLowerCase());
  if (pelaBase != 0) return pelaBase;
  return a.toLowerCase().compareTo(b.toLowerCase());
}
