import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class NextcloudRutasService {
	static Future<String> obtenerRutaRemota(String rutaLocal) async {
		final configuraciones = await _leerSincronizaciones();
		final local = _normalizarLocal(rutaLocal);
		final coincidencias = configuraciones.where((config) {
			final raiz = _normalizarLocal(config.localPath);
			return local == raiz || local.startsWith('$raiz\\');
		}).toList()
			..sort((a, b) => b.localPath.length.compareTo(a.localPath.length));

		if (coincidencias.isEmpty) {
			throw StateError(
				'No se encontró una sincronización Nextcloud Desktop que contenga: '
				'$rutaLocal. Comprueba la configuración de carpetas del cliente.',
			);
		}

		final elegida = coincidencias.first;
		final raiz = _normalizarLocal(elegida.localPath);
		final original = p.windows.normalize(rutaLocal.trim().replaceAll('/', '\\'));
		final resto = local == raiz ? '' : original.substring(raiz.length + 1);
		final segmentos = <String>[
			...elegida.remotePath.split('/').where((s) => s.isNotEmpty),
			...resto.split('\\').where((s) => s.isNotEmpty),
		];
		final resultado = '/${segmentos.join('/')}';
		debugPrint('[Nextcloud rutas] Raíz local: ${elegida.localPath}');
		debugPrint('[Nextcloud rutas] Raíz remota: ${elegida.remotePath}');
		debugPrint('[Nextcloud rutas] Ruta WebDAV: $resultado');
		return resultado;
	}

	static String _normalizarLocal(String ruta) {
		var valor = ruta.trim().replaceAll('/', '\\');
		valor = p.windows.normalize(valor);
		while (valor.endsWith('\\') && !RegExp(r'^[a-zA-Z]:\\$').hasMatch(valor)) {
			valor = valor.substring(0, valor.length - 1);
		}
		return valor.toLowerCase();
	}

	static Future<List<_Sincronizacion>> _leerSincronizaciones() async {
		final appData = Platform.environment['APPDATA'];
		if (appData == null || appData.trim().isEmpty) {
			throw StateError('Windows no proporcionó la variable APPDATA.');
		}
		final archivo = File(p.windows.join(appData, 'Nextcloud', 'nextcloud.cfg'));
		if (!await archivo.exists()) {
			throw StateError('No se encontró la configuración Nextcloud Desktop: ${archivo.path}');
		}
		final lineas = await archivo.readAsLines();
		final secciones = <String, Map<String, String>>{};
		String seccion = '';
		for (final lineaOriginal in lineas) {
			final linea = lineaOriginal.trim();
			if (linea.isEmpty || linea.startsWith('#') || linea.startsWith(';')) continue;
			if (linea.startsWith('[') && linea.endsWith(']')) {
				seccion = linea.substring(1, linea.length - 1).toLowerCase();
				secciones.putIfAbsent(seccion, () => {});
				continue;
			}
			final separador = linea.indexOf('=');
			if (separador < 1) continue;
			secciones.putIfAbsent(seccion, () => {})[
				linea.substring(0, separador).trim().toLowerCase()
			] = linea.substring(separador + 1).trim();
		}

		final sincronizaciones = <_Sincronizacion>[];
		for (final entrada in secciones.entries) {
			final mapa = entrada.value;
			final grupos = <String, Map<String, String>>{};
			for (final item in mapa.entries) {
				final clave = item.key.replaceAll('/', r'\');
				final match = RegExp(r'^(.*)\\(localpath|targetpath)$').firstMatch(clave);
				if (match == null) continue;
				final grupo = match.group(1)!;
				final campo = match.group(2)!;
				grupos.putIfAbsent(grupo, () => {})[campo] = item.value;
			}
			for (final grupo in grupos.values) {
				final local = grupo['localpath'];
				final remoto = grupo['targetpath'];
				if (local != null && local.trim().isNotEmpty && remoto != null) {
					sincronizaciones.add(_Sincronizacion(local, remoto));
				}
			}
			final local = mapa['localpath'];
			final remoto = mapa['targetpath'];
			if (local != null && local.trim().isNotEmpty && remoto != null) {
				sincronizaciones.add(_Sincronizacion(local, remoto));
			}
		}
		if (sincronizaciones.isEmpty) {
			throw StateError(
				'No se encontraron pares localPath/targetPath en ${archivo.path}. '
				'Es necesario revisar el formato de configuración de esta versión de Nextcloud Desktop.',
			);
		}
		return sincronizaciones;
	}
}

class _Sincronizacion {
	final String localPath;
	final String remotePath;
	const _Sincronizacion(this.localPath, this.remotePath);
}
