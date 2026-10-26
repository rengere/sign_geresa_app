import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class SignerService {
  static Process? _apiProcess;
  static bool _isStarting = false;

  // Puerto configurado en tu API
  static const int _apiPort = 8426;

  static Future<void> start() async {
    if (_isStarting || _apiProcess != null) return;
    _isStarting = true;

    try {
      // 1. Verificar si el puerto ya está en uso (por una instancia anterior)
      bool isPortInUse = false;
      try {
        final socket = await Socket.connect('127.0.0.1', _apiPort,
            timeout: const Duration(milliseconds: 500));
        socket.destroy();
        isPortInUse = true;
      } catch (_) {
        // Puerto libre
      }

      if (isPortInUse) {
        debugPrint('[SignerService] El puerto $_apiPort ya está en uso. Asumiendo que la API ya está corriendo.');
        _isStarting = false;
        return;
      }

      // 2. Construir la ruta a la API (SIN CAMBIOS respecto a la tuya original)
      String baseDir = kDebugMode
          ? Directory.current.path
          : p.dirname(Platform.resolvedExecutable);

      final String apiPath = p.join(baseDir, 'signer', 'api', 'FirmadorAPI.exe');

      debugPrint('[SignerService] Buscando API en: $apiPath');

      if (!File(apiPath).existsSync()) {
        debugPrint('[SignerService] ADVERTENCIA: No se encontró la API en $apiPath');
        _isStarting = false;
        return;
      }

      debugPrint('[SignerService] Iniciando API en: $apiPath');

      // 3. Iniciar el proceso
      _apiProcess = await Process.start(
        apiPath,
        [],
        workingDirectory: p.dirname(apiPath),
        mode: ProcessStartMode.normal,
      );

      // Escuchar salida y errores de la API para debug
      _apiProcess!.stdout
          .transform(const SystemEncoding().decoder)
          .listen((data) => debugPrint('[signer] $data'));
      _apiProcess!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) => debugPrint('[signer][ERR] $data'));

      _apiProcess!.exitCode.then((codigo) {
        debugPrint('[SignerService] El proceso de la API terminó con código $codigo');
        _apiProcess = null;
      });

      // Esperar a que la API arranque
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[SignerService] Error al iniciar la API: $e');
    } finally {
      _isStarting = false;
    }
  }

  /// Mata el proceso de la API y todos sus subprocesos en Windows.
  static void stop() {
    if (_apiProcess != null) {
      debugPrint('[SignerService] Deteniendo API (PID: ${_apiProcess!.pid})...');

      try {
        // El comando taskkill /F (forzar) /T (árbol de procesos) /PID (ID del proceso)
        // asegura que no queden procesos huérfanos.
        Process.runSync('taskkill', ['/F', '/T', '/PID', '${_apiProcess!.pid}']);
      } catch (e) {
        debugPrint('[SignerService] Error al intentar matar la API con taskkill: $e');
        _apiProcess!.kill(ProcessSignal.sigterm);
      }

      _apiProcess = null;
    }
  }
}
