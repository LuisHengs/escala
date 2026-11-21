import 'package:flutter/material.dart';

import '../data/escala_repository.dart';
import '../data/local.dart';
import '../data/missa_cadastrada.dart';
import '../formatacao.dart';
import '../mensagem_de_erro.dart';

/// Como a tela pergunta a data e a hora. [atual] é o horário já escolhido (o
/// da missa, ao editar), para o seletor abrir nele; nulo se ainda não há.
/// Entra por parâmetro para o teste não depender do calendário do sistema.
typedef EscolherDataHora = Future<DateTime?> Function(
  BuildContext context,
  DateTime? atual,
);

/// O padrão: o calendário e o relógio do sistema, um depois do outro, já
/// abertos em [atual] (ou em hoje, às 18:00, se não houver). Devolve nulo se a
/// pessoa desistir em qualquer um dos dois.
Future<DateTime?> escolherDataHoraDoSistema(
  BuildContext context,
  DateTime? atual,
) async {
  final agora = DateTime.now();
  final data = await showDatePicker(
    context: context,
    initialDate: atual ?? agora,
    firstDate: DateTime(agora.year - 1),
    lastDate: DateTime(agora.year + 2),
  );
  if (data == null || !context.mounted) return null;

  final hora = await showTimePicker(
    context: context,
    initialTime: atual == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay.fromDateTime(atual),
  );
  if (hora == null) return null;

  return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
}

/// (Administrador) Cadastra ou edita uma missa: local, data e hora. Ao salvar,
/// fecha e devolve `true` para quem abriu (a lista de missas se recarrega).
class NovaMissaPage extends StatefulWidget {
  final EscalaRepository repositorio;
  final EscolherDataHora escolherDataHora;

  /// Se vier preenchida, a tela edita essa missa em vez de criar uma nova.
  final MissaCadastrada? missa;

  const NovaMissaPage({
    super.key,
    required this.repositorio,
    this.escolherDataHora = escolherDataHoraDoSistema,
    this.missa,
  });

  @override
  State<NovaMissaPage> createState() => _NovaMissaPageState();
}

class _NovaMissaPageState extends State<NovaMissaPage> {
  late Future<List<Local>> _locais = widget.repositorio.locais();

  late String? _localId = widget.missa?.localId;
  late DateTime? _inicio = widget.missa?.inicio;
  late bool _escalaLivre = widget.missa?.escalaLivre ?? false;
  String? _mensagem; // aviso ou erro, já em português
  bool _salvando = false;

  bool get _editando => widget.missa != null;

  void _recarregarLocais() {
    final futuro = widget.repositorio.locais();
    // O erro aparece na própria tela, pelo FutureBuilder (ver LocaisPage).
    futuro.ignore();
    setState(() {
      _locais = futuro;
    });
  }

  Future<void> _escolherDataHora() async {
    final escolhida = await widget.escolherDataHora(context, _inicio);
    if (escolhida == null || !mounted) return;
    setState(() {
      _inicio = escolhida;
      _mensagem = null;
    });
  }

  Future<void> _salvar() async {
    final localId = _localId;
    final inicio = _inicio;
    if (localId == null) {
      setState(() => _mensagem = 'Escolha o local.');
      return;
    }
    if (inicio == null) {
      setState(() => _mensagem = 'Escolha a data e a hora.');
      return;
    }

    setState(() {
      _salvando = true;
      _mensagem = null;
    });
    var deuCerto = false;
    try {
      final missa = widget.missa;
      if (missa == null) {
        await widget.repositorio.criarMissa(
          inicio: inicio,
          localId: localId,
          escalaLivre: _escalaLivre,
        );
      } else {
        await widget.repositorio.editarMissa(
          missaId: missa.id,
          inicio: inicio,
          localId: localId,
          escalaLivre: _escalaLivre,
        );
      }
      deuCerto = true;
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        // Erros de regra têm mensagem própria; o resto vira um texto genérico.
        _mensagem = mensagemDoErro(e);
      });
    } finally {
      if (mounted) setState(() => _salvando = false);
    }

    if (deuCerto && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar missa' : 'Nova missa')),
      body: FutureBuilder<List<Local>>(
        future: _locais,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar os locais.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _recarregarLocais,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            );
          }
          final locais = snapshot.requireData;
          if (locais.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cadastre um local antes de criar uma missa.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final inicio = _inicio;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  DropdownButtonFormField<String>(
                    // Só pré-seleciona se o local ainda existir na lista; um
                    // valor fora dela derruba o Flutter.
                    initialValue: locais.any((l) => l.id == _localId)
                        ? _localId
                        : null,
                    decoration: const InputDecoration(labelText: 'Local'),
                    items: [
                      for (final local in locais)
                        DropdownMenuItem(
                          value: local.id,
                          child: Text(local.nome),
                        ),
                    ],
                    onChanged: _salvando
                        ? null
                        : (id) => setState(() {
                            _localId = id;
                            _mensagem = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _salvando ? null : _escolherDataHora,
                    child: Text(
                      inicio == null
                          ? 'Escolher data e hora'
                          : formatarDataMissa(inicio),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Escala livre'),
                    subtitle: const Text(
                      'Os coroinhas podem se escalar sozinhos nesta missa.',
                    ),
                    value: _escalaLivre,
                    onChanged: _salvando
                        ? null
                        : (valor) => setState(() => _escalaLivre = valor),
                  ),
                  if (_mensagem != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _mensagem!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _salvando ? null : _salvar,
                    child: _salvando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _editando ? 'Salvar alterações' : 'Salvar missa',
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
