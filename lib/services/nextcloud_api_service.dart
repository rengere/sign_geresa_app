import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firmador_geresa/data/nxc_access.dart';

class NextcloudApiService {
	static const String _baseUrl = 'https://cloud.diresacusco.gob.pe';

	/// Crea una carpeta en Nextcloud (WebDAV) usando MKCOL
	static Future<bool> crearCarpeta(String rutaRemota) async {
		final url = Uri.parse('$_baseUrl/remote.php/dav/files/$userNxc/$rutaRemota');
		print('DEBUG NEXTCLOUD - MKCOL URL: $url'); // <-- DEBUG
		try {
			final request = http.Request('MKCOL', url);
			request.headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('$userNxc:$passNxc'))}';
			
			final streamedResponse = await request.send();
			final response = await http.Response.fromStream(streamedResponse);
			
			print('DEBUG NEXTCLOUD - MKCOL Status: ${response.statusCode}'); // <-- DEBUG
			
			return response.statusCode == 201 || response.statusCode == 405;
		} catch (e) {
			print('Error al crear carpeta en Nextcloud: $e');
			return false;
		}
	}

	/// Genera un enlace público de solo lectura (OCS API)
	static Future<String?> generarEnlacePublico(String rutaRemota) async {
		final url = Uri.parse('$_baseUrl/ocs/v2.php/apps/files_sharing/api/v1/shares');
		print('DEBUG NEXTCLOUD - Enlace URL: $url'); // <-- DEBUG
		print('DEBUG NEXTCLOUD - Ruta remota enviada: $rutaRemota'); // <-- DEBUG
		
		try {
			final response = await http.post(
				url,
				headers: {
					'Authorization': 'Basic ${base64Encode(utf8.encode('$userNxc:$passNxc'))}',
					'OCS-APIRequest': 'true',
					'Content-Type': 'application/x-www-form-urlencoded',
				},
				body: {
					'path': rutaRemota,
					'shareType': '3',
					'permissions': '1',
					'publicUpload': 'false',
				},
			);

			print('DEBUG NEXTCLOUD - Enlace Status: ${response.statusCode}'); // <-- DEBUG
			
			if (response.statusCode == 200) {
				final regex = RegExp(r'<url>(.*?)<\/url>');
				final match = regex.firstMatch(response.body);
				if (match != null) {
					return match.group(1);
				}
			}
			print('Error al generar enlace: ${response.statusCode} - ${response.body}');
			return null;
		} catch (e) {
			print('Error de red al generar enlace: $e');
			return null;
		}
	}
}