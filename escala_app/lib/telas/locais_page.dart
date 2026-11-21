import 'package:material_ui/material_ui.dart';

import '../data/escala_repository.dart';
import '../data/local.dart';
import '../mensagem_de_erro.dart';

/// (Administrador) Lista as igrejas e capelas e cadastra uma nova.
class LocaisPage extends StatefulWidget {
  final EscalaRepository repositorio;

  const LocaisPage({super.key, required this.repositorio});

  @override
  State<LocaisPage> createState() => _LocaisPageState();
}

class _LocaisPageState extends State<LocaisPage> {
  late Future<List<Local>> _locais = widget.repositorio.locais();
  final _nome = TextEditingController();

  String? _mensagem; // aviso ou erro, já em português
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  void _recarregar() {
    final futuro = widget.repositorio.locais();
    // O erro aparece na própria tela, pelo FutureBuilder. Sem o ignore(), uma
    // falha que chega ANTES de a tela começar a ouvir seria tratada como erro
    // não capturado. O FutureBuilder continua recebendo o erro normalmente.
    futuro.ignore();
    setState(() {
      _locais = futuro;
    });
  }

  Future<void> _adicionar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      setState(() => _mensagem = 'Informe o nome do local.');
      return;
    }

    setState(() {
      _salvando = true;
      _mensagem = null;
    });
    var deuCerto = false;
    try {
      await widget.repositorio.criarLocal(nome);
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

    // A recarga fica FORA do try: se só ela falhar, a criação deu certo e
    // quem mostra o problema é a própria lista.
    if (deuCerto && mounted) {
      _nome.clear();
      _recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locais')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nome,
                  enabled: !_salvando,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nome do local',
                    errorText: _mensagem,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _salvando ? null : _adicionar,
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Adicionar local'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Local>>(
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
                          onPressed: _recarregar,
                          child: const Text('Tentar de novo'),
                        ),
                      ],
                    ),
                  );
                }
                final locais = snapshot.requireData;
                if (locais.isEmpty) {
                  return const Center(child: Text('Nenhum local cadastrado.'));
                }
                return ListView(
                  children: [
                    for (final local in locais)
                      ListTile(
                        leading: const Icon(Icons.church_outlined),
                        title: Text(local.nome),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
