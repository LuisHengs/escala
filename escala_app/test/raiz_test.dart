import 'package:escala_app/data/escala_repository.dart';
import 'package:escala_app/telas/raiz.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) =>
      t.pumpWidget(MaterialApp(home: Raiz(repositorio: repo)));

  testWidgets(
    'R1: enquanto verifica o acesso, mostra um indicador de carregamento',
    (t) async {
      await montar(t);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('R2: sem login, mostra o botão Entrar com Google', (t) async {
    await montar(t);
    repo.emitir(EstadoAcesso.semLogin);
    await t.pump();
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('R3: tocar em Entrar com Google chama o repositório', (t) async {
    await montar(t);
    repo.emitir(EstadoAcesso.semLogin);
    await t.pump();
    await t.tap(find.text('Entrar com Google'));
    await t.pump();
    expect(repo.chamadasEntrar, 1);
  });

  testWidgets('R4: logado sem perfil, pede o código do convite', (t) async {
    await montar(t);
    repo.emitir(EstadoAcesso.semPerfil);
    await t.pump();
    expect(find.text('Código do convite'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsNothing);
  });

  testWidgets('R5: membro vê a tela Minha escala', (t) async {
    await montar(t);
    repo.emitir(EstadoAcesso.membro);
    await t.pump();
    expect(find.text('Minha escala'), findsOneWidget);
  });

  testWidgets(
    'R6: falha ao verificar o acesso mostra uma mensagem, sem travar',
    (t) async {
      await montar(t);
      repo.emitirErro(Exception('falha de rede'));
      await t.pump();
      expect(
        find.text('Não foi possível verificar o seu acesso.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('R7: quando o estado muda, a tela troca sozinha', (t) async {
    await montar(t);
    repo.emitir(EstadoAcesso.semLogin);
    await t.pump();
    expect(find.text('Entrar com Google'), findsOneWidget);

    repo.emitir(EstadoAcesso.membro);
    await t.pump();
    expect(find.text('Minha escala'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsNothing);
  });

  testWidgets('R8: tocar em Sair chama o repositório', (t) async {
    await montar(t);
    repo.emitir(EstadoAcesso.membro);
    await t.pump();
    await t.tap(find.text('Sair'));
    await t.pump();
    expect(repo.chamadasSair, 1);
  });

  testWidgets('R10: o administrador vê o botão Administração', (t) async {
    await montar(t);
    repo.emitir(EstadoAcesso.administrador);
    await t.pump();
    expect(find.text('Minha escala'), findsOneWidget);
    expect(find.text('Administração'), findsOneWidget);
  });

  testWidgets('R11: o membro comum NÃO vê o botão Administração', (t) async {
    await montar(t);
    repo.emitir(EstadoAcesso.membro);
    await t.pump();
    expect(find.text('Administração'), findsNothing);
  });

  testWidgets('R9: ao resgatar o convite, a tela troca para Minha escala', (
    t,
  ) async {
    repo.aoResgatar = () => repo.emitir(EstadoAcesso.membro);
    await montar(t);
    repo.emitir(EstadoAcesso.semPerfil);
    await t.pump();

    await t.enterText(
      find.widgetWithText(TextField, 'Código do convite'),
      'ABCD2345',
    );
    await t.enterText(find.widgetWithText(TextField, 'Seu nome'), 'Maria');
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();

    expect(find.text('Minha escala'), findsOneWidget);
    expect(find.text('Código do convite'), findsNothing);
  });

  testWidgets('R12: falha ao verificar o acesso oferece Tentar de novo', (
    t,
  ) async {
    await montar(t);
    repo.emitirErro(Exception('falha de rede'));
    await t.pump();

    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('R13: Tentar de novo pede ao repositório para verificar', (
    t,
  ) async {
    await montar(t);
    repo.emitirErro(Exception('falha de rede'));
    await t.pump();

    await t.tap(find.text('Tentar de novo'));
    await t.pump();

    expect(repo.reverificacoes, 1);
  });

  testWidgets('R14: se a nova verificação der certo, a tela sai do erro', (
    t,
  ) async {
    repo.aoReverificar = () => repo.emitir(EstadoAcesso.membro);
    await montar(t);
    repo.emitirErro(Exception('falha de rede'));
    await t.pump();

    await t.tap(find.text('Tentar de novo'));
    await t.pump();

    expect(find.text('Minha escala'), findsOneWidget);
    expect(find.text('Não foi possível verificar o seu acesso.'), findsNothing);
  });
}
