import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:firmador_geresa/services/nextcloud_api_service.dart';

class AnexosService {
	static const String _raizNextcloudLocal =
		'C:\\Users\\hailp\\Nextcloud3';

	// ============================================================
	// RUTA REMOTA DE NEXTCLOUD
	// ============================================================

	static String _obtenerRutaRemota(String rutaCarpetaLocal) {
		final rutaAbsoluta = p.normalize(
			p.absolute(rutaCarpetaLocal),
		);

		final raizAbsoluta = p.normalize(
			p.absolute(_raizNextcloudLocal),
		);

		final rutaRelativa = p.relative(
			rutaAbsoluta,
			from: raizAbsoluta,
		);

		if (
			rutaRelativa == '..' ||
			p.isAbsolute(rutaRelativa) ||
			rutaRelativa.startsWith('..${p.separator}')
		) {
			throw StateError(
				'La carpeta de anexos está fuera de la raíz de Nextcloud: '
				'$rutaCarpetaLocal',
			);
		}

		final rutaRemota = rutaRelativa
			.replaceAll('\\', '/')
			.split('/')
			.where((segmento) => segmento.isNotEmpty)
			.join('/');

		return '/$rutaRemota';
	}

	// ============================================================
	// CREAR CARPETA Y OBTENER URL PARA EL QR
	// ============================================================

	static Future<String?> prepararCarpeta({
		required String rutaCarpetaDestino,
		required String nombreArchivoOriginal,
	}) async {
		try {
			final nombreBase = p.basenameWithoutExtension(
				nombreArchivoOriginal,
			);

			final carpetaLocal = Directory(
				p.join(rutaCarpetaDestino, '@$nombreBase'),
			);

			await carpetaLocal.create(recursive: true);

			final rutaRemota = _obtenerRutaRemota(
				carpetaLocal.path,
			);

			debugPrint(
				'[Anexos] Carpeta local: ${carpetaLocal.path}',
			);

			debugPrint(
				'[Anexos] Ruta remota: $rutaRemota',
			);

			// ----------------------------------------------------
			// INTENTAR CREAR LA CARPETA REMOTA
			// ----------------------------------------------------

			bool creada = false;

			try {
				creada = await NextcloudApiService.crearCarpeta(
					rutaRemota,
				);
			} catch (e) {
				debugPrint(
					'[Anexos] Error al crear carpeta remota: $e',
				);
			}

			if (!creada) {
				debugPrint(
					'[Anexos] No se confirmó la creación remota. '
					'Se intentará obtener el enlace de una carpeta existente.',
				);
			}

			// ----------------------------------------------------
			// OBTENER URL PÚBLICA
			// ----------------------------------------------------

			final enlace = await NextcloudApiService
				.generarEnlacePublico(rutaRemota);

			if (enlace == null || enlace.trim().isEmpty) {
				debugPrint(
					'[Anexos] No se pudo obtener una URL pública.',
				);

				return null;
			}

			debugPrint(
				'[Anexos] URL pública obtenida: $enlace',
			);

			// El editor utiliza esta URL para mostrar el QR.
			return enlace;
		} catch (e) {
			debugPrint(
				'[Anexos] Error preparando carpeta: $e',
			);

			return null;
		}
	}

	// ============================================================
	// TRANSFERENCIA DIFERIDA DE ANEXOS
	// ============================================================

	static Future<void> transferirPendientes({
		required String rutaCarpetaDestino,
		required String nombreArchivoOriginal,
		required List<File> archivosAnexos,
	}) async {
		final nombreBase = p.basenameWithoutExtension(
			nombreArchivoOriginal,
		);

		final carpeta = Directory(
			p.join(rutaCarpetaDestino, '@$nombreBase'),
		);

		await carpeta.create(recursive: true);

		int transferidos = 0;

		for (final archivo in archivosAnexos) {
			if (!await archivo.exists()) {
				throw StateError(
					'Anexo no encontrado: ${archivo.path}',
				);
			}

			final nombreOriginal = p.basename(
				archivo.path,
			);

			final extension = p.extension(
				nombreOriginal,
			);

			final nombreSinExtension = p.basenameWithoutExtension(
				nombreOriginal,
			);

			String nombreDestino = nombreOriginal;

			String rutaDestino = p.join(
				carpeta.path,
				nombreDestino,
			);

			// ----------------------------------------------------
			// COMPROBAR SI EL ARCHIVO YA ESTÁ EN DESTINO
			// ----------------------------------------------------

			final rutaOrigenNormalizada = p
				.normalize(archivo.absolute.path)
				.toLowerCase();

			final rutaDestinoNormalizada = p
				.normalize(File(rutaDestino).absolute.path)
				.toLowerCase();

			if (rutaOrigenNormalizada == rutaDestinoNormalizada) {
				debugPrint(
					'[Anexos] Archivo ya ubicado en destino: '
					'$nombreOriginal',
				);

				transferidos++;
				continue;
			}

			// ----------------------------------------------------
			// EVITAR SOBRESCRIBIR ARCHIVOS
			// ----------------------------------------------------

			int correlativo = 2;

			while (await File(rutaDestino).exists()) {
				nombreDestino =
					'${nombreSinExtension}_$correlativo$extension';

				rutaDestino = p.join(
					carpeta.path,
					nombreDestino,
				);

				correlativo++;
			}

			// ----------------------------------------------------
			// COPIAR ARCHIVO
			// ----------------------------------------------------

			final destino = await archivo.copy(
				rutaDestino,
			);

			if (!await destino.exists()) {
				throw StateError(
					'No se pudo verificar la copia: $rutaDestino',
				);
			}

			// ----------------------------------------------------
			// VERIFICAR TAMAÑO
			// ----------------------------------------------------

			final tamanoOrigen = await archivo.length();

			final tamanoDestino = await destino.length();

			if (tamanoOrigen != tamanoDestino) {
				throw StateError(
					'El archivo copiado tiene un tamaño diferente: '
					'$nombreDestino',
				);
			}

			transferidos++;

			debugPrint(
				'[Anexos] Copiado '
				'($transferidos/${archivosAnexos.length}): '
				'${archivo.path} -> $rutaDestino',
			);
		}

		debugPrint(
			'[Anexos] Transferencia verificada: '
			'$transferidos/${archivosAnexos.length} archivos',
		);
	}

	// ============================================================
	// PROCESAMIENTO ORIGINAL DE ANEXOS
	// ============================================================

	static Future<String?> procesarAnexos({
		required String rutaCarpetaDestino,
		required String nombreArchivoOriginal,
		required String rutaPdfOriginal,
		required List<File> archivosAnexos,
	}) async {
		try {
			final nombreBase = p.basenameWithoutExtension(
				nombreArchivoOriginal,
			);

			final carpetaLocal = Directory(
				p.join(rutaCarpetaDestino, '@$nombreBase'),
			);

			await carpetaLocal.create(recursive: true);

			// ----------------------------------------------------
			// COPIAR DOCUMENTO ORIGINAL
			// ----------------------------------------------------

			final archivoOriginal = File(
				rutaPdfOriginal,
			);

			if (!await archivoOriginal.exists()) {
				throw StateError(
					'El documento original no existe: '
					'$rutaPdfOriginal',
				);
			}

			await archivoOriginal.copy(
				p.join(
					carpetaLocal.path,
					nombreArchivoOriginal,
				),
			);

			// ----------------------------------------------------
			// COPIAR ANEXOS
			// ----------------------------------------------------

			await transferirPendientes(
				rutaCarpetaDestino: rutaCarpetaDestino,
				nombreArchivoOriginal: nombreArchivoOriginal,
				archivosAnexos: archivosAnexos,
			);

			// ----------------------------------------------------
			// CREAR CARPETA COMPARTIDA Y OBTENER URL
			// ----------------------------------------------------

			return await prepararCarpeta(
				rutaCarpetaDestino: rutaCarpetaDestino,
				nombreArchivoOriginal: nombreArchivoOriginal,
			);
		} catch (e) {
			debugPrint(
				'[Anexos] Error procesando anexos: $e',
			);

			return null;
		}
	}
}