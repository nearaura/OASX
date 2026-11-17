import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/views/server/server_view.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/shell.dart';

class RecordingShell implements Shell {
  final calls = <List<String>>[];
  bool failInstaller = false;

  @override
  Future<ProcessResult> runExecutableArguments(
    String executable,
    List<String> arguments, {
    void Function(Process process)? onProcess,
  }) async {
    calls.add([executable, ...arguments]);
    if (failInstaller && arguments.contains('deploy.installer')) {
      throw const ProcessException('python', [], 'Installer failed', 1);
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestServerController extends ServerController {
  final recordingShell = RecordingShell();

  @override
  Shell get getShell => recordingShell;
}

void main() {
  late Directory root;
  late String python;
  late TestServerController controller;

  setUp(() {
    root = Directory.systemTemp.createTempSync('oas launch ');
    for (final name in [
      'deploy/installer.py',
      'server.py',
      '.venv/python.exe',
      'git.exe'
    ]) {
      final file = File(p.join(root.path, name));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('');
    }
    python = p.normalize(p.join(root.path, '.venv/python.exe'));
    final deploy = File(p.join(root.path, 'config/deploy.yaml'));
    deploy.parent.createSync();
    deploy.writeAsStringSync('''
Deploy:
  Python:
    PythonExecutable: ${jsonEncode(python)}
  Git:
    GitExecutable: ${jsonEncode(p.join(root.path, 'git.exe'))}
''');
    controller = TestServerController();
    controller.rootPathServer.value = root.path;
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('uses configured Python for installer and server in order', () async {
    await controller.run();
    expect(controller.recordingShell.calls, [
      [python, '-m', 'deploy.installer'],
      [python, 'server.py'],
    ]);
    expect(controller.rootPathAuthenticated.value, isTrue);
  });

  test('does not start server when installer fails', () async {
    controller.recordingShell.failInstaller = true;
    await controller.run();
    expect(controller.recordingShell.calls, [
      [python, '-m', 'deploy.installer'],
    ]);
  });

  test('invalid configuration never starts a process', () async {
    File(python).deleteSync();
    await controller.run();
    expect(controller.recordingShell.calls, isEmpty);
    expect(controller.rootPathAuthenticated.value, isFalse);
  });

  test('saving corrected configuration revalidates the root', () {
    final file = File(p.join(root.path, 'config/deploy.yaml'));
    final valid = file.readAsStringSync();
    controller.writeDeploy('Deploy: {}');
    expect(controller.rootPathAuthenticated.value, isFalse);
    controller.writeDeploy(valid);
    expect(controller.rootPathAuthenticated.value, isTrue);
  });
}
