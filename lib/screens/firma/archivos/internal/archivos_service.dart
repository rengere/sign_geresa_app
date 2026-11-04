import 'dart:io';

import 'archivo_pdf.dart';

enum OpcionCompartir { whatsapp, correo, carpeta }

class ArchivosService {
	static const String prefijoEliminado = '[DELETE]';

	String get _sep => Platform.pathSeparator;

	// ==========================================
	// LECTURA
	// ==========================================
	/// Lista los PDF de la carpeta, ignorando los que empiezan con [DELETE].
	Future<List<ArchivoPdf>> listar(String rutaCarpeta) async {
		final dir = Directory(rutaCarpeta);
		if (!await dir.exists()) {
			throw FileSystemException('La carpeta no existe', rutaCarpeta);
		}

		final resultado = <ArchivoPdf>[];
		await for (final entidad in dir.list(followLinks: false)) {
			if (entidad is! File) continue;
			final nombre = entidad.path.split(_sep).last;
			if (!nombre.toLowerCase().endsWith('.pdf')) continue;
			if (nombre.startsWith(prefijoEliminado)) continue;

			final stat = await entidad.stat();
			resultado.add(ArchivoPdf(
				ruta: entidad.path,
				nombre: nombre,
				fecha: stat.modified,
				tamano: stat.size,
			));
		}
		return resultado;
	}

	// ==========================================
	// MODIFICACIÓN
	// ==========================================
	Future<void> renombrar(ArchivoPdf archivo, String nuevoNombre) async {
		final destino = '${archivo.carpeta}$_sep$nuevoNombre';
		if (await File(destino).exists()) {
			throw FileSystemException('Ya existe un archivo con ese nombre', destino);
		}
		await File(archivo.ruta).rename(destino);
	}

	/// "Eliminar": solo antepone [DELETE] al nombre.
	Future<void> marcarEliminado(ArchivoPdf archivo) async {
		var nuevo = '$prefijoEliminado${archivo.nombre}';
		if (await File('${archivo.carpeta}$_sep$nuevo').exists()) {
			nuevo = '$prefijoEliminado${DateTime.now().millisecondsSinceEpoch}_${archivo.nombre}';
		}
		await File(archivo.ruta).rename('${archivo.carpeta}$_sep$nuevo');
	}

	/// "Suprimir": borrado definitivo.
	Future<void> suprimir(ArchivoPdf archivo) async {
		await File(archivo.ruta).delete();
	}

	// ==========================================
	// COPIAS
	// ==========================================
	Future<void> guardarComo(ArchivoPdf archivo, String rutaDestino) async {
		if (rutaDestino == archivo.ruta) return;
		await File(archivo.ruta).copy(rutaDestino);
	}

	/// Copia el archivo a una carpeta sin pisar uno existente: nombre (1).pdf
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

	// ==========================================
	// SISTEMA OPERATIVO
	// ==========================================
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
			// Ruta absoluta y con barras de Windows (\), si no el Explorador
			// ignora la selección y abre una carpeta por defecto.
			final absoluta = File(ruta).absolute.path.replaceAll('/', r'\');

			if (!await File(absoluta).exists()) {
				throw FileSystemException('El archivo ya no existe', absoluta);
			}

			// PowerShell envía /select,"ruta" como un solo argumento, así que
			// funciona con espacios, tildes y corchetes en el nombre.
			final segura = absoluta.replaceAll("'", "''");
			await Process.run('powershell', [
				'-NoProfile',
				'-NonInteractive',
				'-Command',
				"Start-Process explorer.exe -ArgumentList ('/select,\"' + '$segura' + '\"')",
			]);
		} else if (Platform.isMacOS) {
			await _run('open', ['-R', ruta]);
		} else {
			await _run('xdg-open', [File(ruta).parent.path]);
		}
	}

	/// Devuelve el mensaje a mostrar al usuario.
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

	/// Copia ARCHIVOS (no texto) al portapapeles. Solo Windows.
	Future<bool> _copiarAlPortapapeles(List<String> rutas) async {
		if (!Platform.isWindows) return false;
		try {
			final lista = rutas.map((r) => "'${r.replaceAll("'", "''")}'").join(',');
			final r = await Process.run('powershell', [
				'-NoProfile',
				'-NonInteractive',
				'-Command',
				'Set-Clipboard -LiteralPath @($lista)',
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
		} catch (_) {
			// Si la app no está instalada, se ignora
		}
	}

	Future<void> _run(String exe, List<String> args) async {
		final r = await Process.run(exe, args);
		if (r.exitCode != 0) {
			throw ProcessException(exe, args, '${r.stderr}', r.exitCode);
		}
	}
}