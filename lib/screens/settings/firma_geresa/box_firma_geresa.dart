import 'package:firmador_geresa/assets/tools/fns/uppercase_text.dart';
import 'package:firmador_geresa/data/motivo_firma.dart';
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
	// Listas para Firma
	List<String> _motivosExtra = [];
	List<String> _cargos = [];
	String _motivoSeleccionado = motivosFirmaPred.first;
	String? _cargoSeleccionado;

	// Listas para Visto Bueno
	List<String> _motivosVbExtra = [];
	String _motivoVbSeleccionado = motivosVistoBuenoPred.first;

	@override
	void initState() {
		super.initState();
		_cargarDatos();
	}

	void _cargarDatos() {
		// --- Cargar Firma ---
		_motivosExtra = (JsonStorage.getJson('firma_motivos_extra') as List?)?.cast<String>() ?? [];
		_cargos = (JsonStorage.getJson('firma_cargos') as List?)?.cast<String>() ?? [];
		
		final motivoGuardado = JsonStorage.getString('firma_motivo_activo');
		if (motivoGuardado != null && (motivosFirmaPred.contains(motivoGuardado) || _motivosExtra.contains(motivoGuardado))) {
			_motivoSeleccionado = motivoGuardado;
		} else {
			_motivoSeleccionado = motivosFirmaPred.first;
		}

		final cargoGuardado = JsonStorage.getString('firma_cargo_activo');
		if (cargoGuardado != null && _cargos.contains(cargoGuardado)) {
			_cargoSeleccionado = cargoGuardado;
		} else if (_cargos.isNotEmpty) {
			_cargoSeleccionado = _cargos.first;
		}

		// --- Cargar Visto Bueno ---
		_motivosVbExtra = (JsonStorage.getJson('vb_motivos_extra') as List?)?.cast<String>() ?? [];
		
		final motivoVbGuardado = JsonStorage.getString('vb_motivo_activo');
		if (motivoVbGuardado != null && (motivosVistoBuenoPred.contains(motivoVbGuardado) || _motivosVbExtra.contains(motivoVbGuardado))) {
			_motivoVbSeleccionado = motivoVbGuardado;
		} else {
			_motivoVbSeleccionado = motivosVistoBuenoPred.first;
		}
	}

	Future<void> _mostrarPopupAgregar({required bool isMotivo, required bool isVb}) async {
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
				if (isVb) {
					_motivosVbExtra.add(txt);
					JsonStorage.setJson('vb_motivos_extra', _motivosVbExtra);
					_motivoVbSeleccionado = txt;
					JsonStorage.setString('vb_motivo_activo', txt);
				} else if (isMotivo) {
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
		required List<String> predeterminados, // <-- Pasamos la lista de predeterminados
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
									// Usamos la lista de predeterminados que se pasa por parámetro
									final isPredeterminado = isMotivo && predeterminados.contains(m);
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
		final todosLosMotivos = [...motivosFirmaPred, ..._motivosExtra];
		final todosLosMotivosVb = [...motivosVistoBuenoPred, ..._motivosVbExtra];

		return Container(
			color: context.surfaceWhite,
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.only(left: 32, top: 0, right: 32, bottom: 32),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									// 1. MOTIVO DE FIRMA
									_buildDropdownStyle(
										label: 'Motivo de firma',
										value: _motivoSeleccionado,
										items: todosLosMotivos,
										predeterminados: motivosFirmaPred, // <-- Pasamos los predeterminados de firma
										isMotivo: true,
										onDelete: (m) async {
											setState(() {
												_motivosExtra.remove(m);
												if (_motivoSeleccionado == m) {
													_motivoSeleccionado = motivosFirmaPred.first;
													JsonStorage.setString('firma_motivo_activo', _motivoSeleccionado);
												}
											});
											await JsonStorage.setJson('firma_motivos_extra', _motivosExtra);
										},
										onAdd: () => _mostrarPopupAgregar(isMotivo: true, isVb: false),
										onChanged: (val) {
											if (val != null) {
												setState(() => _motivoSeleccionado = val);
												JsonStorage.setString('firma_motivo_activo', val); 
											}
										},
									),

									const SizedBox(height: 32),

									// 2. MOTIVO DE VISTO BUENO
									_buildDropdownStyle(
										label: 'Motivo de visto bueno',
										value: _motivoVbSeleccionado,
										items: todosLosMotivosVb,
										predeterminados: motivosVistoBuenoPred, // <-- Pasamos los predeterminados de VB
										isMotivo: true,
										onDelete: (m) async {
											setState(() {
												_motivosVbExtra.remove(m);
												if (_motivoVbSeleccionado == m) {
													_motivoVbSeleccionado = motivosVistoBuenoPred.first;
													JsonStorage.setString('vb_motivo_activo', _motivoVbSeleccionado);
												}
											});
											await JsonStorage.setJson('vb_motivos_extra', _motivosVbExtra);
										},
										onAdd: () => _mostrarPopupAgregar(isMotivo: true, isVb: true),
										onChanged: (val) {
											if (val != null) {
												setState(() => _motivoVbSeleccionado = val);
												JsonStorage.setString('vb_motivo_activo', val); 
											}
										},
									),

									const SizedBox(height: 32),

									// 3. CARGOS
									_buildDropdownStyle(
										label: 'Cargos',
										value: _cargoSeleccionado,
										items: _cargos,
										predeterminados: const [], // Los cargos no tienen predeterminados
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
										onAdd: () => _mostrarPopupAgregar(isMotivo: false, isVb: false),
										onChanged: (val) {
											if (val != null) {
												setState(() => _cargoSeleccionado = val);
												JsonStorage.setString('firma_cargo_activo', val); 
											}
										},
									),

									const SizedBox(height: 32),

									// 4. SUFIJO
									InputEditable(
										label: 'Sufijo de la firma',
										initialValue: JsonStorage.getString('firma_sufijo') ?? 'FG',
										hintText: 'Máximo 3 letras',
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

									const SizedBox(height: 32),

									// 5. DIRECCIÓN / OFICINA
									InputEditable(
										label: 'Siglas de Dirección / Oficina',
										initialValue: JsonStorage.getString('firma_direccion_oficina') ?? '',
										hintText: 'Máximo 7 letras',
										isFolderPath: false,
										maxLength: 7,
										inputFormatters: [
											FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
											UpperCaseTextFormatter(),
										],
										onSave: (val) async {
											await JsonStorage.setString('firma_direccion_oficina', val.trim().toUpperCase());
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