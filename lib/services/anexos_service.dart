import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:firmador_geresa/services/nextcloud_api_service.dart';
import 'package:firmador_geresa/services/nextcloud_rutas_service.dart';

class SesionAnexos {
	final String nombrePdf;
	final String destino;
	final String rutaLocal;
	final String rutaRemota;
	String? url;
	SesionAnexos(this.nombrePdf, this.destino, this.rutaLocal, this.rutaRemota);
}

class AnexosService {
	static Future<SesionAnexos> reservarSesion(String destino, String nombre) async {
		final base = p.basenameWithoutExtension(nombre);
		for (int i = 0; i < 60; i++) {
			final ahora = DateTime.now().add(Duration(seconds: i));
			String dos(int n) => n.toString().padLeft(2, '0');
			final marca = '${dos(ahora.day)}-${dos(ahora.month)}-${ahora.year}_${dos(ahora.hour)}-${dos(ahora.minute)}-${dos(ahora.second)}';
			final nombrePdf = '${base}_$marca.pdf';
			final local = p.join(destino, '@${base}_$marca');
			if (await Directory(local).exists() || await File(p.join(destino, nombrePdf)).exists()) continue;
			final remota = await NextcloudRutasService.obtenerRutaRemota(local);
			if (await NextcloudApiService.reservarCarpeta(remota)) {
				return SesionAnexos(nombrePdf, destino, local, remota);
			}
		}
		throw StateError('No se pudo reservar un nombre único');
	}

	static Future<void> prepararSesion(SesionAnexos sesion) async {
		await Directory(sesion.rutaLocal).create(recursive: true);
		sesion.url ??= await NextcloudApiService.generarEnlacePublico(sesion.rutaRemota);
		if (sesion.url == null) throw StateError('No se pudo generar el enlace público');
	}

	static Future<void> reiniciarSesion(SesionAnexos sesion) async {
		final carpeta = Directory(sesion.rutaLocal);
		if (await carpeta.exists() && !await carpeta.list().isEmpty) {
			throw StateError('La carpeta contiene archivos. No se eliminará automáticamente.');
		}
		// Al eliminar la carpeta remota, Nextcloud invalida sus enlaces compartidos.
		await NextcloudApiService.eliminarCarpeta(sesion.rutaRemota);
		if (await carpeta.exists()) await carpeta.delete();
	}

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
