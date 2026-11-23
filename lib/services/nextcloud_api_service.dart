import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firmador_geresa/data/nxc_access.dart';

class NextcloudApiService {
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
}
