import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';


class FileDropZone extends StatefulWidget {
	final double width;
	final double height;
	final String titulo;
	final String subtitulo;
	final double? tamanoMaximoMB;
	final List<String> formatosPermitidos;
	final void Function(String path, String nombre) onFileDropped;

	const FileDropZone({
		super.key,
		required this.width,
		required this.height,
		required this.titulo,
		required this.subtitulo,
		this.tamanoMaximoMB,
		required this.formatosPermitidos,
		required this.onFileDropped,
	}) : assert(tamanoMaximoMB == null || tamanoMaximoMB > 0),
		assert(formatosPermitidos.length > 0);

	@override
	State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
	bool _isDragging = false;
	int? get _tamanoMaximo {
		final limite = widget.tamanoMaximoMB;
		return limite == null ? null : (limite * 1024 * 1024).floor();
	}

	List<String> get _extensionesPermitidas => widget.formatosPermitidos
		.map((ext) => ext.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), ''))
		.where((ext) => ext.isNotEmpty)
		.toSet()
		.toList();

	String get _limiteTexto => widget.tamanoMaximoMB.toString().replaceFirst(RegExp(r'\.0$'), '');

	bool _extensionPermitida(String path) {
		final pathMin = path.toLowerCase();
		return _extensionesPermitidas.any((ext) => pathMin.endsWith('.$ext'));
	}

	Future<void> _procesarArchivo(String path) async {
		if (!_extensionPermitida(path)) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Formatos permitidos: ${_extensionesPermitidas.join(", ")}.')),
				);
			}
			return;
		}

		final archivo = File(path);
		final nombre = path.split(Platform.pathSeparator).last;

		final limite = _tamanoMaximo;
		if (limite != null) {
			try {
				final tamano = await archivo.length();
				if (!mounted) return;

				if (tamano > limite) {
					final tamanoMb = (tamano / (1024 * 1024)).toStringAsFixed(2);
					ScaffoldMessenger.of(context).showSnackBar(
						SnackBar(content: Text('El documento pesa $tamanoMb MB. El tamaño máximo permitido es de $_limiteTexto MB.')),
					);
					return;
				}
			} catch (e) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(content: Text('No se pudo comprobar el tamaño del documento.')),
					);
				}
				return;
			}
		}

		if (!mounted) return;
		widget.onFileDropped(archivo.path, nombre);
	}

	Future<void> _elegirArchivo() async {
		final resultado = await FilePicker.platform.pickFiles(
			type: FileType.custom,
			allowedExtensions: _extensionesPermitidas,
			withData: false,
		);
		if (resultado == null || resultado.files.single.path == null) {
			return;
		}

		if (!mounted) return;
		await _procesarArchivo(resultado.files.single.path!);
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
									widget.titulo,
									style: TextStyle(
										fontSize: 18,
										fontWeight: FontWeight.w600,
										color: _isDragging ? context.primaryPurple : context.textDark,
									),
								),
								const SizedBox(height: AppTheme.spaceSm),
								Text(
									widget.subtitulo,
									style: TextStyle(
										fontSize: 14,
										color: context.textGrey,
									),
								),
								if (widget.tamanoMaximoMB != null) ...[
									const SizedBox(height: AppTheme.spaceSm),
									Text(
										'Tamaño máximo: $_limiteTexto MB',
										style: TextStyle(fontSize: 12, color: context.textGrey),
									),
								],
							],
						),
					),
				),
			),
		);
	}
}