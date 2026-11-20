import 'package:escala_core/escala_core.dart' hide Coroinha;
import 'package:flutter/material.dart';

import '../data/coroinha.dart';
import '../data/escala_repository.dart';
import '../data/escalado_na_missa.dart';
import '../data/missa_cadastrada.dart';
import '../formatacao.dart';

/// Administração dos coroinhas escalados em uma missa específica.
class EscalaMissaPage extends StatefulWidget {
  final EscalaRepository repositorio;
  final MissaCadastrada missa;

  const EscalaMissaPage({
    super.key,
    required this.repositorio,
    required this.missa,
  });

  @override
  State<EscalaMissaPage> createState() => _EscalaMissaPageState();
}

class _EscalaMissaPageState extends State<EscalaMissaPage> {
  late Future<List<EscaladoNaMissa>> _escalados = widget.repositorio
      .escaladosDaMissa(widget.missa.id);

  final Set<String> _ocupadas = {};

  void _recarregar() {
    final futuro = widget.repositorio.escaladosDaMissa(widget.missa.id);
    // O erro aparece na própria tela, pelo FutureBuilder. Sem o ignore(), uma
    // falha que chega antes de a tela começar a ouvir seria tratada como erro
    // não capturado.
    futuro.ignore();
    setState(() {
      _escalados = futuro;
    });
  }

  void _mostrarErro(Object erro) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          erro is RegraDeNegocio
              ? erro.mensagem
              : 'Algo deu errado. Tente de novo.',
        ),
      ),
    );
  }

  Future<void> _adicionar() async {
    if (_ocupadas.contains('adicionar')) return;

    setState(() => _ocupadas.add('adicionar'));

    List<Coroinha> disponiveis;

    try {
      final todos = await widget.repositorio.coroinhas();
      final escalados = await widget.repositorio.escaladosDaMissa(
        widget.missa.id,
      );

      final idsEscalados = escalados.map((e) => e.coroinhaId).toSet();

      disponiveis = todos.where((c) => !idsEscalados.contains(c.id)).toList();
    } on Object catch (e) {
      _mostrarErro(e);
      if (mounted) {
        setState(() => _ocupadas.remove('adicionar'));
      }
      return;
    }

    if (!mounted) return;

    setState(() => _ocupadas.remove('adicionar'));

    if (disponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há coroinhas disponíveis para adicionar.'),
        ),
      );
      return;
    }

    final resultado = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _AdicionarCoroinhaDialog(coroinhas: disponiveis),
    );

    if (resultado == null || !mounted) return;

    setState(() => _ocupadas.add('adicionar'));

    var deuCerto = false;

    try {
      await widget.repositorio.escalar(
        missaId: widget.missa.id,
        coroinhaId: resultado.$1,
        funcao: resultado.$2,
      );
      deuCerto = true;
    } on Object catch (e) {
      _mostrarErro(e);
    } finally {
      if (mounted) {
        setState(() => _ocupadas.remove('adicionar'));
      }
    }

    if (deuCerto && mounted) _recarregar();
  }

  Future<void> _remover(EscaladoNaMissa escalado) async {
    if (_ocupadas.contains(escalado.id)) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Remover da escala?'),
        content: Text('Deseja remover ${escalado.nome} desta missa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    setState(() => _ocupadas.add(escalado.id));

    var deuCerto = false;

    try {
      await widget.repositorio.desescalar(escalado.id);
      deuCerto = true;
    } on Object catch (e) {
      _mostrarErro(e);
    } finally {
      if (mounted) {
        setState(() => _ocupadas.remove(escalado.id));
      }
    }

    if (deuCerto && mounted) _recarregar();
  }

  Widget _cabecalhoParticipantes(int quantidade) {
    final texto = quantidade == 1
        ? '1 participante'
        : '$quantidade participantes';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Coroinhas escalados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Chip(
            avatar: const Icon(Icons.people_outline, size: 18),
            label: Text(texto),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _estadoVazio() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Nenhum coroinha escalado',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Utilize o botão abaixo para adicionar '
            'o primeiro participante desta missa.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escala da missa')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ocupadas.contains('adicionar') ? null : _adicionar,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar coroinha'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.event)),
                      title: Text(
                        formatarDataMissa(widget.missa.inicio),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Data e horário'),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.location_on_outlined),
                      ),
                      title: Text(widget.missa.localNome),
                      subtitle: const Text('Local da celebração'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<EscaladoNaMissa>>(
              future: _escalados,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 12),
                        const Text('Não foi possível carregar os escalados.'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _recarregar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                }

                final escalados = snapshot.requireData;

                return RefreshIndicator(
                  onRefresh: () async {
                    _recarregar();
                    try {
                      await _escalados;
                    } on Object catch (_) {
                      // O FutureBuilder apresenta o erro.
                    }
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      _cabecalhoParticipantes(escalados.length),

                      if (escalados.isEmpty)
                        _estadoVazio()
                      else
                        ...escalados.map((escalado) {
                          final ocupado = _ocupadas.contains(escalado.id);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(
                                escalado.nome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(escalado.funcao),
                              trailing: IconButton(
                                tooltip: 'Remover da escala',
                                onPressed: ocupado
                                    ? null
                                    : () => _remover(escalado),
                                icon: ocupado
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.person_remove_outlined),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo para escolher um coroinha e informar sua função.
class _AdicionarCoroinhaDialog extends StatefulWidget {
  final List<Coroinha> coroinhas;

  const _AdicionarCoroinhaDialog({required this.coroinhas});

  @override
  State<_AdicionarCoroinhaDialog> createState() =>
      _AdicionarCoroinhaDialogState();
}

class _AdicionarCoroinhaDialogState extends State<_AdicionarCoroinhaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _funcaoController = TextEditingController();

  String? _coroinhaId;

  @override
  void dispose() {
    _funcaoController.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;
    if (_coroinhaId == null) return;

    Navigator.of(context).pop((_coroinhaId!, _funcaoController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar coroinha'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _coroinhaId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Coroinha',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final coroinha in widget.coroinhas)
                  DropdownMenuItem(
                    value: coroinha.id,
                    child: Text(coroinha.nome),
                  ),
              ],
              onChanged: (valor) {
                setState(() => _coroinhaId = valor);
              },
              validator: (valor) =>
                  valor == null ? 'Selecione um coroinha.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _funcaoController,
              decoration: const InputDecoration(
                labelText: 'Função',
                hintText: 'Ex.: turiferário',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'Informe a função.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Adicionar')),
      ],
    );
  }
}
