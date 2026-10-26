import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;

class SignerService {
	static Process? _apiProcess;
	static bool _isStarting = false;

	static Future<void> start() async {
		if (_isStarting || _apiProcess != null) return;
		_isStarting = true;

		try {
			// 1. Detectar la ruta base
			String baseDir;
			if (kDebugMode) {
				// En desarrollo, buscamos en la raíz del proyecto (donde está pubspec.yaml)
				// Platform.resolvedExecutable está en build\...\Debug\app.exe
				// Subimos 4 niveles para llegar a la raíz del proyecto.
				baseDir = Directory.current.path; 
				// Si no funciona, usa: p.dirname(p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable))))
			} else {
				// En producción, la API estará junto al .exe de Flutter
				baseDir = p.dirname(Platform.resolvedExecutable);
			}

			// 2. Construir la ruta al .exe de la API
			// Ajusta 'signer/api/FirmadorAPI.exe' según tu estructura real
			final String apiPath = p.join(baseDir, 'signer', 'api', 'FirmadorAPI.exe');

			if (!File(apiPath).existsSync()) {
				print('ADVERTENCIA: No se encontró la API en $apiPath');
				return;
			}

			print('🚀 Iniciando API en: $apiPath');
			
			_apiProcess = await Process.start(
				apiPath,
				[],
				workingDirectory: p.dirname(apiPath), // El directorio de la API
				mode: ProcessStartMode.normal, 
			);

			_apiProcess!.stderr.listen((data) => print('API ERR: ${String.fromCharCodes(data)}'));
			await Future.delayed(const Duration(seconds: 2));

		} catch (e) {
			print('Error al iniciar la API: $e');
		} finally {
			_isStarting = false;
		}
	}

	static void stop() {
		if (_apiProcess != null) {
			print('Deteniendo API...');
			_apiProcess!.kill(ProcessSignal.sigterm);
			_apiProcess = null;
		}
	}
}