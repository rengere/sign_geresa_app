import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

class Nota {
	final String id;
	final String texto;
	final int pagina;
	final double x;
	final double y;
	final bool oculta;

	Nota({
		required this.id,
		required this.texto,
		required this.pagina,
		required this.x,
		required this.y,
		this.oculta = false,
	});

	Map<String, dynamic> toJson() => {
		'id': id,
		'texto': texto,
		'pagina': pagina,
		'x': x,
		'y': y,
		'oculta': oculta,
	};

	factory Nota.fromJson(Map<String, dynamic> json) => Nota(
		id: json['id'] ?? '',
		texto: json['texto'] ?? '',
		pagina: json['pagina'] ?? 1,
		x: (json['x'] ?? 0.0).toDouble(),
		y: (json['y'] ?? 0.0).toDouble(),
		oculta: json['oculta'] ?? false,
	);
}

class NotasService {
	/// Obtiene la ruta del archivo notes.json en la misma carpeta del PDF
	static String _rutaJson(String rutaPdf) {
		final carpeta = p.dirname(rutaPdf);
		return p.join(carpeta, 'notes.json');
	}

	/// Carga todas las notas de un PDF específico
	static Future<List<Nota>> cargarNotas(String rutaPdf) async {
		final file = File(_rutaJson(rutaPdf));
		if (!await file.exists()) return [];

		try {
			final content = await file.readAsString();
			final Map<String, dynamic> data = jsonDecode(content);
			final nombreArchivo = p.basename(rutaPdf);

			if (data.containsKey(nombreArchivo)) {
				final List<dynamic> lista = data[nombreArchivo];
				return lista.map((e) => Nota.fromJson(e as Map<String, dynamic>)).toList();
			}
		} catch (e) {
			print('Error al cargar notas: $e');
		}
		return [];
	}

	/// Guarda todas las notas de un PDF específico
	static Future<void> guardarNotas(String rutaPdf, List<Nota> notas) async {
		final file = File(_rutaJson(rutaPdf));
		Map<String, dynamic> data = {};

		if (await file.exists()) {
			try {
				final content = await file.readAsString();
				data = jsonDecode(content) as Map<String, dynamic>;
			} catch (_) {}
		}

		final nombreArchivo = p.basename(rutaPdf);
		data[nombreArchivo] = notas.map((n) => n.toJson()).toList();

		await file.writeAsString(jsonEncode(data));
	}
}