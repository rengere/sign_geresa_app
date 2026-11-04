// FUERA DE RUTA ACTUALMENTE


import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BotonCopiarProyectado extends StatefulWidget {
	final String rutaDestino;
	final VoidCallback onArchivoCopiado; // Para avisarle al padre que recargue la tabla

	const BotonCopiarProyectado({
		super.key,
		required this.rutaDestino,
		required this.onArchivoCopiado,
	});

	@override
	State<BotonCopiarProyectado> createState() => _BotonCopiarProyectadoState();
}

class _BotonCopiarProyectadoState extends State<BotonCopiarProyectado> {
	bool _copiando = false;

	Future<void> _seleccionarYCopiar() async {
		final result = await FilePicker.platform.pickFiles(
			dialogTitle: 'Seleccionar documento para proyectar',
			type: FileType.custom,
			allowedExtensions: ['pdf'],
		);

		if (result == null || result.files.single.path == null) return;

		setState(() => _copiando = true);

		final archivoOrigen = result.files.single.path!;
		final nombreArchivo = result.files.single.name;

		try {
			final rutaFinal = '${widget.rutaDestino}${Platform.pathSeparator}$nombreArchivo';
			await File(archivoOrigen).copy(rutaFinal);
			
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: const Text('Archivo copiado a proyectados'),
						backgroundColor: context.textDark,
						behavior: SnackBarBehavior.floating,
					),
				);
				widget.onArchivoCopiado(); // Recarga la tabla
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('Error al copiar: $e'),
						backgroundColor: context.errorRed,
						behavior: SnackBarBehavior.floating,
					),
				);
			}
		} finally {
			if (mounted) setState(() => _copiando = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return ElevatedButton.icon(
			onPressed: _copiando ? null : _seleccionarYCopiar,
			icon: _copiando 
				? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
				: const Icon(Icons.file_copy_rounded, size: 18),
			label: Text(_copiando ? 'Copiando...' : 'Copiar PDF aquí'),
			style: ElevatedButton.styleFrom(
				backgroundColor: context.primaryPurple,
				foregroundColor: Colors.white,
				padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(context.radiusMd),
				),
			),
		);
	}
}