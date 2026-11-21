import 'package:material_ui/material_ui.dart';

import '../data/escala_repository.dart';
import 'convite_page.dart';
import 'minha_escala_page.dart';

/// A tela que decide o que mostrar: login, convite ou a escala, conforme o
/// estado de acesso da pessoa. Ela só conversa com o [EscalaRepository].
class Raiz extends StatefulWidget {
  final EscalaRepository repositorio;

  const Raiz({super.key, required this.repositorio});

  @override
  State<Raiz> createState() => _RaizState();
}

class _RaizState extends State<Raiz> {
  // O stream é criado UMA vez. Se fosse criado dentro do build(), cada
  // reconstrução da tela abriria um stream novo e repetiria a consulta ao
  // banco.
  late final Stream<EstadoAcesso> _estado = widget.repositorio.estadoAcesso;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EstadoAcesso>(
      stream: _estado,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Mensagem(
            'Não foi possível verificar o seu acesso.',
            onTentarDeNovo: widget.repositorio.verificarAcessoDeNovo,
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        switch (snapshot.requireData) {
          case EstadoAcesso.semLogin:
            return _TelaLogin(onEntrar: widget.repositorio.entrarComGoogle);
          case EstadoAcesso.semPerfil:
            return ConvitePage(repositorio: widget.repositorio);
          case EstadoAcesso.membro:
            return MinhaEscalaPage(repositorio: widget.repositorio);
          case EstadoAcesso.administrador:
            return MinhaEscalaPage(
              repositorio: widget.repositorio,
              administrador: true,
            );
        }
      },
    );
  }
}

class _Mensagem extends StatelessWidget {
  final String texto;
  final Future<void> Function() onTentarDeNovo;

  const _Mensagem(this.texto, {required this.onTentarDeNovo});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onTentarDeNovo,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TelaLogin extends StatelessWidget {
  final Future<void> Function() onEntrar;

  const _TelaLogin({required this.onEntrar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Escala Coroinhas',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onEntrar,
              child: const Text('Entrar com Google'),
            ),
          ],
        ),
      ),
    );
  }
}
