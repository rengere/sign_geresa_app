import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:firmador_geresa/services/nextcloud_api_service.dart';
import 'package:firmador_geresa/services/correlativo_ref_service.dart';

class SesionAnexos {
	final String nombrePdf;
	final String destino;
	final String rutaRemota;
	String? url;
	final Map<String, String> nombresAnexos = {};
	SesionAnexos(this.nombrePdf, this.destino, this.rutaRemota);
}

class AnexosService {
	static Future<SesionAnexos> reservarSesion(String destino, String nombre) async {
		final base = p.basenameWithoutExtension(nombre);
		final inicio = DateTime.now();
		for (int i = 0; i < 60; i++) {
			final ahora = inicio.add(Duration(seconds: i));
			String dos(int n) => n.toString().padLeft(2, '0');
			final marca = '${dos(ahora.day)}-${dos(ahora.month)}-${ahora.year}_${dos(ahora.hour)}-${dos(ahora.minute)}-${dos(ahora.second)}';
			final identificador = await CorrelativoRefService.reservar();
			final carpeta = '${base}_$marca$identificador';
			final nombrePdf = '$carpeta.pdf';
			final remota = '${NextcloudApiService.rutaReferenciales}/$carpeta';
			if (await NextcloudApiService.reservarCarpeta(remota)) {
				return SesionAnexos(nombrePdf, destino, remota);
			}
		}
		throw StateError('No se pudo reservar un nombre único');
	}

	static Future<void> prepararSesion(SesionAnexos sesion) async {
		sesion.url ??= await NextcloudApiService.generarEnlacePublico(sesion.rutaRemota);
		if (sesion.url == null || sesion.url!.trim().isEmpty) throw StateError('No se pudo generar el enlace público');
	}

	static Future<void> reiniciarSesion(SesionAnexos sesion) async {
		// Nextcloud invalida el enlace al eliminar la carpeta compartida.
		await NextcloudApiService.eliminarCarpeta(sesion.rutaRemota);
	}

	static Future<void> transferirPendientes({
		required SesionAnexos sesion,
		required List<File> archivosAnexos,
	}) async {
		if (sesion.url == null) throw StateError('No existe enlace público');
		if (!await NextcloudApiService.existeCarpeta(sesion.rutaRemota)) {
			throw StateError('La carpeta compartida no está disponible');
		}
		for (final archivo in archivosAnexos) {
			final clave = p.normalize(archivo.absolute.path).toLowerCase();
			final nombre = sesion.nombresAnexos.putIfAbsent(clave, () {
				final original = p.basename(archivo.path);
				final usados = sesion.nombresAnexos.values.map((n) => n.toLowerCase()).toSet();
				String candidato = original;
				int i = 2;
				while (usados.contains(candidato.toLowerCase())) {
					candidato = '${p.basenameWithoutExtension(original)}_${i++}${p.extension(original)}';
				}
				return candidato;
			});
			final bytes = await archivo.readAsBytes();
			await NextcloudApiService.subirArchivo('${sesion.rutaRemota}/$nombre', bytes);
			debugPrint('[Anexos] Subida verificada: $nombre');
		}
	}
}
