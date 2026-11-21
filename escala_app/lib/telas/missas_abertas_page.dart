import 'package:escala_core/escala_core.dart';
import 'package:flutter/material.dart';

import '../data/escala_repository.dart';
import '../data/missa_cadastrada.dart';
import '../formatacao.dart';
import '../mensagem_de_erro.dart';

/// (Coroinha) As missas futuras com escala livre em que a pessoa ainda não
/// está escalada. Cada uma tem o botão para entrar na escala.
class MissasAbertasPage extends StatefulWidget {
  final EscalaRepository repositorio;

  const MissasAbertasPage({super.key, required this.repositorio});

  @override
  State<MissasAbertasPage> createState() => _MissasAbertasPageState();
}

class _MissasAbertasPageState extends State<MissasAbertasPage> {
  late Future<List<MissaCadastrada>> _missas = widget.repositorio
      .missasAbertas();
  bool _ocupado = false; // bloqueia os botões enquanto uma entrada acontece

  void _recarregar() {
    final futuro = widget.repositorio.missasAbertas();
    // O erro aparece na própria tela, pelo FutureBuilder (lição 14).
    futuro.ignore();
    setState(() {
      _missas = futuro;
    });
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _entrar(MissaCadastrada missa) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    var deuCerto = false;
    var listaDesatualizada = false;
    try {
      await widget.repositorio.entrarNaEscala(missa.id);
      deuCerto = true;
    } on Object catch (e) {
      if (!mounted) return;
      _avisar(mensagemDoErro(e));
      // Nestes casos a lista que a pessoa está vendo ficou velha.
      listaDesatualizada =
          e is EscalaNaoLivre ||
          e is MissaJaComecou ||
          e is JaEscaladoNaMissa ||
          e is MissaInexistente;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }

    // Fora do try: se só o recarregamento falhar, a lista mostra o próprio
    // erro de carga e não diz que a entrada falhou.
    if (!mounted) return;
    if (deuCerto) _avisar('Você entrou na escala.');
    if (deuCerto || listaDesatualizada) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missas abertas')),
      body: FutureBuilder<List<MissaCadastrada>>(
        future: _missas,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar as missas abertas.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            );
          }
          final missas = snapshot.requireData;
          if (missas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma missa aberta no momento.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              for (final missa in missas)
                ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(formatarDataMissa(missa.inicio)),
                  subtitle: Text(missa.localNome),
                  trailing: FilledButton(
                    onPressed: _ocupado ? null : () => _entrar(missa),
                    child: const Text('Entrar na escala'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
