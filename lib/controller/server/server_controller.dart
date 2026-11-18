part of server;

class ServerController extends GetxController with LogMixin {
  final rootPathServer = ''.obs;
  final rootPathAuthenticated = true.obs;
  final showDeploy = true.obs;

  final log = ''.obs;
  final deployContent = ''.obs;
  Shell? shell;
  var shellController = ShellLinesController();
  ServerRuntime? _runtime;
  bool _starting = false;

  @override
  void onInit() {
    rootPathServer.value =
        Get.find<SettingsController>().storage.read('rootPathServer') ??
            'Please set OAS root path';
    shellController.stream.listen((event) {
      addLog('INFO: $event');
    });
    readDeploy();
    rootPathAuthenticated.value = authenticatePath(rootPathServer.value);
    super.onInit();
  }

  void updateRootPathServer(String value) {
    rootPathServer.value = value;
    Get.find<SettingsController>()
        .storage
        .write('rootPathServer', rootPathServer.value);
    readDeploy();
    rootPathAuthenticated.value = authenticatePath(value);
  }

  bool authenticatePath(String root) {
    _runtime = null;
    try {
      _runtime = ServerRuntime.load(root);
      return true;
    } catch (e) {
      addLog('ERROR: $e');
      return false;
    }
  }

  Shell get getShell => Shell(
        workingDirectory: _runtime!.root,
        runInShell: false,
        environment: _runtime!.environment,
        stdout: shellController.sink,
        stderr: shellController.sink,
        verbose: false,
      );

  Future<void> run() async {
    if (_starting) return;
    _starting = true;
    clearLog();
    try {
      // Read again so edits made outside OASX also take effect.
      rootPathAuthenticated.value = authenticatePath(rootPathServer.value);
      if (!rootPathAuthenticated.value) return;
      shell?.kill();
      shell = getShell;
      addLog('INFO: OAS working directory: ${_runtime!.root}');
      await shell!.runExecutableArguments(
        _runtime!.python,
        ['-m', 'deploy.installer'],
      );
      // The installer can update deploy.yaml. Validate it before starting OAS.
      rootPathAuthenticated.value = authenticatePath(rootPathServer.value);
      if (!rootPathAuthenticated.value) return;
      shell = getShell;
      addLog('INFO: Start OAS');
      await shell!.runExecutableArguments(_runtime!.python, ['server.py']);
    } catch (e) {
      addLog('ERROR: $e');
    } finally {
      _starting = false;
    }
  }

  void readDeploy() {
    final file = File('${rootPathServer.value}/config/deploy.yaml');
    try {
      deployContent.value =
          file.existsSync() ? file.readAsStringSync() : 'File not found';
    } catch (e) {
      deployContent.value = 'Error reading file: $e';
    }
  }

  void writeDeploy(String value) {
    final file = File('${rootPathServer.value}/config/deploy.yaml');
    deployContent.value = value;
    try {
      if (!file.existsSync()) {
        deployContent.value = 'File not found';
        return;
      }
      file.writeAsStringSync(value);
      rootPathAuthenticated.value = authenticatePath(rootPathServer.value);
    } catch (e) {
      deployContent.value = 'Error writing file: $e';
    }
  }
}
