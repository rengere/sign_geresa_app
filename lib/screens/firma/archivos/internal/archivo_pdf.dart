import 'dart:io';

enum CampoOrden { nombre, fecha }

class ArchivoPdf {
	final String ruta;
	final String nombre;
	final DateTime fecha;
	final int tamano;

	const ArchivoPdf({
		required this.ruta,
		required this.nombre,
		required this.fecha,
		required this.tamano,
	});

	String get carpeta => File(ruta).parent.path;

	String get nombreSinExtension {
		return nombre.toLowerCase().endsWith('.pdf') ? nombre.substring(0, nombre.length - 4) : nombre;
	}

	/// dd/MM/yyyy HH:mm
	String get fechaTexto => '${_dos(fecha.day)}/${_dos(fecha.month)}/${fecha.year} ${_dos(fecha.hour)}:${_dos(fecha.minute)}';

	/// yyyy-MM-dd (para buscar por "2026-10", etc.)
	String get fechaIso => '${fecha.year}-${_dos(fecha.month)}-${_dos(fecha.day)}';

	String get tamanoTexto => formatearBytes(tamano);

	static String _dos(int n) => n.toString().padLeft(2, '0');
}

String formatearBytes(int bytes) {
	if (bytes < 1024) return '$bytes B';
	final kb = bytes / 1024;
	if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
	final mb = kb / 1024;
	if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
	return '${(mb / 1024).toStringAsFixed(2)} GB';
}