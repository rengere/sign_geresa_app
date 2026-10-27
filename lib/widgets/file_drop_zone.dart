import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';


class FileDropZone extends StatefulWidget {
	final double width;
	final double height;
	final void Function(String path, String nombre) onFileDropped;

	const FileDropZone({
		super.key,
		required this.width,
		required this.height,
		required this.onFileDropped,
	});

	@override
	State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
	bool _isDragging = false;

	// Extensiones aceptadas en esta zona de carga. El .doc se deja pasar
	// hasta acá a propósito: es sign_screen.dart quien lo rechaza con un
	// mensaje específico explicando por qué no se puede convertir, en vez
	// de duplicar esa lógica en dos lugares.
	static const _extensionesPermitidas = ['.pdf', '.docx', '.doc'];

	bool _extensionPermitida(String path) {
		final pathMin = path.toLowerCase();
		return _extensionesPermitidas.any((ext) => pathMin.endsWith(ext));
	}

	Future<void> _procesarArchivo(String path) async {
		if (!_extensionPermitida(path)) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Solo se permiten archivos PDF o Word (.docx).')),
				);
			}
			return;
		}

		final archivo = File(path);
		final nombre = path.split(Platform.pathSeparator).last;

		widget.onFileDropped(archivo.path, nombre);
	}

	Future<void> _elegirArchivo() async {
		final resultado = await FilePicker.platform.pickFiles(
			type: FileType.custom,
			allowedExtensions: ['pdf', 'docx', 'doc'],
			withData: true,
		);
		if (resultado == null || resultado.files.single.path == null) {
			return;
		}

		if (!mounted) return;
		widget.onFileDropped(
			resultado.files.single.path!,
			resultado.files.single.name,
		);
	}

	@override
	Widget build(BuildContext context) {
		return DropTarget(
			onDragEntered: (_) => setState(() => _isDragging = true),
			onDragExited: (_) => setState(() => _isDragging = false),
			onDragDone: (details) {
				setState(() => _isDragging = false);
				if (details.files.isNotEmpty) {
					_procesarArchivo(details.files.first.path);
				}
			},
			child: Container(
				width: widget.width,
				height: widget.height,
				decoration: BoxDecoration(
					color: _isDragging ? context.primaryPurple.withValues(alpha: 0.05) : context.surfaceWhite,
					borderRadius: BorderRadius.circular(context.radiusXl),
					border: Border.all(
						color: _isDragging ? context.primaryPurple : context.borderColor,
						width: 2,
					),
					boxShadow: _isDragging ? AppTheme.shadowMd : AppTheme.shadowSm,
				),
				child: Material(
					color: Colors.transparent,
					child: InkWell(
						onTap: _elegirArchivo,
						borderRadius: BorderRadius.circular(context.radiusXl),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Icon(
									_isDragging ? Icons.file_download_outlined : Icons.cloud_upload_outlined,
									size: 64,
									color: _isDragging ? context.primaryPurple : context.textGrey,
								),
								const SizedBox(height: AppTheme.spaceLg),
								Text(
									'Arrastra tu documento (PDF o Word) aquí',
									style: TextStyle(
										fontSize: 18,
										fontWeight: FontWeight.w600,
										color: _isDragging ? context.primaryPurple : context.textDark,
									),
								),
								const SizedBox(height: AppTheme.spaceSm),
								Text(
									'o haz clic para seleccionarlo',
									style: TextStyle(
										fontSize: 14,
										color: context.textGrey,
									),
								),
							],
						),
					),
				),
			),
		);
	}
}