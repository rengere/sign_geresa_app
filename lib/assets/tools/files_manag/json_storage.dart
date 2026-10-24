import 'dart:convert';
import 'dart:io';

import 'package:firmador_geresa/assets/tools/files_manag/file_route.dart';


class JsonStorage {
	// Ruta exacta donde se guardará el archivo
	static String get _folderPath => folderPath;
	static const String _fileName = 'data.json';

	// Ruta completa del archivo
	static String get _filePath => '$_folderPath\\$_fileName';

	// Caché en memoria para no leer el disco en cada operación
	static Map<String, dynamic>? _cache;

	// ─────────────────────────────────────────────
	// INICIALIZACIÓN: Crea la carpeta y el archivo si no existen
	// ─────────────────────────────────────────────
	static Future<void> init() async {
		final folder = Directory(_folderPath);
		if (!await folder.exists()) {
			await folder.create(recursive: true);
		}

		final file = File(_filePath);
		if (!await file.exists()) {
			await file.writeAsString(jsonEncode({}));
		}

		// Cargamos los datos en memoria
		_cache = await _readFile();
	}

	// ─────────────────────────────────────────────
	// LEER el archivo desde el disco
	// ─────────────────────────────────────────────
	static Future<Map<String, dynamic>> _readFile() async {
		try {
			final file = File(_filePath);
			if (!await file.exists()) return {};
			
			final content = await file.readAsString();
			if (content.trim().isEmpty) return {};
			
			return jsonDecode(content) as Map<String, dynamic>;
		} catch (e) {
			return {};
		}
	}

	// ─────────────────────────────────────────────
	// GUARDAR el archivo en el disco
	// ─────────────────────────────────────────────
	static Future<void> _writeFile(Map<String, dynamic> data) async {
		final file = File(_filePath);
		await file.writeAsString(jsonEncode(data));
		_cache = data; // Actualizamos la caché
	}

	// ─────────────────────────────────────────────
	// MÉTODOS PÚBLICOS (Simulan SharedPreferences)
	// ─────────────────────────────────────────────

	/// Guarda un String
	static Future<void> setString(String key, String value) async {
		_cache ??= await _readFile();
		_cache![key] = value;
		await _writeFile(_cache!);
	}

	/// Guarda un int
	static Future<void> setInt(String key, int value) async {
		_cache ??= await _readFile();
		_cache![key] = value;
		await _writeFile(_cache!);
	}

	/// Guarda un bool
	static Future<void> setBool(String key, bool value) async {
		_cache ??= await _readFile();
		_cache![key] = value;
		await _writeFile(_cache!);
	}

	/// Guarda cualquier objeto serializable a JSON (List, Map, etc.)
	static Future<void> setJson(String key, dynamic value) async {
		_cache ??= await _readFile();
		_cache![key] = value;
		await _writeFile(_cache!);
	}

	/// Lee un String
	static String? getString(String key) {
		return _cache?[key] as String?;
	}

	/// Lee un int
	static int? getInt(String key) {
		return _cache?[key] as int?;
	}

	/// Lee un bool
	static bool? getBool(String key) {
		return _cache?[key] as bool?;
	}

	/// Lee cualquier objeto JSON (List, Map)
	static dynamic getJson(String key) {
		return _cache?[key];
	}

	/// Elimina una clave
	static Future<void> remove(String key) async {
		_cache ??= await _readFile();
		_cache!.remove(key);
		await _writeFile(_cache!);
	}

	/// Limpia todo el archivo
	static Future<void> clear() async {
		await _writeFile({});
	}
}


// // ── GUARDAR ──
// await JsonStorage.setString('token', 'abc123');
// await JsonStorage.setInt('contador', 5);
// await JsonStorage.setBool('tema_oscuro', false);

// // Guardar una lista de objetos (tu lista de usuarios)
// await JsonStorage.setJson('usuarios', usuarios);

// // ── LEER ──
// final token = JsonStorage.getString('token') ?? '';
// final contador = JsonStorage.getInt('contador') ?? 0;
// final usuarios = JsonStorage.getJson('usuarios') as List? ?? [];

// // ── ELIMINAR ──
// await JsonStorage.remove('token');