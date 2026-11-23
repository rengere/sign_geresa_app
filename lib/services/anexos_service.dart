import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:firmador_geresa/services/nextcloud_api_service.dart';
import 'package:firmador_geresa/services/nextcloud_rutas_service.dart';

class AnexosService {
	static Future<String?> prepararCarpeta({
		required String rutaCarpetaDestino,
		required String nombreArchivoOriginal,
	}) async {
		try {
			final nombreBase = p.basenameWithoutExtension(nombreArchivoOriginal);
			final carpetaLocal = Directory(p.join(rutaCarpetaDestino, '@$nombreBase'));
			await carpetaLocal.create(recursive: true);
			final rutaRemota = await NextcloudRutasService.obtenerRutaRemota(carpetaLocal.path);
			debugPrint('[Anexos] Carpeta local: ${carpetaLocal.path}');
			debugPrint('[Anexos] Ruta remota: $rutaRemota');
			final creada = await NextcloudApiService.crearCarpeta(rutaRemota);
			if (!creada) {
				debugPrint('[Anexos] No se confirmó MKCOL. Se verificará la carpeta remota.');
			}
			final existe = await NextcloudApiService.existeCarpeta(rutaRemota);
			if (!existe) {
				throw StateError('La carpeta remota no existe o no es accesible: $rutaRemota');
			}
			final enlace = await NextcloudApiService.generarEnlacePublico(rutaRemota);
			if (enlace == null || enlace.trim().isEmpty) {
				throw StateError('Nextcloud no devolvió una URL pública para: $rutaRemota');
			}
			debugPrint('[Anexos] Enlace público generado correctamente.');
			return enlace;
		} catch (e) {
			debugPrint('[Anexos] Error preparando carpeta: $e');
			return null;
		}
	}

	static Future<void> transferirPendientes({
		required String rutaCarpetaDestino,
		required String nombreArchivoOriginal,
		required List<File> archivosAnexos,
	}) async {
		final nombreBase = p.basenameWithoutExtension(nombreArchivoOriginal);
		final carpeta = Directory(p.join(rutaCarpetaDestino, '@$nombreBase'));
		await carpeta.create(recursive: true);
		int transferidos = 0;
		for (final archivo in archivosAnexos) {
			if (!await archivo.exists()) {
				throw StateError('Anexo no encontrado: ${archivo.path}');
			}
			final nombreOriginal = p.basename(archivo.path);
			final extension = p.extension(nombreOriginal);
			final nombreSinExtension = p.basenameWithoutExtension(nombreOriginal);
			String nombreDestino = nombreOriginal;
			String rutaDestino = p.join(carpeta.path, nombreDestino);
			final rutaOrigenNormalizada = p.normalize(archivo.absolute.path).toLowerCase();
			final rutaDestinoNormalizada = p.normalize(File(rutaDestino).absolute.path).toLowerCase();
			if (rutaOrigenNormalizada == rutaDestinoNormalizada) {
				debugPrint('[Anexos] Archivo ya ubicado en destino: $nombreOriginal');
				transferidos++;
				continue;
			}
			int correlativo = 2;
			while (await File(rutaDestino).exists()) {
				nombreDestino = '${nombreSinExtension}_$correlativo$extension';
				rutaDestino = p.join(carpeta.path, nombreDestino);
				correlativo++;
			}
			final destino = await archivo.copy(rutaDestino);
			if (!await destino.exists()) {
				throw StateError('No se pudo verificar la copia: $rutaDestino');
			}
			if (await archivo.length() != await destino.length()) {
				throw StateError('El archivo copiado tiene un tamaño diferente: $nombreDestino');
			}
			transferidos++;
			debugPrint('[Anexos] Copiado ($transferidos/${archivosAnexos.length}): ${archivo.path} -> $rutaDestino');
		}
		debugPrint('[Anexos] Transferencia verificada: $transferidos/${archivosAnexos.length} archivos');
	}

	static Future<String?> procesarAnexos({
		required String rutaCarpetaDestino,
		required String nombreArchivoOriginal,
		required String rutaPdfOriginal,
		required List<File> archivosAnexos,
	}) async {
		try {
			final nombreBase = p.basenameWithoutExtension(nombreArchivoOriginal);
			final carpetaLocal = Directory(p.join(rutaCarpetaDestino, '@$nombreBase'));
			await carpetaLocal.create(recursive: true);
			final archivoOriginal = File(rutaPdfOriginal);
			if (!await archivoOriginal.exists()) {
				throw StateError('El documento original no existe: $rutaPdfOriginal');
			}
			await archivoOriginal.copy(p.join(carpetaLocal.path, nombreArchivoOriginal));
			await transferirPendientes(
				rutaCarpetaDestino: rutaCarpetaDestino,
				nombreArchivoOriginal: nombreArchivoOriginal,
				archivosAnexos: archivosAnexos,
			);
			return await prepararCarpeta(
				rutaCarpetaDestino: rutaCarpetaDestino,
				nombreArchivoOriginal: nombreArchivoOriginal,
			);
		} catch (e) {
			debugPrint('[Anexos] Error procesando anexos: $e');
			return null;
		}
	}
}
