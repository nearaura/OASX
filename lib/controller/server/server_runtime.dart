import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Runtime paths from the OAS installation's config/deploy.yaml.
class ServerRuntime {
  ServerRuntime._(this.root, this.python, this.git, this.adb);

  final String root;
  final String python;
  final String git;
  final String? adb;

  factory ServerRuntime.load(String root) {
    final directory = Directory(root).absolute;
    for (final file in ['config/deploy.yaml', 'deploy/installer.py']) {
      if (!File(p.join(directory.path, file)).existsSync()) {
        throw FormatException('Missing OAS file: $file');
      }
    }
    final document = loadYaml(
      File(p.join(directory.path, 'config', 'deploy.yaml')).readAsStringSync(),
    );
    final deploy = document is Map ? document['Deploy'] : null;
    if (deploy is! Map) {
      throw const FormatException(
          'Missing Deploy section in config/deploy.yaml');
    }

    String? executable(String section, String key, {bool required = true}) {
      final values = deploy[section];
      final value = values is Map ? values[key] : null;
      if (!required && value == null) return null;
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing or invalid Deploy.$section.$key');
      }
      final path = p.normalize(
          p.isAbsolute(value) ? value : p.join(directory.path, value));
      if (required && !File(path).existsSync()) {
        throw FormatException('Deploy.$section.$key does not exist: $path');
      }
      return path;
    }

    return ServerRuntime._(
      directory.path,
      executable('Python', 'PythonExecutable')!,
      executable('Git', 'GitExecutable')!,
      executable('Adb', 'AdbExecutable', required: false),
    );
  }

  Map<String, String> get environment {
    final pythonDirectory = p.dirname(python);
    final pathKey = Platform.environment.keys.firstWhere(
      (key) => key.toUpperCase() == 'PATH',
      orElse: () => 'PATH',
    );
    final paths = [
      pythonDirectory,
      p.join(pythonDirectory, 'Scripts'),
      p.dirname(git),
      if (adb != null) p.dirname(adb!),
      if (Platform.environment[pathKey] != null) Platform.environment[pathKey]!,
    ];
    return {pathKey: paths.join(Platform.isWindows ? ';' : ':')};
  }
}
