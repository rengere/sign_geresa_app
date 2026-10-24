import 'dart:io';
import 'dart:math';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/folder_path_nxc.dart';
import 'package:flutter/material.dart';

import 'archivo_menu_acciones.dart';
import 'archivo_pdf.dart';
import 'archivos_barra_seleccion.dart';
import 'archivos_dialogos.dart';
import 'archivos_paginacion.dart';
import 'archivos_service.dart';
import 'archivos_tabla.dart';
import 'archivos_toolbar.dart';
import 'visor_pdf_dialog.dart';

class VerArchivos extends StatefulWidget {
	const VerArchivos({super.key});

	@override
	State<VerArchivos> createState() => _VerArchivosState();
}

class _VerArchivosState extends State<VerArchivos> {
	static const int _porPagina = 20;

	final ArchivosService _service = ArchivosService();
	final TextEditingController _busquedaCtrl = TextEditingController();

	List<ArchivoPdf> _todos = [];
	bool _cargando = true;
	String? _error;

	String _consulta = '';
	DateTimeRange? _rango;

	// Por defecto: más reciente arriba
	CampoOrden _campo = CampoOrden.fecha;
	bool _ascendente = false;

	int _pagina = 0;
	final Set<String> _seleccion = {};

	@override
	void initState() {
		super.initState();
		_cargar();
	}

	@override
	void dispose() {
		_busquedaCtrl.dispose();
		super.dispose();
	}

	// ==========================================
	// DATOS
	// ==========================================
	Future<void> _cargar() async {
		if (_todos.isEmpty) setState(() => _cargando = true);
		try {
			// Consultamos la ruta en el momento exacto
			final ruta = obtenerRutaNextcloud();
			final lista = await _service.listar(ruta);
			if (!mounted) return;
			setState(() {
				_todos = lista;
				_error = null;
				_cargando = false;
				_seleccion.retainAll(lista.map((a) => a.ruta).toSet());
			});
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_todos = [];
				_error = _describir(e);
				_cargando = false;
			});
		}
	}

	List<ArchivoPdf> _filtrar() {
		final q = _consulta.trim().toLowerCase();
		final rango = _rango;

		final lista = _todos.where((a) {
			// El buscador filtra SOLO por nombre de archivo
			if (q.isNotEmpty && !a.nombre.toLowerCase().contains(q)) return false;

			// Las fechas se filtran únicamente con el selector de rango
			if (rango != null) {
				final inicio = DateTime(rango.start.year, rango.start.month, rango.start.day);
				final fin = DateTime(rango.end.year, rango.end.month, rango.end.day).add(const Duration(days: 1));
				if (a.fecha.isBefore(inicio) || !a.fecha.isBefore(fin)) return false;
			}
			return true;
		}).toList();

		lista.sort(_comparar);
		return lista;
	}

	int _comparar(ArchivoPdf a, ArchivoPdf b) {
		final porNombre = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
		if (_campo == CampoOrden.nombre) {
			final r = _ascendente ? porNombre : -porNombre;
			return r != 0 ? r : b.fecha.compareTo(a.fecha);
		}
		final porFecha = a.fecha.compareTo(b.fecha);
		final r = _ascendente ? porFecha : -porFecha;
		return r != 0 ? r : porNombre;
	}

	List<ArchivoPdf> _seleccionados() => _todos.where((a) => _seleccion.contains(a.ruta)).toList();

	// ==========================================
	// UI HELPERS
	// ==========================================
	void _aviso(String mensaje, {bool error = false}) {
		ScaffoldMessenger.of(context)
			..hideCurrentSnackBar()
			..showSnackBar(
				SnackBar(
					content: Text(mensaje, style: const TextStyle(color: Colors.white)),
					backgroundColor: error ? context.errorRed : context.textDark,
					behavior: SnackBarBehavior.floating,
					width: 460,
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusSm)),
				),
			);
	}

	String _describir(Object e) {
		if (e is FileSystemException) {
			final detalle = e.osError?.message;
			return (detalle == null || detalle.isEmpty) ? e.message : '${e.message}: $detalle';
		}
		return e.toString();
	}

	Future<void> _intentar(Future<String?> Function() tarea) async {
		try {
			final mensaje = await tarea();
			if (!mounted) return;
			if (mensaje != null) _aviso(mensaje);
		} catch (e) {
			if (!mounted) return;
			_aviso(_describir(e), error: true);
		}
	}

	// ==========================================
	// ACCIONES SOBRE UN ARCHIVO
	// ==========================================
	Future<void> _ejecutarAccion(AccionArchivo accion, ArchivoPdf a) async {
		switch (accion) {
			case AccionArchivo.verEnApp:
				return _verEnApp(a);
			case AccionArchivo.abrirExterno:
				return _abrirExterno(a);
			case AccionArchivo.mostrarCarpeta:
				return _intentar(() async {
					await _service.mostrarEnCarpeta(a.ruta);
					return null;
				});
			case AccionArchivo.descargar:
				return _guardarComo(a);
			case AccionArchivo.compartir:
				return _compartir([a]);
			case AccionArchivo.renombrar:
				return _renombrar(a);
			case AccionArchivo.detalles:
				await showDialog(context: context, builder: (_) => DetallesArchivoDialog(archivo: a));
				return;
			case AccionArchivo.eliminar:
				return _eliminar([a]);
			case AccionArchivo.suprimir:
				return _suprimir([a]);
		}
	}

	Future<void> _verEnApp(ArchivoPdf a) async {
		await showDialog(
			context: context,
			builder: (_) => VisorPdfDialog(archivo: a, onAbrirExterno: () => _abrirExterno(a)),
		);
	}

	Future<void> _abrirExterno(ArchivoPdf a) {
		return _intentar(() async {
			await _service.abrirPredeterminado(a.ruta);
			return null;
		});
	}

	Future<void> _guardarComo(ArchivoPdf a) {
		return _intentar(() async {
			final destino = await FilePicker.platform.saveFile(
				dialogTitle: 'Guardar copia de ${a.nombre}',
				fileName: a.nombre,
				type: FileType.custom,
				allowedExtensions: ['pdf'],
			);
			if (destino == null) return null;
			final ruta = destino.toLowerCase().endsWith('.pdf') ? destino : '$destino.pdf';
			await _service.guardarComo(a, ruta);
			return 'Copia guardada correctamente';
		});
	}

	Future<void> _compartir(List<ArchivoPdf> archivos) async {
		final opcion = await mostrarCompartir(context, cantidad: archivos.length);
		if (opcion == null) return;
		await _intentar(() => _service.compartir(opcion, archivos));
	}

	Future<void> _renombrar(ArchivoPdf a) async {
		final existentes = _todos.where((x) => x.ruta != a.ruta).map((x) => x.nombre.toLowerCase()).toSet();
		final nuevo = await mostrarRenombrar(context, nombreActual: a.nombre, existentes: existentes);
		if (nuevo == null || nuevo == a.nombre) return;
		await _intentar(() async {
			await _service.renombrar(a, nuevo);
			await _cargar();
			return 'Archivo renombrado';
		});
	}

	Future<void> _eliminar(List<ArchivoPdf> archivos) async {
		final uno = archivos.length == 1;
		final ok = await mostrarConfirmacion(
			context,
			titulo: uno ? '¿Eliminar archivo?' : '¿Eliminar ${archivos.length} archivos?',
			mensaje: uno
					? '"${archivos.first.nombre}" dejará de mostrarse en la lista. No se borra del disco: solo se renombra con el prefijo ${ArchivosService.prefijoEliminado}.'
					: 'Estos ${archivos.length} archivos dejarán de mostrarse en la lista. No se borran del disco: solo se renombran con el prefijo ${ArchivosService.prefijoEliminado}.',
			textoConfirmar: 'Eliminar',
			colorConfirmar: context.accentCoral,
		);
		if (!ok || !mounted) return;
		await _intentar(() async {
			for (final a in archivos) {
				await _service.marcarEliminado(a);
			}
			await _cargar();
			return uno ? 'Archivo eliminado' : '${archivos.length} archivos eliminados';
		});
	}

	Future<void> _suprimir(List<ArchivoPdf> archivos) async {
		final uno = archivos.length == 1;
		final ok = await mostrarConfirmacion(
			context,
			titulo: uno ? '¿Suprimir definitivamente?' : '¿Suprimir ${archivos.length} archivos?',
			mensaje: uno
					? '"${archivos.first.nombre}" se borrará de forma permanente del disco. Esta acción no se puede deshacer.'
					: 'Estos ${archivos.length} archivos se borrarán de forma permanente del disco. Esta acción no se puede deshacer.',
			textoConfirmar: 'Suprimir',
			colorConfirmar: context.errorRed,
		);
		if (!ok || !mounted) return;
		await _intentar(() async {
			for (final a in archivos) {
				await _service.suprimir(a);
			}
			await _cargar();
			return uno ? 'Archivo suprimido' : '${archivos.length} archivos suprimidos';
		});
	}

	Future<void> _descargarSeleccion() {
		return _intentar(() async {
			final destino = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Elige la carpeta de destino');
			if (destino == null) return null;
			final lista = _seleccionados();
			for (final a in lista) {
				await _service.copiarACarpeta(a, destino);
			}
			return '${lista.length} archivo(s) guardado(s) en $destino';
		});
	}

	Future<void> _elegirRango() async {
		final actual = _rango;

		final valores = await showCalendarDatePicker2Dialog(
			context: context,
			config: CalendarDatePicker2WithActionButtonsConfig(
				calendarType: CalendarDatePicker2Type.range,
				firstDate: DateTime(2000),
				lastDate: DateTime(2100),
				firstDayOfWeek: 1,
				weekdayLabels: const ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'],
				selectedDayHighlightColor: context.primaryPurple,
				centerAlignModePicker: true,
				okButton: Text('Aplicar', style: TextStyle(color: context.primaryPurple, fontWeight: FontWeight.w700)),
				cancelButton: Text('Cancelar', style: TextStyle(color: context.textGrey, fontWeight: FontWeight.w600)),
			),
			dialogSize: const Size(340, 420),
			borderRadius: BorderRadius.circular(context.radiusMd),
			dialogBackgroundColor: context.surfaceWhite,
			value: actual == null ? <DateTime?>[] : <DateTime?>[actual.start, actual.end],
		);

		if (valores == null || !mounted) return;
		final fechas = valores.whereType<DateTime>().toList();
		if (fechas.isEmpty) return;

		final inicio = fechas.first;
		final fin = fechas.length > 1 ? fechas.last : fechas.first;

		setState(() {
			_rango = DateTimeRange(start: inicio, end: fin);
			_pagina = 0;
		});
	}

	void _limpiarFiltros() {
		_busquedaCtrl.clear();
		setState(() {
			_consulta = '';
			_rango = null;
			_pagina = 0;
		});
	}

	void _ordenar(CampoOrden campo) {
		setState(() {
			if (_campo == campo) {
				_ascendente = !_ascendente;
			} else {
				_campo = campo;
				_ascendente = campo == CampoOrden.nombre;
			}
			_pagina = 0;
		});
	}

	void _toggle(ArchivoPdf a) {
		setState(() {
			if (!_seleccion.add(a.ruta)) _seleccion.remove(a.ruta);
		});
	}

	void _toggleTodosPagina(List<ArchivoPdf> visibles) {
		setState(() {
			final todos = visibles.every((a) => _seleccion.contains(a.ruta));
			if (todos) {
				_seleccion.removeAll(visibles.map((a) => a.ruta));
			} else {
				_seleccion.addAll(visibles.map((a) => a.ruta));
			}
		});
	}

	@override
	Widget build(BuildContext context) {
		final filtrados = _filtrar();
		final totalPaginas = max(1, (filtrados.length / _porPagina).ceil());
		final pagina = _pagina.clamp(0, totalPaginas - 1).toInt();
		final visibles = filtrados.skip(pagina * _porPagina).take(_porPagina).toList();

		return Scaffold(
			appBar: AppBar(title: const Text('Firmar Documento')),
			backgroundColor: context.backgroundLight,
			body: Padding(
				padding: EdgeInsets.all(context.spaceLg),
				child: Column(
					children: [
						ArchivosToolbar(
							controller: _busquedaCtrl,
							onCambioTexto: (t) => setState(() {
								_consulta = t;
								_pagina = 0;
							}),
							onLimpiarTexto: () {
								_busquedaCtrl.clear();
								setState(() {
									_consulta = '';
									_pagina = 0;
								});
							},
							rango: _rango,
							onElegirRango: _elegirRango,
							onLimpiarRango: () => setState(() {
								_rango = null;
								_pagina = 0;
							}),
							onRefrescar: _cargar,
							total: _todos.length,
							encontrados: filtrados.length,
						),
						SizedBox(height: context.spaceMd),
						AnimatedSize(
							duration: const Duration(milliseconds: 200),
							alignment: Alignment.topCenter,
							child: _seleccion.isEmpty
									? const SizedBox(width: double.infinity)
									: Padding(
											padding: EdgeInsets.only(bottom: context.spaceMd),
											child: ArchivosBarraSeleccion(
												cantidad: _seleccion.length,
												totalFiltrados: filtrados.length,
												onSeleccionarTodos: () => setState(() => _seleccion.addAll(filtrados.map((a) => a.ruta))),
												onCancelar: () => setState(_seleccion.clear),
												onDescargar: _descargarSeleccion,
												onCompartir: () => _compartir(_seleccionados()),
												onEliminar: () => _eliminar(_seleccionados()),
												onSuprimir: () => _suprimir(_seleccionados()),
											),
										),
						),
						Expanded(
							child: Material(
								color: context.surfaceWhite,
								clipBehavior: Clip.antiAlias,
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(context.radiusMd),
									side: BorderSide(color: context.borderColor),
								),
								child: _construirContenido(filtrados, visibles, pagina, totalPaginas),
							),
						),
					],
				),
			),
		);
	}

	Widget _construirContenido(List<ArchivoPdf> filtrados, List<ArchivoPdf> visibles, int pagina, int totalPaginas) {
		if (_cargando) {
			return Center(child: CircularProgressIndicator(color: context.primaryPurple));
		}
		if (_error != null) {
			return _estado(
				icono: Icons.folder_off_outlined,
				titulo: 'No se pudo leer la carpeta',
				mensaje: '${obtenerRutaNextcloud()}\n$_error',
				textoBoton: 'Reintentar',
				onBoton: _cargar,
			);
		}
		if (_todos.isEmpty) {
			return _estado(
				icono: Icons.picture_as_pdf_outlined,
				titulo: 'No hay archivos PDF',
				mensaje: 'La carpeta ${obtenerRutaNextcloud()} no tiene documentos.',
				textoBoton: 'Actualizar',
				onBoton: _cargar,
			);
		}
		if (filtrados.isEmpty) {
			return _estado(
				icono: Icons.search_off_rounded,
				titulo: 'Sin resultados',
				mensaje: 'Ningún archivo coincide con tu búsqueda.',
				textoBoton: 'Limpiar filtros',
				onBoton: _limpiarFiltros,
			);
		}

		return Column(
			children: [
				Expanded(
					child: ArchivosTabla(
						archivos: visibles,
						seleccion: _seleccion,
						campoOrden: _campo,
						ascendente: _ascendente,
						onOrdenar: _ordenar,
						onToggle: _toggle,
						onToggleTodos: () => _toggleTodosPagina(visibles),
						onAccion: _ejecutarAccion,
					),
				),
				if (filtrados.length > _porPagina)
					ArchivosPaginacion(
						pagina: pagina,
						totalPaginas: totalPaginas,
						totalArchivos: filtrados.length,
						porPagina: _porPagina,
						onCambiar: (p) => setState(() => _pagina = p),
					),
			],
		);
	}

	Widget _estado({
		required IconData icono,
		required String titulo,
		required String mensaje,
		required String textoBoton,
		required VoidCallback onBoton,
	}) {
		return Center(
			child: Padding(
				padding: EdgeInsets.all(context.spaceLg),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Container(
							width: 80,
							height: 80,
							decoration: BoxDecoration(color: context.surfaceGrey, shape: BoxShape.circle),
							child: Icon(icono, size: 36, color: context.textGrey),
						),
						SizedBox(height: context.spaceMd),
						Text(titulo, style: Theme.of(context).textTheme.titleLarge),
						SizedBox(height: context.spaceSm),
						Text(mensaje, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
						SizedBox(height: context.spaceMd),
						ElevatedButton(onPressed: onBoton, child: Text(textoBoton)),
					],
				),
			),
		);
	}
}