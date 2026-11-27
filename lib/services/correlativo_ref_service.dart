import 'dart:convert';
import 'dart:math';

import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/services/nextcloud_api_service.dart';

class CorrelativoRefService {
	static String obtenerSiglas() {
		final siglas = (JsonStorage.getString('firma_direccion_oficina') ?? '').trim().toUpperCase();
		if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{0,39}$').hasMatch(siglas)) {
			throw StateError('Configura las siglas de oficina (letras A-Z, números, guion o guion bajo; máximo 40 caracteres).');
		}
		return siglas;
	}

	static Future<String> reservar() async {
		final siglas = obtenerSiglas();
		final random = Random();
		for (int intento = 0; intento < 20; intento++) {
			final respuesta = await NextcloudApiService.leerCorrelativos();
			Map<String, dynamic> datos = {};
			String? etag;
			if (respuesta.statusCode == 200) {
				final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
				if (json is! Map<String, dynamic> || json.values.any((v) => v is! int || v < 0)) {
					throw StateError('El archivo de correlativos tiene un formato inválido. No se sobrescribirá.');
				}
				datos = json;
				etag = respuesta.headers['etag'];
				if (etag == null || !etag.startsWith('"') || !etag.endsWith('"')) {
					throw StateError('Nextcloud no devolvió un ETag fuerte para reservar el correlativo.');
				}
			} else if (respuesta.statusCode != 404) {
				throw StateError('Error leyendo correlativos: ${respuesta.statusCode}');
			}
			final siguiente = (datos[siglas] as int? ?? 0) + 1;
			datos[siglas] = siguiente;
			final estado = await NextcloudApiService.escribirCorrelativos(datos, etag: etag);
			if ([200, 201, 204].contains(estado)) {
				return '@ref_${siglas}_${siguiente.toString().padLeft(3, '0')}';
			}
			if (estado != 412 && estado != 423) {
				throw StateError('Error reservando correlativo: $estado');
			}
			await Future<void>.delayed(Duration(milliseconds: 100 + random.nextInt(400)));
		}
		throw StateError('No se pudo reservar el correlativo. Inténtalo nuevamente.');
	}
}
