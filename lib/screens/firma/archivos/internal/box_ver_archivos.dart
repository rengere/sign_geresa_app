import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/editor_firma_modal.dart';
import 'package:firmador_geresa/screens/firma/firmar/popup_firma.dart';
import 'package:firmador_geresa/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/assets/tools/files_manag/folder_path_nxc.dart';
import 'package:firmador_geresa/data/rutas_carpetas_docs.dart';

import 'archivo_menu_acciones.dart';
import 'archivo_pdf.dart';
import 'archivos_barra_seleccion.dart';
import 'archivos_dialogos.dart';
import 'archivos_paginacion.dart';
import 'archivos_service.dart';
import 'archivos_tabla.dart';
import 'archivos_toolbar.dart';
import 'visor_pdf_dialog.dart';

class BoxVerArchivos extends StatefulWidget {
	final String rutaCarpetaPrincipal;
	final String tipo;
	final List<Map<String, dynamic>>? rutasAlternativas;

	const BoxVerArchivos({
		super.key, 
		required this.rutaCarpetaPrincipal,
		required this.tipo,
		this.rutasAlternativas,
	});

	@override
	State<BoxVerArchivos> createState() => _BoxVerArchivosState();
}

class _BoxVerArchivosState extends State<BoxVerArchivos> {
	static const int _porPagina = 20;
	
	List<Map<String, dynamic>> _alternativas = [];
	String? _rutaActual;
	String? _nombreCarpetaActual;

	final ArchivosService _service = ArchivosService();
	final TextEditingController _busquedaCtrl = TextEditingController();

	List<ArchivoPdf> _archivos = [];
	bool _cargando = true;
	String? _error;

	String _consulta = '';
	DateTimeRange? _rango;

	CampoOrden _campo = CampoOrden.fecha;
	bool _ascendente = false;

	int _pagina = 0;
	final Set<String> _seleccion = {};

	@override
	void initState() {
		super.initState();
		_alternativas = widget.rutasAlternativas ?? [];
		_cargar();
	}

	@override
	void dispose() {
		_busquedaCtrl.dispose();
		super.dispose();
	}

	Future<void> _cargar() async {
		setState(() => _cargando = true);
		try {
			final String rutaALeer = _rutaActual ?? widget.rutaCarpetaPrincipal;
			final lista = await _service.listar(rutaALeer);

			if (!mounted) return;
			setState(() {
				_archivos = lista;
				_error = null;
				_cargando = false;
				_seleccion.retainAll(lista.map((a) => a.ruta).toSet());
			});
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_archivos = [];
				_error = _describir(e);
				_cargando = false;
			});
		}
	}

	void _entrarCarpeta(Map<String, dynamic> rutaData) {
		setState(() {
			_rutaActual = rutaData['ruta'];
			_nombreCarpetaActual = rutaData['nombre'] ?? 'Carpeta Alternativa';
			_pagina = 0;
			_consulta = '';
			_busquedaCtrl.clear();
			_rango = null;
			_seleccion.clear();
		});
		_cargar();
	}

	void _volverRaiz() {
		setState(() {
			_rutaActual = null;
			_nombreCarpetaActual = null;
			_pagina = 0;
			_consulta = '';
			_busquedaCtrl.clear();
			_rango = null;
			_seleccion.clear();
		});
		_cargar();
	}

	List<ArchivoPdf> _filtrarLista(List<ArchivoPdf> lista) {
		final q = _consulta.trim().toLowerCase();
		final rango = _rango;

		final filtrados = lista.where((a) {
			if (q.isNotEmpty && !a.nombre.toLowerCase().contains(q)) return false;
			if (rango != null) {
				final inicio = DateTime(rango.start.year, rango.start.month, rango.start.day);
				final fin = DateTime(rango.end.year, rango.end.month, rango.end.day).add(const Duration(days: 1));
				if (a.fecha.isBefore(inicio) || !a.fecha.isBefore(fin)) return false;
			}
			return true;
		}).toList();

		filtrados.sort(_comparar);
		return filtrados;
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

	List<ArchivoPdf> _seleccionados() => _archivos.where((a) => _seleccion.contains(a.ruta)).toList();

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

	// --- NUEVO MODAL DE CARGA ---
	void _mostrarCarga(BuildContext context, ValueNotifier<String> mensaje) {
		showDialog(
			context: context,
			barrierDismissible: false,
			barrierColor: Colors.transparent,
			builder: (ctx) => Center(
				child: Material(
					color: Colors.transparent,
					child: Container(
						padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
						decoration: BoxDecoration(
							color: ctx.surfaceWhite,
							borderRadius: BorderRadius.circular(ctx.radiusLg),
							boxShadow: [
								BoxShadow(
									color: Colors.black.withValues(alpha: 0.1),
									blurRadius: 10,
									offset: const Offset(0, 4),
								),
							],
						),
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								SizedBox(
									width: 24,
									height: 24,
									child: CircularProgressIndicator(
										strokeWidth: 2.5,
										color: ctx.primaryPurple,
									),
								),
								const SizedBox(width: 16),
								ValueListenableBuilder<String>(
									valueListenable: mensaje,
									builder: (_, texto, __) => Text(
										texto,
										style: TextStyle(
											fontSize: 14,
											fontWeight: FontWeight.w500,
											color: ctx.textDark,
										),
									),
								),
							],
						),
					),
				),
			),
		);
	}

	Future<void> _firmarDocumentoProyectado(ArchivoPdf archivo) async {
		try {
			final bytes = await File(archivo.ruta).readAsBytes();

			final api = ApiService();
			TitularCertificado? titular;
			int intentos = 0;

			// --- MOSTRAR MODAL DE CARGA ---
			final mensajeCarga = ValueNotifier<String>('Leyendo DNIe...');
			if (mounted) _mostrarCarga(context, mensajeCarga);

			while (intentos < 5) {
				try {
					titular = await api.obtenerTitular();
					break;
				} catch (e) {
					intentos++;
					if (intentos >= 5) rethrow;
					await Future.delayed(const Duration(milliseconds: 200));
				}
			}

			// --- CERRAR MODAL DE CARGA ---
			if (mounted) {
				Navigator.of(context, rootNavigator: true).pop();
			}

			if (!mounted) return;

			final dataNormal = await DefaultAssetBundle.of(context).load('lib/assets/images/logo_firma.png');
			final dataVB = await DefaultAssetBundle.of(context).load('lib/assets/images/logo_vb.png');

			if (!mounted) return;

			final resultadoEditor = await Navigator.of(context).push<Map<String, dynamic>>(
				MaterialPageRoute(
					builder: (_) => EditorFirmaModal(
						pdfBytes: bytes,
						nombreArchivo: archivo.nombre,
						imagenFirmaBytes: dataNormal.buffer.asUint8List(),
						imagenVistoBuenoBytes: dataVB.buffer.asUint8List(),
						nombreFirmante: titular!.nombre,
						dniFirmante: titular.dni,
					),
				),
			);

			if (resultadoEditor == null || !mounted) return;

			final pdfProcesado = resultadoEditor['pdfBytes'] as Uint8List;
			final requiereFirma = resultadoEditor['requiereFirma'] as bool;

			final rutaNxc = obtenerRutaNextcloud();
			final rutaFirmados = "$rutaNxc$firmados";
			final rutaProyectados = "$rutaNxc$proyectados";

			if (requiereFirma) {
				await showDialog(
					context: context,
					barrierDismissible: false,
					builder: (_) => PopupFirma(
						pdfBytes: pdfProcesado,
						nombreArchivo: archivo.nombre,
						rutaDestinoFinal: rutaFirmados, // <-- ENVIAR A FIRMADOS
						esVistoBueno: false,
						imagenSello: resultadoEditor['imagenSello'],
						pagina: resultadoEditor['pagina'],
						x: resultadoEditor['x'],
						y: resultadoEditor['y'],
						ancho: resultadoEditor['ancho'],
						alto: resultadoEditor['alto'],
					),
				);
			} else {
				await File(archivo.ruta).writeAsBytes(pdfProcesado);
				
				await showDialog(
					context: context,
					barrierDismissible: false,
					builder: (_) => PopupFirma(
						pdfBytes: pdfProcesado,
						nombreArchivo: archivo.nombre,
						rutaDestinoFinal: rutaProyectados, // <-- ENVIAR A PROYECTADOS
						esVistoBueno: true,
					),
				);
				
				if (mounted) {
					_aviso('Documento firmado (Visto Bueno) y actualizado', error: false);
				}
			}
			
			if (mounted) await _cargar();

		} catch (e) {
			// Si hay un error, nos aseguramos de cerrar el modal de carga si está abierto
			if (mounted) {
				Navigator.of(context, rootNavigator: true).pop();
			}
			if (!mounted) return;
			_aviso('Error al firmar: $e', error: true);
		}
	}

	Future<void> _ejecutarAccion(AccionArchivo accion, ArchivoPdf a) async {
		switch (accion) {
			case AccionArchivo.verEnApp:
				return _verEnApp(a);
			case AccionArchivo.firmarDigitalmente:
				return _firmarDocumentoProyectado(a);
			case AccionArchivo.abrirExterno:
				return _abrirExterno(a);
			case AccionArchivo.mostrarCarpeta:
				return _intentar(() async {
					await _service.mostrarEnCarpeta(a.ruta);
					return null;
				});
			case AccionArchivo.descargar:
				return _guardarComo(a);
			case AccionArchivo.renombrar:
				return _renombrar(a);
			case AccionArchivo.detalles:
				await showDialog(context: context, builder: (_) => DetallesArchivoDialog(archivo: a));
				return;
			case AccionArchivo.eliminar:
				return _eliminar([a]);
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

	Future<void> _renombrar(ArchivoPdf a) async {
		final existentes = _archivos.where((x) => x.ruta != a.ruta).map((x) => x.nombre.toLowerCase()).toSet();
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
		final filtrados = _filtrarLista(_archivos);
		final totalPaginas = max(1, (filtrados.length / _porPagina).ceil());
		final pagina = _pagina.clamp(0, totalPaginas - 1).toInt();
		final visibles = filtrados.skip(pagina * _porPagina).take(_porPagina).toList();

		final q = _consulta.trim().toLowerCase();
		final carpetasFiltradas = _alternativas.where((rutaData) {
			final nombre = (rutaData['nombre'] as String? ?? '').toLowerCase();
			return q.isEmpty || nombre.contains(q);
		}).toList();

		final bool enRaiz = _rutaActual == null && _rango == null;
		
		final int totalItems = _archivos.length + (enRaiz ? _alternativas.length : 0);
		final int encontradosItems = filtrados.length + (enRaiz ? carpetasFiltradas.length : 0);

		return Column(
			children: [
				Row(
					children: [
						if (_rutaActual != null) ...[
							IconButton(
								tooltip: 'Volver a la raíz',
								onPressed: _volverRaiz,
								icon: const Icon(Icons.arrow_back_rounded),
								color: context.primaryPurple,
							),
							Text(
								'$_nombreCarpetaActual / ',
								style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark, fontSize: 16),
							),
							const SizedBox(width: 16),
						],
						Expanded(
							child: ArchivosToolbar(
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
								total: totalItems,
								encontrados: encontradosItems,
							),
						),
					],
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
										esProyectado: widget.tipo == 'proyectados',
										onSeleccionarTodos: () => setState(() => _seleccion.addAll(filtrados.map((a) => a.ruta))),
										onCancelar: () => setState(_seleccion.clear),
										onDescargar: _descargarSeleccion,
										onEliminar: () => _eliminar(_seleccionados()),
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
						child: _cargando
							? Center(child: CircularProgressIndicator(color: context.primaryPurple))
							: (_error != null
								? _estado(icono: Icons.folder_off_outlined, titulo: 'No se pudo leer', mensaje: _error!, textoBoton: 'Reintentar', onBoton: _cargar)
								: Column(
									children: [
										Expanded(
											child: SingleChildScrollView(
												child: ArchivosTabla(
													archivos: visibles,
													seleccion: _seleccion,
													campoOrden: _campo,
													ascendente: _ascendente,
													esProyectado: widget.tipo == 'proyectados',
													onOrdenar: _ordenar,
													onToggle: _toggle,
													onToggleTodos: () => _toggleTodosPagina(visibles),
													onAccion: _ejecutarAccion,
													
													headerExtra: enRaiz && carpetasFiltradas.isNotEmpty 
														? Column(
															children: carpetasFiltradas.map((rutaData) {
																return _CarpetaValidada(
																	rutaData: rutaData,
																	service: _service,
																	onEnter: () => _entrarCarpeta(rutaData),
																);
															}).toList(),
														)
														: null,
												),
											),
										),
										
										if (filtrados.isEmpty && (!enRaiz || carpetasFiltradas.isEmpty))
											_estado(
												icono: Icons.picture_as_pdf_outlined, 
												titulo: 'No hay archivos PDF', 
												mensaje: 'La carpeta está vacía o no coincide con la búsqueda.', 
												textoBoton: 'Actualizar', 
												onBoton: _cargar
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
								)
							),
					),
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

class _CarpetaValidada extends StatefulWidget {
	final Map<String, dynamic> rutaData;
	final ArchivosService service;
	final VoidCallback onEnter;

	const _CarpetaValidada({
		required this.rutaData,
		required this.service,
		required this.onEnter,
	});

	@override
	State<_CarpetaValidada> createState() => _CarpetaValidadaState();
}

class _CarpetaValidadaState extends State<_CarpetaValidada> {
	late Future<bool> _futureTieneArchivos;

	@override
	void initState() {
		super.initState();
		_futureTieneArchivos = _verificarArchivos();
	}

	Future<bool> _verificarArchivos() async {
		try {
			final ruta = widget.rutaData['ruta'] as String;
			final archivos = await widget.service.listar(ruta);
			return archivos.isNotEmpty;
		} catch (_) {
			return false;
		}
	}

	@override
	Widget build(BuildContext context) {
		return FutureBuilder<bool>(
			future: _futureTieneArchivos,
			builder: (context, snapshot) {
				if (snapshot.connectionState != ConnectionState.done) {
					return const SizedBox.shrink();
				}

				if (snapshot.data != true) {
					return const SizedBox.shrink();
				}

				final nombre = widget.rutaData['nombre'] ?? 'Carpeta';
				return Material(
					color: Colors.transparent,
					child: InkWell(
						onTap: widget.onEnter,
						child: Padding(
							padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
							child: Row(
								children: [
									Icon(Icons.folder_rounded, color: context.primaryPurple, size: 28),
									const SizedBox(width: 12),
									Text(nombre, style: TextStyle(fontWeight: FontWeight.w600, color: context.textDark, fontSize: 14)),
									const Spacer(),
									Icon(Icons.chevron_right_rounded, color: context.textGrey),
								],
							),
						),
					),
				);
			},
		);
	}
}