import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firmador_geresa/data/nxc_access.dart';

class NextcloudApiService {
	static const String rutaReferenciales = '/GERESA_FIRMA/DocReferenciales';
	static const String _baseUrl = 'https://cloud.diresacusco.gob.pe';

	static String _normalizarRemota(String rutaRemota) {
		final segmentos = rutaRemota.replaceAll('\\', '/')
			.split('/')
			.where((s) => s.isNotEmpty && s != '.')
			.toList();
		if (segmentos.any((s) => s == '..')) {
			throw ArgumentError('Ruta remota inválida: $rutaRemota');
		}
		return '/${segmentos.join('/')}';
	}

	static Uri _urlWebDav(String rutaRemota) {
		final ruta = _normalizarRemota(rutaRemota);
		final segmentos = [
			'remote.php', 'dav', 'files', userNxc,
			...ruta.split('/').where((s) => s.isNotEmpty),
		];
		return Uri.parse(_baseUrl).replace(pathSegments: segmentos);
	}

	static String get _autorizacion =>
		'Basic ${base64Encode(utf8.encode('$userNxc:$passNxc'))}';

	static Future<bool> crearCarpeta(String rutaRemota) async {
		final url = _urlWebDav(rutaRemota);
		debugPrint('DEBUG NEXTCLOUD - MKCOL URL: $url');
		try {
			final request = http.Request('MKCOL', url);
			request.headers['Authorization'] = _autorizacion;
			final streamedResponse = await request.send();
			final response = await http.Response.fromStream(streamedResponse);
			debugPrint('DEBUG NEXTCLOUD - MKCOL Status: ${response.statusCode}');
			return response.statusCode == 201 || response.statusCode == 405;
		} catch (e) {
			debugPrint('[Nextcloud] Error MKCOL: $e');
			return false;
		}
	}

	static Future<bool> existeCarpeta(String rutaRemota) async {
		final url = _urlWebDav(rutaRemota);
		try {
			final request = http.Request('PROPFIND', url);
			request.headers['Authorization'] = _autorizacion;
			request.headers['Depth'] = '0';
			final streamedResponse = await request.send();
			final response = await http.Response.fromStream(streamedResponse);
			debugPrint('DEBUG NEXTCLOUD - PROPFIND Status: ${response.statusCode}');
			return response.statusCode == 207;
		} catch (e) {
			debugPrint('[Nextcloud] Error PROPFIND: $e');
			return false;
		}
	}

	static Future<String?> generarEnlacePublico(String rutaRemota) async {
		final url = Uri.parse('$_baseUrl/ocs/v2.php/apps/files_sharing/api/v1/shares');
		final ruta = _normalizarRemota(rutaRemota);
		debugPrint('DEBUG NEXTCLOUD - Ruta remota enviada: $ruta');
		try {
			final response = await http.post(
				url,
				headers: {
					'Authorization': _autorizacion,
					'OCS-APIRequest': 'true',
					'Content-Type': 'application/x-www-form-urlencoded',
				},
				body: {
					'path': ruta,
					'shareType': '3',
					'permissions': '1',
					'publicUpload': 'false',
				},
			);
			debugPrint('DEBUG NEXTCLOUD - Enlace Status: ${response.statusCode}');
			if (response.statusCode == 200 || response.statusCode == 201) {
				final match = RegExp(r'<url>(.*?)</url>', dotAll: true).firstMatch(response.body);
				if (match != null) return match.group(1);
			}
			debugPrint('[Nextcloud] No se generó enlace: ${response.statusCode} - ${response.body}');
			return null;
		} catch (e) {
			debugPrint('[Nextcloud] Error generando enlace: $e');
			return null;
		}
	}

	// Reserva exclusiva: nunca reutiliza una carpeta existente.
	static Future<bool> reservarCarpeta(String ruta) async {
		final request = http.Request('MKCOL', _urlWebDav(ruta));
		request.headers['Authorization'] = _autorizacion;
		final response = await http.Response.fromStream(await request.send());
		if (response.statusCode == 201) return true;
		if (response.statusCode == 405 && await existeCarpeta(ruta)) return false;
		throw StateError('No se pudo reservar carpeta: ${response.statusCode}');
	}

	static Future<void> eliminarCarpeta(String ruta) async {
		final normalizada = _normalizarRemota(ruta);
		if (!normalizada.startsWith('$rutaReferenciales/') || normalizada.split('/').length != 4) {
			throw ArgumentError('No es una carpeta de anexos');
		}
		if (!await carpetaVacia(ruta)) throw StateError('La carpeta remota contiene archivos o no se pudo comprobar.');
		final response = await http.delete(_urlWebDav(ruta), headers: {'Authorization': _autorizacion}).timeout(const Duration(seconds: 60));
		if (![200, 204, 404].contains(response.statusCode)) {
			throw StateError('Error eliminando carpeta: ${response.statusCode}');
		}
	}
	// Comprueba la carpeta antes de permitir su eliminación.
	static Future<bool> carpetaVacia(String ruta) async {
		final request = http.Request('PROPFIND', _urlWebDav(ruta));
		request.headers.addAll({'Authorization': _autorizacion, 'Depth': '1'});
		final response = await http.Response.fromStream(await request.send()).timeout(const Duration(seconds: 60));
		if (response.statusCode == 404) return true;
		if (response.statusCode != 207) throw StateError('PROPFIND: ${response.statusCode}');
		return RegExp(r'<(?:[\w.-]+:)?response(?:\s[^>]*)?>').allMatches(response.body).length == 1;
	}

	// PUT exclusivo; un reintento solo acepta un archivo idéntico.
	static Future<void> subirArchivo(String ruta, Uint8List bytes) async {
		final url = _urlWebDav(ruta);
		final response = await http.put(url, headers: {
			'Authorization': _autorizacion,
			'Content-Type': 'application/octet-stream',
			'If-None-Match': '*',
		}, body: bytes).timeout(const Duration(minutes: 10));
		if (![200, 201, 204, 412].contains(response.statusCode)) {
			throw StateError('PUT: ${response.statusCode} ($ruta)');
		}
		final comprobacion = await http.get(url, headers: {'Authorization': _autorizacion}).timeout(const Duration(minutes: 10));
		if (comprobacion.statusCode != 200 || !listEquals(comprobacion.bodyBytes, bytes)) {
			throw StateError('No se pudo verificar el contenido remoto: $ruta');
		}
	}
}
