import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Cliente del backend local (Java) que corre en http://127.0.0.1:8426
class ApiService {
	static const String baseUrl = 'http://127.0.0.1:8426';

	/// Firma el PDF con el PIN del DNIe. Devuelve los bytes del PDF firmado.
	Future<Uint8List> firmar({
		required Uint8List pdfBytes,
		required String nombreArchivo,
		required String pin,
	}) async {
		final uri = Uri.parse('$baseUrl/firmar');
		final request = http.MultipartRequest('POST', uri)
			..fields['pin'] = pin
			..files.add(
				http.MultipartFile.fromBytes('pdf', pdfBytes, filename: nombreArchivo),
			);

		final streamed = await request.send();
		final res = await http.Response.fromStream(streamed);

		if (res.statusCode != 200) {
			throw Exception(_detalle(res));
		}
		return res.bodyBytes;
	}

	/// Verifica las firmas de un PDF. Devuelve la respuesta JSON cruda tal
	/// como la entrega el backend (la misma que se ve al probar con curl).
	Future<Map<String, dynamic>> verificar({
		required Uint8List pdfBytes,
		required String nombreArchivo,
	}) async {
		final uri = Uri.parse('$baseUrl/verificar');
		final request = http.MultipartRequest('POST', uri)
			..files.add(
				http.MultipartFile.fromBytes('pdf', pdfBytes, filename: nombreArchivo),
			);

		final streamed = await request.send();
		final res = await http.Response.fromStream(streamed);

		if (res.statusCode != 200) {
			throw Exception(_detalle(res));
		}
		return jsonDecode(res.body) as Map<String, dynamic>;
	}

	String _detalle(http.Response res) {
		try {
			final cuerpo = jsonDecode(res.body);
			return cuerpo['detail']?.toString() ?? 'Error desconocido (${res.statusCode})';
		} catch (_) {
			return 'Error desconocido (${res.statusCode})';
		}
	}
}


class TitularCertificado {
	final String nombre;
	final String dni;

	TitularCertificado({
		required this.nombre,
		required this.dni,
	});
}

extension ApiServiceTitular on ApiService {
	/// Obtiene los datos del titular del certificado desde el lector del DNIe.
	Future<TitularCertificado> obtenerTitular() async {
		final uri = Uri.parse('${ApiService.baseUrl}/lector/titular');
		final res = await http.get(uri);

		if (res.statusCode != 200) {
			throw Exception('No se pudo leer el certificado. Verifica que el DNIe esté insertado.');
		}

		final json = jsonDecode(res.body) as Map<String, dynamic>;
		final sujeto = json['sujeto']?.toString() ?? '';

		// Parseo básico del DN X.509
		String nombreCompleto = 'Desconocido';
		String dni = '00000000';

		final matchCN = RegExp(r'CN=([^,]+)').firstMatch(sujeto);
		if (matchCN != null) {
			final cn = matchCN.group(1)!;
			final matchDni = RegExp(r'FIR\s+(\d+)').firstMatch(cn);
			if (matchDni != null) {
				dni = matchDni.group(1)!;
			}
		}

		final matchApellido = RegExp(r'2\.5\.4\.4=#0c0c([0-9a-fA-F]+)').firstMatch(sujeto);
		final matchNombre = RegExp(r'2\.5\.4\.42=#0c0c([0-9a-fA-F]+)').firstMatch(sujeto);

		String apellidos = '';
		String nombres = '';

		if (matchApellido != null) {
			final hex = matchApellido.group(1)!;
			try {
				apellidos = utf8.decode(hexToBytes(hex));
			} catch (_) {}
		}

		if (matchNombre != null) {
			final hex = matchNombre.group(1)!;
			try {
				nombres = utf8.decode(hexToBytes(hex));
			} catch (_) {}
		}

		if (apellidos.isNotEmpty && nombres.isNotEmpty) {
			nombreCompleto = '$apellidos $nombres';
		} else if (matchCN != null) {
			// Fallback: limpiar el CN si no se pudo parsear el hex
			nombreCompleto = matchCN.group(1)!.replaceAll(RegExp(r'\s+FIR.*$'), '').trim();
		}

		return TitularCertificado(
			nombre: nombreCompleto,
			dni: dni,
		);
	}

	List<int> hexToBytes(String hex) {
		final result = <int>[];
		for (int i = 0; i < hex.length; i += 2) {
			result.add(int.parse(hex.substring(i, i + 2), radix: 16));
		}
		return result;
	}
}


extension ApiServiceDocumentos on ApiService {
	/// Convierte un documento Word (.docx) a PDF usando el endpoint del
	/// signer. Devuelve los bytes del PDF resultante.
	Future<Uint8List> convertirWordAPdf({
		required Uint8List docxBytes,
		required String nombreArchivo,
	}) async {
		final uri = Uri.parse('${ApiService.baseUrl}/convertir/word-a-pdf');
		final request = http.MultipartRequest('POST', uri)
			..files.add(
				http.MultipartFile.fromBytes('archivo', docxBytes, filename: nombreArchivo),
			);

		final streamed = await request.send();
		final res = await http.Response.fromStream(streamed);

		if (res.statusCode != 200) {
			String detalle;
			try {
				final cuerpo = jsonDecode(res.body);
				detalle = cuerpo['detail']?.toString() ?? 'Error desconocido (${res.statusCode})';
			} catch (_) {
				detalle = 'Error desconocido (${res.statusCode})';
			}
			throw Exception(detalle);
		}
		return res.bodyBytes;
	}
}