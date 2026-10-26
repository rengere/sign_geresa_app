import 'package:file_selector/file_selector.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

class InputEditable extends StatefulWidget {
	final String label;
	final String initialValue;
	final String? hintText;
	final ValueChanged<String> onSave;
	
	// NUEVO PARÁMETRO: Si es true, muestra el botón para elegir carpeta
	final bool isFolderPath;

	const InputEditable({
		super.key, 
		required this.label,
		required this.initialValue,
		required this.onSave,
		this.hintText,
		this.isFolderPath = false, // Por defecto es falso (texto normal)
	});

	@override
	State<InputEditable> createState() => _InputEditableState();
}

class _InputEditableState extends State<InputEditable> {
	late TextEditingController _controller;
	bool _isEditing = false;

	@override
	void initState() {
		super.initState();
		_controller = TextEditingController(text: widget.initialValue);
	}

	@override
	void didUpdateWidget(covariant InputEditable oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.initialValue != widget.initialValue && !_isEditing) {
			_controller.text = widget.initialValue;
		}
	}

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	void _startEditing() {
		setState(() {
			_isEditing = true;
		});
	}

	void _cancelEditing() {
		setState(() {
			_isEditing = false;
			_controller.text = widget.initialValue;
		});
	}

	void _saveEditing() {
		setState(() {
			_isEditing = false;
		});
		widget.onSave(_controller.text);
	}

	// NUEVA FUNCIÓN: Abre el explorador de carpetas
	Future<void> _seleccionarCarpeta() async {
		final ruta = await getDirectoryPath();
		if (ruta != null) {
			setState(() {
				_controller.text = ruta;
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text(
					widget.label,
					style: TextStyle(
						color: context.textDark,
						fontSize: 14,
						fontWeight: FontWeight.w600,
					),
				),
				const SizedBox(height: 8),

				Row(
					children: [
						Expanded(
							child: MouseRegion(
								cursor: _isEditing ? SystemMouseCursors.text : SystemMouseCursors.basic,
								child: TextField(
									controller: _controller,
									readOnly: !_isEditing,
									canRequestFocus: _isEditing,
									showCursor: _isEditing,
									decoration: InputDecoration(
										hintText: widget.hintText,
										filled: true,
										fillColor: _isEditing ? context.surfaceWhite : context.surfaceGrey,
										contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
										border: OutlineInputBorder(
											borderRadius: BorderRadius.circular(8),
											borderSide: BorderSide(color: context.borderColor),
										),
										enabledBorder: OutlineInputBorder(
											borderRadius: BorderRadius.circular(8),
											borderSide: BorderSide(color: context.borderColor),
										),
										focusedBorder: OutlineInputBorder(
											borderRadius: BorderRadius.circular(8),
											borderSide: BorderSide(color: context.borderColor),
										),
									),
									style: TextStyle(
										color: context.textDark,
										fontSize: 14,
									),
								),
							),
						),
						const SizedBox(width: 12),

						// BOTÓN DE EDITAR (Solo cuando NO se está editando)
						if (!_isEditing)
							IconButton(
								onPressed: _startEditing,
								icon: const Icon(Icons.edit_rounded),
								tooltip: 'Editar',
								color: context.primaryPurple,
								style: IconButton.styleFrom(
									backgroundColor: context.primaryPurple.withOpacity(0.1),
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
								),
							),

						// BOTONES CUANDO SE ESTÁ EDITANDO
						if (_isEditing) ...[
							// NUEVO BOTÓN: Solo aparece si es una ruta de carpeta
							if (widget.isFolderPath) ...[
								IconButton(
									onPressed: _seleccionarCarpeta,
									icon: const Icon(Icons.folder_open_rounded),
									tooltip: 'Seleccionar carpeta',
									color: context.textDark,
									style: IconButton.styleFrom(
										backgroundColor: context.surfaceGrey,
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
										side: BorderSide(color: context.borderColor),
									),
								),
								const SizedBox(width: 8),
							],

							IconButton(
								onPressed: _cancelEditing,
								icon: const Icon(Icons.close_rounded),
								tooltip: 'Cancelar',
								color: context.errorRed,
								style: IconButton.styleFrom(
									backgroundColor: context.errorRed.withOpacity(0.1),
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
								),
							),
							const SizedBox(width: 8),
							IconButton(
								onPressed: _saveEditing,
								icon: const Icon(Icons.check_rounded),
								tooltip: 'Guardar',
								color: context.primaryPurpleLight,
								style: IconButton.styleFrom(
									backgroundColor: context.primaryPurpleLight.withOpacity(0.1),
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
								),
							),
						],
					],
				),
			],
		);
	}
}