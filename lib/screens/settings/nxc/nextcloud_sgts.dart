import 'package:file_picker/file_picker.dart'; // <-- IMPORTANTE AÑADIR ESTO
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/widgets/forms/input_editable.dart';
import 'package:flutter/material.dart';

class NextcloudStgs extends StatefulWidget {
	const NextcloudStgs({super.key});

	@override
	State<NextcloudStgs> createState() => _NextcloudStgsState();
}

class _NextcloudStgsState extends State<NextcloudStgs> {
	// Valor actual de la ruta principal
	String _rutaNextCloud = '';
	
	// Lista de rutas alternativas
	List<Map<String, dynamic>> _rutasAlternativas = [];

	// Claves de JSON
	final String _keyRutaNextCloud = 'ruta_nextcloud';
	final String _keyRutasAlt = 'rutas_alternativas';

	@override
	void initState() {
		super.initState();
		// 1. Leer ruta principal
		_rutaNextCloud = JsonStorage.getString(_keyRutaNextCloud) ?? '';

		// 2. Leer rutas alternativas
		final jsonRutas = JsonStorage.getJson(_keyRutasAlt);
		if (jsonRutas != null) {
			_rutasAlternativas = List<Map<String, dynamic>>.from(jsonRutas);
		}
	}

	// ==========================================
	// POPUP PARA AGREGAR / EDITAR RUTA
	// ==========================================
	Future<void> _mostrarPopupRuta({int? index}) async {
		final esEdicion = index != null;
		final TextEditingController ctrlRuta = TextEditingController(
			text: esEdicion ? _rutasAlternativas[index]['ruta'] : ''
		);
		bool checkProyectados = esEdicion ? _rutasAlternativas[index]['proyectados'] : false;
		bool checkFirmados = esEdicion ? _rutasAlternativas[index]['firmados'] : false;

		final result = await showDialog<bool>(
			context: context,
			builder: (ctx) {
				return StatefulBuilder(
					builder: (context, setStateDialog) {
						return AlertDialog(
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
							title: Text(esEdicion ? 'Editar Ruta Alternativa' : 'Añadir Ruta Alternativa'),
							content: SizedBox(
								width: 400,
								child: Column(
									mainAxisSize: MainAxisSize.min,
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										// Input con estilo similar a InputEditable
										Row(
											children: [
												Expanded(
													child: TextField(
														controller: ctrlRuta,
														readOnly: true, // Solo lectura, se llena con el filepicker
														decoration: InputDecoration(
															hintText: 'Selecciona una carpeta...',
															filled: true,
															fillColor: ctx.surfaceGrey,
															contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
															border: OutlineInputBorder(
																borderRadius: BorderRadius.circular(8),
																borderSide: BorderSide(color: ctx.borderColor),
															),
														),
													),
												),
												const SizedBox(width: 12),
												IconButton(
													onPressed: () async {
														// AQUÍ SÍ ABRE EL EXPLORADOR REAL DE WINDOWS
														final ruta = await FilePicker.platform.getDirectoryPath(
															dialogTitle: 'Selecciona la carpeta',
														);
														if (ruta != null) {
															setStateDialog(() => ctrlRuta.text = ruta);
														}
													},
													icon: const Icon(Icons.folder_open_rounded),
													color: ctx.primaryPurple,
													style: IconButton.styleFrom(
														backgroundColor: ctx.primaryPurple.withValues(alpha: 0.1),
														shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
													),
												),
											],
										),
										const SizedBox(height: 24),
										// CHECKS ACORTADOS
										Row(
											children: [
												Expanded(
													child: CheckboxListTile(
														title: Text('Doc. Proyectados', style: TextStyle(fontSize: 13, color: ctx.textDark)),
														value: checkProyectados,
														activeColor: ctx.primaryPurple,
														onChanged: (val) => setStateDialog(() => checkProyectados = val ?? false),
														contentPadding: EdgeInsets.zero,
														controlAffinity: ListTileControlAffinity.leading,
													),
												),
												Expanded(
													child: CheckboxListTile(
														title: Text('Doc. Firmados', style: TextStyle(fontSize: 13, color: ctx.textDark)),
														value: checkFirmados,
														activeColor: ctx.primaryPurple,
														onChanged: (val) => setStateDialog(() => checkFirmados = val ?? false),
														contentPadding: EdgeInsets.zero,
														controlAffinity: ListTileControlAffinity.leading,
													),
												),
											],
										)
									],
								),
							),
							actions: [
								TextButton(
									onPressed: () => Navigator.pop(ctx, false),
									child: Text('Cancelar', style: TextStyle(color: ctx.textGrey)),
								),
								ElevatedButton(
									onPressed: () {
										if (ctrlRuta.text.trim().isNotEmpty) {
											Navigator.pop(ctx, true);
										}
									},
									style: ElevatedButton.styleFrom(backgroundColor: ctx.primaryPurple),
									child: Text(esEdicion ? 'Guardar Cambios' : 'Añadir'),
								),
							],
						);
					}
				);
			},
		);

		// Si el usuario presionó Añadir/Guardar
		if (result == true && ctrlRuta.text.trim().isNotEmpty) {
			setState(() {
				final nuevaRuta = {
					'ruta': ctrlRuta.text.trim(),
					'proyectados': checkProyectados,
					'firmados': checkFirmados,
				};

				if (esEdicion) {
					_rutasAlternativas[index] = nuevaRuta;
				} else {
					_rutasAlternativas.add(nuevaRuta);
				}
			});
			// Guardar en JSON
			await JsonStorage.setJson(_keyRutasAlt, _rutasAlternativas);
		}
	}

	// ==========================================
	// ELIMINAR RUTA
	// ==========================================
	Future<void> _eliminarRuta(int index) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
				title: const Text('¿Eliminar ruta?'),
				content: Text('Se eliminará la ruta "${_rutasAlternativas[index]['ruta']}".'),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: Text('Cancelar', style: TextStyle(color: ctx.textGrey)),
					),
					ElevatedButton(
						onPressed: () => Navigator.pop(ctx, true),
						style: ElevatedButton.styleFrom(backgroundColor: ctx.errorRed),
						child: const Text('Eliminar'),
					),
				],
			),
		);

		if (confirmar == true) {
			setState(() {
				_rutasAlternativas.removeAt(index);
			});
			await JsonStorage.setJson(_keyRutasAlt, _rutasAlternativas);
		}
	}

	// ==========================================
	// BUILD
	// ==========================================
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.only(top: 0, right: 24.0, bottom: 24.0, left: 24.0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					// 1. RUTA PRINCIPAL
					InputEditable(
						label: 'Ruta NextCloud Principal',
						initialValue: _rutaNextCloud,
						hintText: 'agrega ruta',
						isFolderPath: true,
						onSave: (newValue) async {
							setState(() => _rutaNextCloud = newValue);
							await JsonStorage.setString(_keyRutaNextCloud, newValue);
							if (mounted) {
								ScaffoldMessenger.of(context).showSnackBar(
									const SnackBar(content: Text('Ruta principal guardada'), duration: Duration(seconds: 2)),
								);
							}
						},
					),

					const SizedBox(height: 32),

					// 2. RUTAS ALTERNATIVAS
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: [
							Text(
								'Rutas Alternativas',
								style: TextStyle(
									fontSize: 16,
									fontWeight: FontWeight.bold,
									color: context.textDark,
								),
							),
							IconButton(
								onPressed: () => _mostrarPopupRuta(),
								icon: const Icon(Icons.add),
								color: context.primaryPurple,
								style: IconButton.styleFrom(
									backgroundColor: context.primaryPurple.withValues(alpha: 0.1),
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
								),
								tooltip: 'Añadir ruta alternativa',
							),
						],
					),
					const SizedBox(height: 12),

					// TABLA DE RUTAS
					if (_rutasAlternativas.isEmpty)
						Container(
							width: double.infinity,
							padding: const EdgeInsets.all(24),
							decoration: BoxDecoration(
								color: context.surfaceGrey,
								borderRadius: BorderRadius.circular(context.radiusMd),
								border: Border.all(color: context.borderColor),
							),
							child: Text(
								'No hay rutas alternativas configuradas.',
								textAlign: TextAlign.center,
								style: TextStyle(color: context.textGrey, fontSize: 14),
							),
						)
					else
						Container(
							decoration: BoxDecoration(
								border: Border.all(color: context.borderColor),
								borderRadius: BorderRadius.circular(context.radiusMd),
							),
							child: ClipRRect(
								borderRadius: BorderRadius.circular(context.radiusMd),
								child: Table(
									columnWidths: const {
										0: FlexColumnWidth(3),
										1: FlexColumnWidth(2),
										2: FlexColumnWidth(2),
										3: FixedColumnWidth(100),
									},
									border: TableBorder(horizontalInside: BorderSide(color: context.borderColor)),
									children: [
										// CABECERA CORREGIDA
										TableRow(
											decoration: BoxDecoration(color: context.surfaceGrey),
											children: [
												Padding(padding: const EdgeInsets.all(12), child: Text('Ruta', style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark))),
												Padding(padding: const EdgeInsets.all(12), child: Text('Doc. Proyectados', style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark))),
												Padding(padding: const EdgeInsets.all(12), child: Text('Doc. Firmados', style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark))),
												Padding(padding: const EdgeInsets.all(12), child: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark))),
											],
										),
										// FILAS
										..._rutasAlternativas.asMap().entries.map((entry) {
											final i = entry.key;
											final ruta = entry.value;
											return TableRow(
												children: [
													Padding(padding: const EdgeInsets.all(12), child: Text(ruta['ruta'], overflow: TextOverflow.ellipsis, style: TextStyle(color: context.textDark))),
													Padding(
														padding: const EdgeInsets.all(12),
														child: Icon(
															ruta['proyectados'] ? Icons.check_circle_rounded : Icons.cancel_rounded,
															color: ruta['proyectados'] ? Colors.green : context.textGrey,
															size: 20,
														),
													),
													Padding(
														padding: const EdgeInsets.all(12),
														child: Icon(
															ruta['firmados'] ? Icons.check_circle_rounded : Icons.cancel_rounded,
															color: ruta['firmados'] ? Colors.green : context.textGrey,
															size: 20,
														),
													),
													Padding(
														padding: const EdgeInsets.symmetric(horizontal: 4),
														child: Row(
															mainAxisSize: MainAxisSize.min,
															children: [
																IconButton(
																	onPressed: () => _mostrarPopupRuta(index: i),
																	icon: const Icon(Icons.edit_rounded, size: 18),
																	color: context.primaryPurple,
																	tooltip: 'Editar',
																),
																IconButton(
																	onPressed: () => _eliminarRuta(i),
																	icon: const Icon(Icons.delete_rounded, size: 18),
																	color: context.errorRed,
																	tooltip: 'Eliminar',
																),
															],
														),
													),
												],
											);
										}),
									],
								),
							),
						),
				],
			),
		);
	}
}