import 'package:firmador_geresa/assets/tools/fns/uppercase_text.dart';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/widgets/forms/input_editable.dart';
import 'package:flutter/services.dart';

class BoxFirmaGeresa extends StatefulWidget {
	const BoxFirmaGeresa({super.key});

	@override
	State<BoxFirmaGeresa> createState() => _BoxFirmaGeresaState();
}

class _BoxFirmaGeresaState extends State<BoxFirmaGeresa> {
	static const List<String> _motivosPredeterminados = [
		'Soy el autor del documento',
		'Señal de conformidad',
		'Por encargo',
	];

	List<String> _motivosExtra = [];
	List<String> _cargos = [];
	
	String _motivoSeleccionado = _motivosPredeterminados.first;
	String? _cargoSeleccionado;

	@override
	void initState() {
		super.initState();
		_cargarDatos();
	}

	void _cargarDatos() {
		_motivosExtra = (JsonStorage.getJson('firma_motivos_extra') as List?)?.cast<String>() ?? [];
		_cargos = (JsonStorage.getJson('firma_cargos') as List?)?.cast<String>() ?? [];
		
		final motivoGuardado = JsonStorage.getString('firma_motivo_activo');
		if (motivoGuardado != null && (_motivosPredeterminados.contains(motivoGuardado) || _motivosExtra.contains(motivoGuardado))) {
			_motivoSeleccionado = motivoGuardado;
		} else {
			_motivoSeleccionado = _motivosPredeterminados.first;
		}

		final cargoGuardado = JsonStorage.getString('firma_cargo_activo');
		if (cargoGuardado != null && _cargos.contains(cargoGuardado)) {
			_cargoSeleccionado = cargoGuardado;
		} else if (_cargos.isNotEmpty) {
			_cargoSeleccionado = _cargos.first;
		}
	}

	Future<void> _mostrarPopupAgregar({required bool isMotivo}) async {
		final TextEditingController ctrl = TextEditingController();
		final String tipo = isMotivo ? 'Motivo' : 'Cargo';

		final result = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
				title: Text('Añadir nuevo $tipo'),
				content: TextField(
					controller: ctrl,
					autofocus: true,
					maxLength: 30,
					decoration: InputDecoration(
						hintText: 'Escribe el $tipo...',
						border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
					),
				),
				actions: [
					IconButton(
						onPressed: () => Navigator.pop(ctx, false),
						icon: const Icon(Icons.close_rounded, color: Colors.red),
						tooltip: 'Cancelar',
					),
					IconButton(
						onPressed: () {
							if (ctrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
						},
						icon: Icon(Icons.check_rounded, color: ctx.primaryPurple),
						tooltip: 'Confirmar',
					),
				],
			),
		);

		if (result == true && ctrl.text.trim().isNotEmpty) {
			final txt = ctrl.text.trim();
			setState(() {
				if (isMotivo) {
					_motivosExtra.add(txt);
					JsonStorage.setJson('firma_motivos_extra', _motivosExtra);
					_motivoSeleccionado = txt;
					JsonStorage.setString('firma_motivo_activo', txt);
				} else {
					_cargos.add(txt);
					JsonStorage.setJson('firma_cargos', _cargos);
					_cargoSeleccionado = txt;
					JsonStorage.setString('firma_cargo_activo', txt);
				}
			});
		}
	}

	Widget _buildDropdownStyle({
		required String label, 
		required String? value, 
		required List<String> items, 
		required ValueChanged<String?> onChanged,
		required bool isMotivo,
		required Function(String) onDelete,
		required VoidCallback onAdd,
	}) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text(
					label,
					style: TextStyle(color: context.textDark, fontSize: 14, fontWeight: FontWeight.w600),
				),
				const SizedBox(height: 8),
				Row(
					children: [
						Expanded(
							child: DropdownButtonFormField<String>(
								value: value,
								isExpanded: true,
								decoration: InputDecoration(
									filled: true,
									fillColor: context.surfaceGrey,
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
								items: items.map((m) {
									final isPredeterminado = isMotivo && _motivosPredeterminados.contains(m);
									return DropdownMenuItem(
										value: m,
										child: Row(
											mainAxisAlignment: MainAxisAlignment.spaceBetween,
											children: [
												Expanded(child: Text(m, overflow: TextOverflow.ellipsis)),
												if (!isPredeterminado)
													IconButton(
														icon: const Icon(Icons.close, size: 16, color: Colors.red),
														onPressed: () => onDelete(m),
														padding: EdgeInsets.zero,
														constraints: const BoxConstraints(),
													),
											],
										),
									);
								}).toList(),
								onChanged: onChanged,
							),
						),
						const SizedBox(width: 12),
						IconButton(
							onPressed: onAdd,
							icon: const Icon(Icons.add),
							color: context.primaryPurple,
							style: IconButton.styleFrom(
								backgroundColor: context.primaryPurple.withOpacity(0.1),
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
							),
						),
					],
				),
			],
		);
	}

	@override
	Widget build(BuildContext context) {
		final todosLosMotivos = [..._motivosPredeterminados, ..._motivosExtra];

		// Forzamos el fondo blanco con Container y mantenemos tu padding original
		return Container(
			color: context.surfaceWhite,
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Expanded(
						child: SingleChildScrollView(
							// Tu padding original (el único)
							padding: const EdgeInsets.only(left: 32, top: 0, right: 32, bottom: 32),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									// 1. MOTIVO DE FIRMA
									_buildDropdownStyle(
										label: 'Motivo de firma',
										value: _motivoSeleccionado,
										items: todosLosMotivos,
										isMotivo: true,
										onDelete: (m) async {
											setState(() {
												_motivosExtra.remove(m);
												if (_motivoSeleccionado == m) {
													_motivoSeleccionado = _motivosPredeterminados.first;
													JsonStorage.setString('firma_motivo_activo', _motivoSeleccionado);
												}
											});
											await JsonStorage.setJson('firma_motivos_extra', _motivosExtra);
										},
										onAdd: () => _mostrarPopupAgregar(isMotivo: true),
										onChanged: (val) {
											if (val != null) {
												setState(() => _motivoSeleccionado = val);
												JsonStorage.setString('firma_motivo_activo', val); 
											}
										},
									),

									const SizedBox(height: 32),

									// 2. CARGOS
									_buildDropdownStyle(
										label: 'Cargos',
										value: _cargoSeleccionado,
										items: _cargos,
										isMotivo: false, 
										onDelete: (c) async {
											setState(() {
												_cargos.remove(c);
												if (_cargoSeleccionado == c) {
													_cargoSeleccionado = _cargos.isNotEmpty ? _cargos.first : null;
													JsonStorage.setString('firma_cargo_activo', _cargoSeleccionado ?? '');
												}
											});
											await JsonStorage.setJson('firma_cargos', _cargos);
										},
										onAdd: () => _mostrarPopupAgregar(isMotivo: false),
										onChanged: (val) {
											if (val != null) {
												setState(() => _cargoSeleccionado = val);
												JsonStorage.setString('firma_cargo_activo', val); 
											}
										},
									),

									const SizedBox(height: 32),

									// 3. SUFIJO
									InputEditable(
										label: 'Sufijo de la firma',
										initialValue: JsonStorage.getString('firma_sufijo') ?? 'FG',
										hintText: 'Máximo 3 letras (Ej. FG)',
										isFolderPath: false,
										maxLength: 3,
										inputFormatters: [
											FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
											UpperCaseTextFormatter(),
										],
										onSave: (val) async {
											final finalVal = val.trim().isEmpty ? 'FG' : val.trim().toUpperCase();
											await JsonStorage.setString('firma_sufijo', finalVal);
										},
									),
								],
							),
						),
					),
				],
			),
		);
	}
}