import 'dart:io';
import 'dart:convert'; // <-- NUEVO
import 'package:path/path.dart' as p; // <-- NUEVO
import 'package:flutter/foundation.dart'; // <-- NUEVO

import 'archivo_pdf.dart';
import 'package:printing/printing.dart';

enum OpcionCompartir { whatsapp, correo, carpeta }

class ArchivosService {
	static const String prefijoEliminado = '[DELETE]';
	static const String prefijoFirmado = '[SIGN]';

	String get _sep => Platform.pathSeparator;

	Future<Map<String, dynamic>> _leerNotas(String carpeta) async {
		final archivo = File(p.join(carpeta, 'notes.json'));
		try {
			if (await archivo.exists()) {
				return jsonDecode(await archivo.readAsString()) as Map<String, dynamic>;
			}
		} catch (e) {
			debugPrint('Error leyendo notes.json: $e');
		}
		return {};
	}

	Future<ArchivoPdf> _crearArchivoPdf(File archivo, Map<String, dynamic> notas, {bool esCompartido = false}) async {
		final nombre = p.basename(archivo.path);
		final stat = await archivo.stat();
		final listaNotas = notas[nombre];
		return ArchivoPdf(
			ruta: archivo.path,
			nombre: nombre,
			fecha: stat.modified,
			tamano: stat.size,
			tieneNotas: listaNotas is List && listaNotas.any((nota) => nota is Map && nota['oculta'] != true),
			esCompartido: esCompartido,
		);
	}

	Future<List<ArchivoPdf>> listar(String rutaCarpeta) async {
		final dir = Directory(rutaCarpeta);
		if (!await dir.exists()) {
			throw FileSystemException('La carpeta no existe', rutaCarpeta);
		}

		final notasRaiz = await _leerNotas(rutaCarpeta);
		final resultado = <ArchivoPdf>[];
		await for (final entidad in dir.list(followLinks: false)) {
			final nombre = p.basename(entidad.path);
			if (nombre.startsWith(prefijoEliminado) || nombre.startsWith(prefijoFirmado)) continue;
			if (entidad is File && nombre.toLowerCase().endsWith('.pdf')) {
				resultado.add(await _crearArchivoPdf(entidad, notasRaiz));
			} else if (entidad is Directory && nombre.startsWith('@') && nombre.length > 1) {
				// Solo buscar el documento principal, nunca listar los referenciales.
				final esperado = '${nombre.substring(1)}.pdf';
				try {
					final candidatos = <File>[];
					await for (final interno in entidad.list(followLinks: false)) {
						if (interno is File && p.basename(interno.path).toLowerCase() == esperado.toLowerCase()) {
							candidatos.add(interno);
						}
					}
					// Si hay ambigüedad, no elegir un referencial por error.
					if (candidatos.length != 1) continue;
					final notas = await _leerNotas(entidad.path);
					resultado.add(await _crearArchivoPdf(candidatos.single, notas, esCompartido: true));
				} catch (e) {
					debugPrint('Error leyendo carpeta compartida ${entidad.path}: $e');
				}
			}
		}
		return resultado;
	}

	// ... (El resto del archivo se mantiene exactamente igual)
	Future<void> renombrar(ArchivoPdf archivo, String nuevoNombre) async {
		if (archivo.esCompartido) {
			throw FileSystemException('No se puede renombrar un documento de una carpeta compartida', archivo.ruta);
		}
		final destino = '${archivo.carpeta}$_sep$nuevoNombre';
		if (await File(destino).exists()) {
			throw FileSystemException('Ya existe un archivo con ese nombre', destino);
		}
		await File(archivo.ruta).rename(destino);
	}

	Future<void> marcarEliminado(ArchivoPdf archivo) async {
		var nuevo = '$prefijoEliminado${archivo.nombre}';
		if (await File('${archivo.carpeta}$_sep$nuevo').exists()) {
			nuevo = '$prefijoEliminado${DateTime.now().millisecondsSinceEpoch}_${archivo.nombre}';
		}
		await File(archivo.ruta).rename('${archivo.carpeta}$_sep$nuevo');
	}

	Future<void> marcarFirmado(ArchivoPdf archivo) async {
		final origen = File(archivo.ruta);
		if (archivo.nombre.startsWith(prefijoFirmado)) return;
		var destino = p.join(archivo.carpeta, '$prefijoFirmado${archivo.nombre}');
		var i = 1;
		while (await FileSystemEntity.type(destino) != FileSystemEntityType.notFound) {
			destino = p.join(archivo.carpeta, '$prefijoFirmado${i++}_${archivo.nombre}');
		}
		await origen.rename(destino);
	}

	Future<void> suprimir(ArchivoPdf archivo) async {
		await File(archivo.ruta).delete();
	}

	Future<void> guardarComo(ArchivoPdf archivo, String rutaDestino) async {
		if (rutaDestino == archivo.ruta) return;
		await File(archivo.ruta).copy(rutaDestino);
	}

	Future<String> copiarACarpeta(ArchivoPdf archivo, String carpetaDestino) async {
		var destino = '$carpetaDestino$_sep${archivo.nombre}';
		var i = 1;
		while (await File(destino).exists()) {
			destino = '$carpetaDestino$_sep${archivo.nombreSinExtension} ($i).pdf';
			i++;
		}
		await File(archivo.ruta).copy(destino);
		return destino;
	}

	Future<void> abrirPredeterminado(String ruta) async {
		if (Platform.isWindows) {
			await _run('rundll32', ['url.dll,FileProtocolHandler', ruta]);
		} else if (Platform.isMacOS) {
			await _run('open', [ruta]);
		} else {
			await _run('xdg-open', [ruta]);
		}
	}

	Future<void> mostrarEnCarpeta(String ruta) async {
		if (Platform.isWindows) {
			final absoluta = File(ruta).absolute.path.replaceAll('/', r'\');
			if (!await File(absoluta).exists()) {
				throw FileSystemException('El archivo ya no existe', absoluta);
			}
			final segura = absoluta.replaceAll("'", "''");
			await Process.run('powershell', [
				'-NoProfile', '-NonInteractive', '-Command',
				"Start-Process explorer.exe -ArgumentList ('/select,\"' + '$segura' + '\"')",
			]);
		} else if (Platform.isMacOS) {
			await _run('open', ['-R', ruta]);
		} else {
			await _run('xdg-open', [File(ruta).parent.path]);
		}
	}

	Future<String> compartir(OpcionCompartir opcion, List<ArchivoPdf> archivos) async {
		final rutas = archivos.map((a) => a.ruta).toList();
		switch (opcion) {
			case OpcionCompartir.carpeta:
				await mostrarEnCarpeta(rutas.first);
				return 'Carpeta abierta: arrastra el archivo donde lo necesites';
			case OpcionCompartir.whatsapp:
				final copiado = await _copiarAlPortapapeles(rutas);
				await _abrirUrl('whatsapp://');
				if (copiado) return 'Archivo(s) copiado(s). Pégalo(s) con Ctrl+V en el chat de WhatsApp';
				await mostrarEnCarpeta(rutas.first);
				return 'Arrastra el archivo al chat de WhatsApp';
			case OpcionCompartir.correo:
				final copiado = await _copiarAlPortapapeles(rutas);
				await _abrirUrl('mailto:?subject=Documentos');
				if (copiado) return 'Archivo(s) copiado(s). Pégalo(s) con Ctrl+V en el correo';
				await mostrarEnCarpeta(rutas.first);
				return 'Arrastra el archivo al correo como adjunto';
		}
	}

	Future<bool> _copiarAlPortapapeles(List<String> rutas) async {
		if (!Platform.isWindows) return false;
		try {
			final lista = rutas.map((r) => "'${r.replaceAll("'", "''")}'").join(',');
			final r = await Process.run('powershell', [
				'-NoProfile', '-NonInteractive', '-Command', 'Set-Clipboard -LiteralPath @($lista)',
			]);
			return r.exitCode == 0;
		} catch (_) {
			return false;
		}
	}

	Future<void> _abrirUrl(String url) async {
		try {
			if (Platform.isWindows) {
				await Process.run('cmd', ['/c', 'start', '', url]);
			} else if (Platform.isMacOS) {
				await Process.run('open', [url]);
			} else {
				await Process.run('xdg-open', [url]);
			}
		} catch (_) {}
	}

	Future<void> _run(String exe, List<String> args) async {
		final r = await Process.run(exe, args);
		if (r.exitCode != 0) {
			throw ProcessException(exe, args, '${r.stderr}', r.exitCode);
		}
	}

	Future<void> imprimir(String ruta) async {
		final bytes = await File(ruta).readAsBytes();
		await Printing.layoutPdf(onLayout: (format) async => bytes);
	}
}