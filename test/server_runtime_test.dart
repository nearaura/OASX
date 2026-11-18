import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/controller/server/server_runtime.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('oas runtime ');
    for (final name in ['deploy/installer.py', 'server.py']) {
      final file = File(p.join(root.path, name));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('');
    }
    Directory(p.join(root.path, 'config')).createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  String createExecutable(String name) {
    final file = File(p.join(root.path, name));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('');
    return p.normalize(file.path);
  }

  void writeDeploy(Object? python, Object? git, {String? adb}) {
    File(p.join(root.path, 'config', 'deploy.yaml')).writeAsStringSync('''
Deploy:
  Python:
    PythonExecutable: ${jsonEncode(python)}
  Git:
    GitExecutable: ${jsonEncode(git)}
  Adb:
    AdbExecutable: ${jsonEncode(adb)}
''');
  }

  test('accepts absolute paths outside the OAS root, including spaces', () {
    final external = Directory.systemTemp.createTempSync('oas external ');
    try {
      final python = File(p.join(external.path, 'custom python.exe'))
        ..writeAsStringSync('');
      final git = File(p.join(external.path, 'custom git.exe'))
        ..writeAsStringSync('');
      writeDeploy(python.path, git.path);
      final runtime = ServerRuntime.load(root.path);
      expect(runtime.python, python.path);
      expect(runtime.git, git.path);
      expect(runtime.adb, isNull);
      expect(Directory(p.join(root.path, 'toolkit')).existsSync(), isFalse);
    } finally {
      external.deleteSync(recursive: true);
    }
  });

  test('resolves relative paths from OAS root, not current directory', () {
    final python = createExecutable('.venv/Scripts/python.exe');
    final git = createExecutable('custom Git/bin/git.exe');
    writeDeploy('./.venv/Scripts/python.exe', './custom Git/bin/git.exe');
    final runtime = ServerRuntime.load(root.path);
    expect(runtime.python, python);
    expect(runtime.git, git);
  });

  test('keeps toolkit installations working with their configured Git path',
      () {
    final python = createExecutable('toolkit/python.exe');
    final git = createExecutable('toolkit/Git/mingw64/bin/git.exe');
    writeDeploy('./toolkit/python.exe', './toolkit/Git/mingw64/bin/git.exe');
    final runtime = ServerRuntime.load(root.path);
    expect(runtime.python, python);
    expect(runtime.git, git);
    expect(File(p.join(root.path, 'toolkit/Git/cmd/git.exe')).existsSync(),
        isFalse);
  });

  test('PATH contains configured tools and preserves parent PATH', () {
    final python = createExecutable('.venv/Scripts/python.exe');
    final git = createExecutable('custom Git/bin/git.exe');
    writeDeploy(python, git, adb: './custom adb/adb.exe');
    final runtime = ServerRuntime.load(root.path);
    final environment = runtime.environment;
    final key = environment.keys.single;
    final separator = Platform.isWindows ? ';' : ':';
    final entries = environment[key]!.split(separator);
    expect(
        entries,
        containsAll([
          p.dirname(python),
          p.dirname(git),
          p.join(root.path, 'custom adb'),
        ]));
    if (Platform.environment[key] != null) {
      expect(environment[key], endsWith(Platform.environment[key]!));
    }
  });

  test('rejects missing, empty, non-string and nonexistent executable paths',
      () {
    final git = createExecutable('git.exe');
    for (final python in [null, '', '  ', 123, './missing/python.exe']) {
      writeDeploy(python, git);
      expect(() => ServerRuntime.load(root.path), throwsFormatException);
    }
    final python = createExecutable('python.exe');
    writeDeploy(python, './missing/git.exe');
    expect(() => ServerRuntime.load(root.path), throwsFormatException);
  });

  test('rejects malformed YAML and missing Deploy section', () {
    final deploy = File(p.join(root.path, 'config', 'deploy.yaml'));
    for (final contents in ['', 'Deploy: [', 'Deploy: []', 'Python: {}']) {
      deploy.writeAsStringSync(contents);
      expect(() => ServerRuntime.load(root.path), throwsA(anything));
    }
  });

  test('requires installer and deploy config', () {
    File(p.join(root.path, 'server.py')).deleteSync();
    writeDeploy(createExecutable('python.exe'), createExecutable('git.exe'));
    for (final name in ['deploy/installer.py', 'config/deploy.yaml']) {
      final file = File(p.join(root.path, name));
      final contents = file.readAsStringSync();
      file.deleteSync();
      expect(() => ServerRuntime.load(root.path), throwsFormatException);
      file.writeAsStringSync(contents);
    }
  });
}
