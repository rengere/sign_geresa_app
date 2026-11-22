import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:firmador_geresa/services/nextcloud_api_service.dart';

class AnexosService {
	static Future<String?> procesarAnexos({
		required String rutaCarpetaDestino,
		required String nombreArchivoOriginal,
		required String rutaPdfOriginal,
		required List<File> archivosAnexos,
	}) async {
		try {
			final nombreBase = p.basenameWithoutExtension(nombreArchivoOriginal);
			final nombreCarpeta = '@$nombreBase';
			final rutaCarpetaLocal = p.join(rutaCarpetaDestino, nombreCarpeta);

			final carpeta = Directory(rutaCarpetaLocal);
			if (!await carpeta.exists()) {
				await carpeta.create(recursive: true);
			}

			final archivoOriginal = File(rutaPdfOriginal);
			if (!await archivoOriginal.exists()) {
				throw Exception('El archivo original no existe en: $rutaPdfOriginal');
			}
			await archivoOriginal.copy(p.join(rutaCarpetaLocal, nombreArchivoOriginal));

			for (final anexo in archivosAnexos) {
				await anexo.copy(p.join(rutaCarpetaLocal, p.basename(anexo.path)));
			}

			// --- CÁLCULO DE LA RUTA REMOTA ---
			// La raíz de Nextcloud local es: C:\Users\hailp\Nextcloud3
			const String raizNextcloudLocal = 'C:\\Users\\hailp\\Nextcloud3';
			
			// Normalizamos las rutas
			final rutaAbsolutaNormalizada = p.normalize(rutaCarpetaLocal);
			final raizNormalizada = p.normalize(raizNextcloudLocal);

			// Obtenemos la ruta relativa desde la raíz de Nextcloud
			// Ejemplo: GERESA_FIRMA\GERENCIA GENERAL\...\Doc Firmados\@Fdsa
			final rutaRelativaLocal = p.relative(rutaAbsolutaNormalizada, from: raizNormalizada);

			// Convertimos las barras de Windows (\) a barras de URL (/)
			var rutaRemota = rutaRelativaLocal.replaceAll('\\', '/');
			
			// Aseguramos que empiece con '/'
			if (!rutaRemota.startsWith('/')) {
				rutaRemota = '/$rutaRemota';
			}

			print('DEBUG ANEXOS - Ruta remota calculada: $rutaRemota');

			// Crear la carpeta remota
			await NextcloudApiService.crearCarpeta(rutaRemota);

			// Generar el enlace
			final enlace = await NextcloudApiService.generarEnlacePublico(rutaRemota);

			return enlace;
		} catch (e) {
			print('Error en AnexosService: $e');
			return null;
		}
	}
}