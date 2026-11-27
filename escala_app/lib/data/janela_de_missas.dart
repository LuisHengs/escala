/// Quanto tempo uma missa dura, para efeito das listas: ela continua
/// aparecendo até 1h30 depois do início.
const duracaoDaMissa = Duration(hours: 1, minutes: 30);

/// A partir de quando as listas mostram missas: [agora] menos a duração de
/// uma missa (assim a missa em andamento não some no instante em que começa).
DateTime inicioDaJanela(DateTime agora) => agora.subtract(duracaoDaMissa);

/// O primeiro dia que o calendário oferece: hoje, à meia-noite. Dias que já
/// passaram não aparecem.
DateTime primeiroDiaParaEscolher(DateTime agora) =>
    DateTime(agora.year, agora.month, agora.day);
