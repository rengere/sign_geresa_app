import 'dart:io';
import 'visor_anexo.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:firmador_geresa/assets/tools/files_manag/folder_path_nxc.dart';
import 'package:firmador_geresa/data/motivo_firma.dart';
import 'package:firmador_geresa/data/rutas_carpetas_docs.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/boton_zoom.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/correlativo_visual.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/documento_referencial.dart' show DocumentoReferencial;
import 'package:firmador_geresa/screens/firma/firmar/editor/documentos_ref_slider.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/anexos_slider.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/qr_visual.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/sello_firma_visual.dart';
import 'package:firmador_geresa/services/anexos_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/services/api_service.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/detector_dnie_service.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/config_sello_firma.dart';
import 'package:path/path.dart' as p;

class _ArrastreCorrelativo {
	final String valor;
	const _ArrastreCorrelativo(this.valor);
}

class _ArrastreQr {
	final String url;
	const _ArrastreQr(this.url);
}

enum PosicionFirma { arribaIzquierda, arribaCentro, arribaDerecha, abajoIzquierda, abajoCentro, abajoDerecha }

class EditorFirmaModal extends StatefulWidget {
	final Uint8List pdfBytes;
	final String nombreArchivo;
	final Uint8List imagenFirmaBytes;
	final Uint8List imagenVistoBuenoBytes;
	final String nombreFirmante;
	final String dniFirmante;
	final String? rutaArchivoOriginal; // <-- NUEVO PARÁMETRO

	const EditorFirmaModal({
		super.key,
		required this.pdfBytes,
		required this.nombreArchivo,
		required this.imagenFirmaBytes,
		required this.imagenVistoBuenoBytes,
		required this.nombreFirmante,
		required this.dniFirmante,
		this.rutaArchivoOriginal, // <-- NUEVO
	});

	@override
	State<EditorFirmaModal> createState() => _EditorFirmaModalState();
}

enum _PanelLateral { ninguno, referenciales, anexos }

class _EditorFirmaModalState extends State<EditorFirmaModal> {
	_PanelLateral _panelLateral = _PanelLateral.ninguno;
	File? _anexoSeleccionado;
	final List<File> _anexosPendientes = [];
	SesionAnexos? _sesionAnexos;
	bool _reinicioPendiente = false;
	bool _preparandoEnlace = false;
	final PdfViewerController _pdfController = PdfViewerController();
	final GlobalKey _stackKey = GlobalKey();
	final GlobalKey _selloKey = GlobalKey();
	final GlobalKey _qrKey = GlobalKey();

	final TextEditingController _paginaCtrl = TextEditingController(text: '1');
	final TextEditingController _correlativoCtrl = TextEditingController(text: '');

	final DetectorDnieService _detector = DetectorDnieService();
	bool _hardwareDisponible = false;
	String _nombreFirmante = '';
	String _dniFirmante = '';

	bool _esModoVistoBueno = false;
	bool _vbTodas = false;
	final Map<int, List<Offset>> _vbPosiciones = {};
	Offset? _vbReferencia;
	static const double _ladoVb = ConfigSelloFirma.ladoSelloVb;
	bool get _hayVb => _vbTodas ? _vbReferencia != null : _vbPosiciones.values.any((lista) => lista.isNotEmpty);

	Offset _limitarVb(Offset pos, int pagina) {
		final size = _tamanos[pagina - 1];
		return Offset(pos.dx.clamp(0.0, math.max(0.0, 1 - _ladoVb / size.width)).toDouble(), pos.dy.clamp(0.0, math.max(0.0, 1 - _ladoVb / size.height)).toDouble());
	}

	List<Offset> _vistosEnPagina(int pagina) {
		if (_vbTodas) return _vbReferencia == null ? [] : [_limitarVb(_vbReferencia!, pagina)];
		return _vbPosiciones[pagina] ?? [];
	}

	void _reiniciarVb() {
		_vbPosiciones.clear();
		_vbReferencia = null;
	}

	Widget _selloVb() => SelloFirmaVisual(
		esModoVistoBueno: true, hardwareDisponible: _hardwareDisponible,
		nombreFirmante: _nombreFirmante, dniFirmante: _dniFirmante,
		cargoSeleccionado: _cargoSeleccionado ?? '', motivoSeleccionado: _motivoSeleccionado,
		direccionOficina: _direccionOficina, totalPaginas: _totalPaginas,
		imagenFirmaBytes: widget.imagenFirmaBytes, imagenVistoBuenoBytes: widget.imagenVistoBuenoBytes,
		anchoFirma: _ladoVb, altoFirma: _ladoVb, ladoImagen: _lado,
	);
	bool _modoManual = true;
	bool _procesando = false;
	bool _foliarDocumento = false;
	bool _documentoYaFirmado = false;

	double _fuenteCorrelativo = 12.0;
	Offset? _posicionCorrelativo;

	static const double _anchoFirma = ConfigSelloFirma.anchoFirma;
	static const double _altoFirma = ConfigSelloFirma.altoFirma;
	static const double _lado = ConfigSelloFirma.ladoImagen;
	static const double _margen = ConfigSelloFirma.margen;
	static const double _anchoCorrelativo = ConfigSelloFirma.anchoCorrelativo;
	static const double _altoCorrelativo = ConfigSelloFirma.altoCorrelativo;

	Offset? _posicionPorcentual;
	int _paginaFirma = 1;
	int _totalPaginas = 1;
	List<Size> _tamanos = const [];
	PosicionFirma _posicionAuto = PosicionFirma.abajoIzquierda;

	Uint8List _documentoUnido = Uint8List(0);
	List<DocumentoReferencial> _referenciales = [];
	Offset? _posicionAutoElegida;

	String _motivoSeleccionado = '';
	String? _cargoSeleccionado;
	List<String> _motivosFirmaDisponibles = [];
	List<String> _motivosVbDisponibles = [];
	List<String> _cargosDisponibles = [];
	String _direccionOficina = '';

	String? _urlAnexos;
	Offset? _posicionQr;
	bool _cargandoAnexos = false;

	@override
	void initState() {
		super.initState();
		_cargarConfiguracionFirma();
		_documentoUnido = widget.pdfBytes;
		_nombreFirmante = widget.nombreFirmante;
		_dniFirmante = widget.dniFirmante;
		_hardwareDisponible = _nombreFirmante.isNotEmpty && _dniFirmante.isNotEmpty;
		_detector.onCambioHardware = _alCambiarHardware;
		_detector.iniciar();
		_verificarSiFirmado();
	}

	@override
	void dispose() {
		_detector.detener();
		_paginaCtrl.dispose();
		_correlativoCtrl.dispose();
		super.dispose();
	}

	Future<void> _alCambiarHardware(bool disponible) async {
		if (!mounted) return;
		if (disponible) {
			try {
				final titular = await ApiService().obtenerTitular();
				if (mounted) {
					setState(() {
						_hardwareDisponible = true;
						_nombreFirmante = titular.nombre;
						_dniFirmante = titular.dni;
					});
				}
			} catch (_) {
				if (mounted) setState(() => _hardwareDisponible = false);
			}
		} else {
			setState(() {
				_hardwareDisponible = false;
				_nombreFirmante = '';
				_dniFirmante = '';
			});
		}
	}

	Future<void> _verificarSiFirmado() async {
		try {
			final yaFirmado = await ApiService().estaFirmado(pdfBytes: widget.pdfBytes, nombreArchivo: widget.nombreArchivo);
			if (mounted) setState(() => _documentoYaFirmado = yaFirmado);
		} catch (e) {
			debugPrint('Error verificando estado del documento: $e');
		}
	}

	void _cargarConfiguracionFirma() {
		final motivosFirmaExtra = (JsonStorage.getJson('firma_motivos_extra') as List?)?.cast<String>() ?? [];
		_motivosFirmaDisponibles = [...motivosFirmaPred, ...motivosFirmaExtra];
		_cargosDisponibles = (JsonStorage.getJson('firma_cargos') as List?)?.cast<String>() ?? [];
		final motivosVbExtra = (JsonStorage.getJson('vb_motivos_extra') as List?)?.cast<String>() ?? [];
		_motivosVbDisponibles = [...motivosVistoBuenoPred, ...motivosVbExtra];

		final firmaActiva = JsonStorage.getString('firma_motivo_activo');
		_motivoSeleccionado = (firmaActiva != null && _motivosFirmaDisponibles.contains(firmaActiva)) ? firmaActiva : (_motivosFirmaDisponibles.isNotEmpty ? _motivosFirmaDisponibles.first : '');

		final cargoActivo = JsonStorage.getString('firma_cargo_activo');
		_cargoSeleccionado = (cargoActivo != null && _cargosDisponibles.contains(cargoActivo)) ? cargoActivo : (_cargosDisponibles.isNotEmpty ? _cargosDisponibles.first : null);

		_direccionOficina = JsonStorage.getString('firma_direccion_oficina') ?? '';

		_esModoVistoBueno = false;
		_modoManual = true;
		_foliarDocumento = true;
	}

	void _alternarModo(bool irAVistoBueno) {
		if (_cargandoAnexos || _sesionAnexos != null) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reinicia los anexos antes de cambiar el modo.')));
			return;
		}
		setState(() {
			_esModoVistoBueno = irAVistoBueno;
			_vbTodas = false;
			_reiniciarVb();
			if (_esModoVistoBueno) {
				if (!_motivosVbDisponibles.contains(_motivoSeleccionado)) {
					_motivoSeleccionado = _motivosVbDisponibles.isNotEmpty ? _motivosVbDisponibles.first : 'Visto bueno';
				}
				_foliarDocumento = false;
				_modoManual = false;
				_posicionAuto = PosicionFirma.abajoIzquierda;
			} else {
				if (!_motivosFirmaDisponibles.contains(_motivoSeleccionado)) {
					_motivoSeleccionado = _motivosFirmaDisponibles.isNotEmpty ? _motivosFirmaDisponibles.first : '';
				}
				_foliarDocumento = true;
				_modoManual = true;
			}
			_posicionPorcentual = null;
			_posicionAutoElegida = null;
			_posicionCorrelativo = null;
		});
	}

	Future<void> _actualizarDocumentoUnido() async {
		if (_referenciales.isEmpty) {
			setState(() => _documentoUnido = widget.pdfBytes);
			return;
		}

		setState(() => _procesando = true);
		try {
			final documentoFinal = sf.PdfDocument();
			final List<Uint8List> todosLosPdfs = [widget.pdfBytes, ..._referenciales.map((r) => r.bytes)];
			sf.PdfSection? seccion;

			for (final bytesPdf in todosLosPdfs) {
				final documentoFuente = sf.PdfDocument(inputBytes: bytesPdf);
				for (int i = 0; i < documentoFuente.pages.count; i++) {
					final paginaFuente = documentoFuente.pages[i];
					final template = paginaFuente.createTemplate();
					if (seccion == null || seccion.pageSettings.size != template.size) {
						seccion = documentoFinal.sections!.add();
						seccion.pageSettings.size = template.size;
						seccion.pageSettings.margins.all = 0;
					}
					seccion.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
				}
				documentoFuente.dispose();
			}

			final List<int> resultado = await documentoFinal.save();
			documentoFinal.dispose();

			setState(() {
				_documentoUnido = Uint8List.fromList(resultado);
				_procesando = false;
			});
		} catch (e) {
			debugPrint('Error al unir: $e');
			setState(() => _procesando = false);
		}
	}

	Future<void> _agregarReferencial() async {
		setState(() => _procesando = true);
		bool yaFirmado = false;
		try {
			yaFirmado = await ApiService().estaFirmado(pdfBytes: widget.pdfBytes, nombreArchivo: widget.nombreArchivo);
		} catch (e) {
			debugPrint('Error verificando firma: $e');
		} finally {
			setState(() => _procesando = false);
		}

		if (yaFirmado && mounted) {
			final anchoModal = MediaQuery.of(context).size.width * 0.6;
			final confirmar = await showDialog<bool>(
				context: context,
				barrierDismissible: false,
				builder: (ctx) => AlertDialog(
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
					insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
					content: SizedBox(
						width: anchoModal,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(Icons.warning_amber_rounded, color: ctx.errorRed, size: 48),
								const SizedBox(height: 16),
								Text('Documento ya firmado', style: TextStyle(fontWeight: FontWeight.bold, color: ctx.errorRed, fontSize: 20), textAlign: TextAlign.center),
								const SizedBox(height: 12),
								Text('El documento actual ya contiene firmas digitales.', style: TextStyle(fontWeight: FontWeight.bold, color: ctx.textDark, fontSize: 14), textAlign: TextAlign.center),
								const SizedBox(height: 12),
								Text('Si añades un documento referencial, el sistema reconstruirá el PDF y **perderás todas las firmas existentes**. Esta acción no se puede deshacer.', style: TextStyle(color: ctx.textGrey, fontSize: 13), textAlign: TextAlign.center),
							],
						),
					),
					actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
					actions: [
						Row(
							mainAxisAlignment: MainAxisAlignment.end,
							children: [
								TextButton(onPressed: () => Navigator.pop(ctx, false), style: TextButton.styleFrom(foregroundColor: ctx.textGrey), child: const Text('Cancelar')),
								const SizedBox(width: 12),
								ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ctx.errorRed), child: const Text('Añadir y perder firmas')),
							],
						),
					],
				),
			);
			if (confirmar != true) return;
		}

		final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
		if (result != null && result.files.single.bytes != null) {
			setState(() {
				_panelLateral = _PanelLateral.referenciales;
				_referenciales.add(DocumentoReferencial(id: DateTime.now().millisecondsSinceEpoch.toString(), nombre: result.files.single.name, bytes: result.files.single.bytes!));
				_actualizarDocumentoUnido();
			});
		}
	}

	void _eliminarReferencial(String id) {
		setState(() {
			_referenciales.removeWhere((element) => element.id == id);
			_actualizarDocumentoUnido();
		});
	}

	Future<void> _abrirAnexos() async {
		if (_procesando || _documentoYaFirmado || _cargandoAnexos) return;
		setState(() => _panelLateral = _PanelLateral.anexos);
		if (_reinicioPendiente || _urlAnexos != null) return;
		setState(() => _cargandoAnexos = true);
		try {
			if (_urlAnexos == null && !_preparandoEnlace) {
				_preparandoEnlace = true;
				try {
					final rutaBase = obtenerRutaNextcloud();
					final carpetaDestino = _esModoVistoBueno ? '$rutaBase$proyectados' : '$rutaBase$firmados';
					_sesionAnexos ??= await AnexosService.reservarSesion(carpetaDestino, widget.nombreArchivo);
					await AnexosService.prepararSesion(_sesionAnexos!);
					final url = _sesionAnexos!.url;
					if (!mounted) return;
					if (url == null) throw StateError('No se pudo generar el enlace público de anexos.');
					setState(() {
						_urlAnexos = url;
						_posicionQr ??= const Offset(0.1, 0.1);
					});
				} finally {
					_preparandoEnlace = false;
				}
			}
		} catch (e) {
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear enlace: $e')));
		} finally {
			if (mounted) setState(() => _cargandoAnexos = false);
		}
	}

	Future<void> _agregarAnexos() async {
		if (_documentoYaFirmado || _cargandoAnexos || _reinicioPendiente) return;
		if (_urlAnexos == null) {
			await _abrirAnexos();
			if (!mounted || _urlAnexos == null) return;
		}
		setState(() {
			_cargandoAnexos = true;
			_panelLateral = _PanelLateral.anexos;
		});
		try {
			final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['pdf']);
			if (result == null) return;
			final archivos = result.paths.whereType<String>().map((ruta) => File(ruta)).toList();
			if (archivos.isEmpty) return;
			for (final archivo in archivos) {
				if (p.extension(archivo.path).toLowerCase() != '.pdf') throw StateError('Solo se admiten archivos PDF.');
				if (!await archivo.exists()) throw StateError('Archivo no encontrado: ${archivo.path}');
			}
			if (!mounted) return;
			setState(() {
				for (final archivo in archivos) {
					if (!_anexosPendientes.any((existente) => existente.path == archivo.path)) {
						_anexosPendientes.add(archivo);
					}
				}
			});

		} catch (e) {
			debugPrint('[Anexos] Error: $e');
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al añadir anexos: $e')));
		} finally {
			if (mounted) setState(() => _cargandoAnexos = false);
		}
	}

	Future<void> _reiniciarAnexos() async {
		if (_procesando || _cargandoAnexos || _preparandoEnlace) return;
		setState(() { _cargandoAnexos = true; _reinicioPendiente = true; });
		try {
			if (_sesionAnexos != null) await AnexosService.reiniciarSesion(_sesionAnexos!);
			if (!mounted) return;
			setState(() {
				_sesionAnexos = null;
				_anexosPendientes.clear();
				_anexoSeleccionado = null;
				_urlAnexos = null;
				_posicionQr = null;
				_reinicioPendiente = false;
				_panelLateral = _PanelLateral.ninguno;
			});
		} catch (e) {
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se completó el reinicio. Reintenta: $e')));
		} finally {
			if (mounted) setState(() => _cargandoAnexos = false);
		}
	}

	void _eliminarAnexo(String ruta) {
		if (_cargandoAnexos || _reinicioPendiente) return;
		setState(() {
			_anexosPendientes.removeWhere((archivo) => archivo.path == ruta);
			if (_anexoSeleccionado?.path == ruta) _anexoSeleccionado = null;
		});
	}

	Offset _limitar(Offset p, int pagina) {
		if (_tamanos.isEmpty) return p;
		final s = _tamanos[pagina - 1];
		final double anchoActual = _esModoVistoBueno ? 56.0 : _anchoFirma;
		final double altoActual = _esModoVistoBueno ? 56.0 : _altoFirma;
		final double maxX = (1 - (anchoActual / s.width)) + (10 / s.width);
		final double maxY = (1 - (altoActual / s.height)) + (10 / s.height);
		return Offset(p.dx.clamp(0.0, maxX.clamp(0.0, 1.0)), p.dy.clamp(0.0, maxY.clamp(0.0, 1.0)));
	}

	Offset _limitarCorrelativo(Offset p, int pagina) {
		if (_tamanos.isEmpty) return p;
		final s = _tamanos[pagina - 1];
		final maxX = (1 - (_anchoCorrelativo / s.width)).clamp(0.0, 1.0);
		final maxY = (1 - (_altoCorrelativo / s.height)).clamp(0.0, 1.0);
		return Offset(p.dx.clamp(0.0, maxX), p.dy.clamp(0.0, maxY));
	}

	Offset _limitarQr(Offset p, int pagina) {
		if (_tamanos.isEmpty) return p;
		final s = _tamanos[pagina - 1];
		final maxX = (1 - (QrVisual.ancho / s.width)).clamp(0.0, 1.0);
		final maxY = (1 - (QrVisual.alto / s.height)).clamp(0.0, 1.0);
		return Offset(p.dx.clamp(0.0, maxX), p.dy.clamp(0.0, maxY));
	}

	void _irAPagina(int pagina) {
		if (!_pdfController.isReady) return;
		_pdfController.goToPage(pageNumber: pagina, anchor: PdfPageAnchor.all);
	}

	void _cambiarPagina(int delta) {
		final nueva = (_paginaFirma + delta).clamp(1, _totalPaginas);
		if (nueva == _paginaFirma) return;
		setState(() {
			_paginaFirma = nueva;
			_paginaCtrl.text = nueva.toString();
			if (_posicionPorcentual != null) _posicionPorcentual = _limitar(_posicionPorcentual!, nueva);
			if (_posicionCorrelativo != null) _posicionCorrelativo = _limitarCorrelativo(_posicionCorrelativo!, nueva);
			if (_posicionQr != null) _posicionQr = _limitarQr(_posicionQr!, nueva);
		});
		_irAPagina(nueva);
	}

	void _irAPaginaInput(String valor) {
		final num = int.tryParse(valor);
		if (num != null && num >= 1 && num <= _totalPaginas) {
			if (num == _paginaFirma) return;
			setState(() {
				_paginaFirma = num;
				if (_posicionPorcentual != null) _posicionPorcentual = _limitar(_posicionPorcentual!, num);
				if (_posicionCorrelativo != null) _posicionCorrelativo = _limitarCorrelativo(_posicionCorrelativo!, num);
				if (_posicionQr != null) _posicionQr = _limitarQr(_posicionQr!, num);
			});
			_irAPagina(num);
		} else {
			_paginaCtrl.text = _paginaFirma.toString();
		}
	}

	void _colocarAutomatico() {
		if (_tamanos.isEmpty) return;
		final n = _totalPaginas;
		final s = _tamanos[n - 1];
		if (_esModoVistoBueno) _posicionAuto = PosicionFirma.abajoIzquierda;
		final izq = _margen / s.width;
		final cen = (1 - _anchoFirma / s.width) / 2;
		final der = 1 - (_anchoFirma + _margen) / s.width;
		final arr = _margen / s.height;
		final aba = 1 - (_altoFirma + _margen) / s.height;
		final pos = switch (_posicionAuto) {
			PosicionFirma.arribaIzquierda => Offset(izq, arr),
			PosicionFirma.arribaCentro => Offset(cen, arr),
			PosicionFirma.arribaDerecha => Offset(der, arr),
			PosicionFirma.abajoIzquierda => Offset(izq, aba),
			PosicionFirma.abajoCentro => Offset(cen, aba),
			PosicionFirma.abajoDerecha => Offset(der, aba),
		};
		setState(() {
			_modoManual = false;
			_paginaFirma = 1;
			_paginaCtrl.text = '1';
			_posicionPorcentual = _limitar(pos, 1);
			_posicionAutoElegida = _posicionPorcentual;
		});
		_irAPagina(1);
	}

	void _elegirPosicionAuto(PosicionFirma p) {
		_posicionAuto = p;
		_colocarAutomatico();
	}

	void _colocarManual() {
		setState(() {
			_modoManual = true;
			_posicionPorcentual = null;
			_posicionAutoElegida = null;
		});
	}

	void _alSoltar(DragTargetDetails<Uint8List> details) {
		if (!_pdfController.isReady || _tamanos.isEmpty) return;
		final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
		if (box == null) return;
		final centroGlobal = details.offset + (_esModoVistoBueno ? const Offset(_ladoVb / 2, _ladoVb / 2) : const Offset(_anchoFirma / 2, _altoFirma / 2));
		final local = box.globalToLocal(centroGlobal);
		final inversa = Matrix4.inverted(_pdfController.value);
		final doc = MatrixUtils.transformPoint(inversa, local);
		final layouts = _pdfController.layout.pageLayouts;
		int idx = 0;
		double mejor = double.infinity;
		for (int i = 0; i < layouts.length; i++) {
			final r = layouts[i];
			final dx = math.max(math.max(r.left - doc.dx, 0.0), doc.dx - r.right);
			final dy = math.max(math.max(r.top - doc.dy, 0.0), doc.dy - r.bottom);
			final d = dx * dx + dy * dy;
			if (d < mejor) { mejor = d; idx = i; }
		}
		final rect = layouts[idx];
		final size = _tamanos[idx];
		final cx = (doc.dx - rect.left) / rect.width;
		final cy = (doc.dy - rect.top) / rect.height;
		setState(() {
			_paginaFirma = idx + 1;
			_paginaCtrl.text = (idx + 1).toString();
			if (_esModoVistoBueno) {
				final pos = _limitarVb(Offset(cx - _ladoVb / size.width / 2, cy - _ladoVb / size.height / 2), idx + 1);
				if (_vbTodas) {
					_vbReferencia = pos;
				} else {
					_vbPosiciones.putIfAbsent(idx + 1, () => []).add(pos);
				}
			} else {
				_posicionPorcentual = _limitar(Offset(cx - (_anchoFirma / size.width) / 2, cy - (_altoFirma / size.height) / 2), idx + 1);
			}
		});
	}

	void _alSoltarCorrelativo(DragTargetDetails<_ArrastreCorrelativo> details) {
		if (!_pdfController.isReady || _tamanos.isEmpty) return;
		final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
		if (box == null) return;
		final centroGlobal = details.offset + const Offset(_anchoCorrelativo / 2, _altoCorrelativo / 2);
		final local = box.globalToLocal(centroGlobal);
		final inversa = Matrix4.inverted(_pdfController.value);
		final doc = MatrixUtils.transformPoint(inversa, local);
		final layouts = _pdfController.layout.pageLayouts;
		int idx = 0;
		double mejor = double.infinity;
		for (int i = 0; i < layouts.length; i++) {
			final r = layouts[i];
			final dx = math.max(math.max(r.left - doc.dx, 0.0), doc.dx - r.right);
			final dy = math.max(math.max(r.top - doc.dy, 0.0), doc.dy - r.bottom);
			final d = dx * dx + dy * dy;
			if (d < mejor) { mejor = d; idx = i; }
		}
		final rect = layouts[idx];
		final size = _tamanos[idx];
		final cx = (doc.dx - rect.left) / rect.width;
		final cy = (doc.dy - rect.top) / rect.height;
		setState(() {
			_paginaFirma = idx + 1;
			_paginaCtrl.text = (idx + 1).toString();
			_posicionCorrelativo = _limitarCorrelativo(Offset(cx - (_anchoCorrelativo / size.width) / 2, cy - (_altoCorrelativo / size.height) / 2), idx + 1);
		});
	}

	void _alSoltarQr(DragTargetDetails<_ArrastreQr> details) {
		if (!_pdfController.isReady || _tamanos.isEmpty) return;
		final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
		if (box == null) return;
		final centroGlobal = details.offset + const Offset(QrVisual.ancho / 2, QrVisual.alto / 2);
		final local = box.globalToLocal(centroGlobal);
		final inversa = Matrix4.inverted(_pdfController.value);
		final doc = MatrixUtils.transformPoint(inversa, local);
		final layouts = _pdfController.layout.pageLayouts;
		int idx = 0;
		double mejor = double.infinity;
		for (int i = 0; i < layouts.length; i++) {
			final r = layouts[i];
			final dx = math.max(math.max(r.left - doc.dx, 0.0), doc.dx - r.right);
			final dy = math.max(math.max(r.top - doc.dy, 0.0), doc.dy - r.bottom);
			final d = dx * dx + dy * dy;
			if (d < mejor) { mejor = d; idx = i; }
		}
		final rect = layouts[idx];
		final size = _tamanos[idx];
		final cx = (doc.dx - rect.left) / rect.width;
		final cy = (doc.dy - rect.top) / rect.height;
		setState(() {
			_paginaFirma = idx + 1;
			_paginaCtrl.text = (idx + 1).toString();
			_posicionQr = _limitarQr(Offset(cx - (QrVisual.ancho / size.width) / 2, cy - (QrVisual.alto / size.height) / 2), idx + 1);
		});
	}

	Future<void> _confirmar() async {
		if (_anexoSeleccionado != null) return;
		if (_cargandoAnexos || _reinicioPendiente) return;
		if (_esModoVistoBueno ? !_hayVb : _posicionPorcentual == null) return;
		if ((_sesionAnexos != null || _anexosPendientes.isNotEmpty) && _urlAnexos == null) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo preparar el enlace de anexos. Vuelve a presionar el botón de nube.')));
			return;
		}
		if (!_esModoVistoBueno && !_hardwareDisponible) return;
		if (_urlAnexos != null && _posicionQr == null) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes arrastrar el QR de anexos al documento antes de firmar.')));
			return;
		}

		setState(() => _procesando = true);
		_detector.pausar();

		try {
			bool yaFirmado = false;
			if (_foliarDocumento) {
				try {
					yaFirmado = await ApiService().estaFirmado(pdfBytes: widget.pdfBytes, nombreArchivo: widget.nombreArchivo);
				} catch (e) {
					debugPrint('Error verificando firma para foliado: $e');
				}
			}

			final boundary = _selloKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
			if (boundary == null) throw Exception('No se encontró el sello visual');
			await Future.delayed(const Duration(milliseconds: 100));
			final image = await boundary.toImage(pixelRatio: 3.0);
			final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
			final pngBytes = byteData!.buffer.asUint8List();

			Uint8List documentoParaFirmar = _documentoUnido;

			if (!_documentoYaFirmado) {
				if ((_foliarDocumento && !yaFirmado) || _posicionCorrelativo != null || _posicionQr != null) {
					final docFoliar = sf.PdfDocument(inputBytes: documentoParaFirmar);
					final int total = docFoliar.pages.count;

					if (_foliarDocumento && !yaFirmado) {
						final fuenteFoliar = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 8);
						final negroFoliar = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));
						for (int i = 0; i < total; i++) {
							final page = docFoliar.pages[i];
							final numFolio = total - i;
							final xFolio = page.size.width - 30;
							final yFolio = page.size.height - 20;
							page.graphics.drawString('$numFolio', fuenteFoliar, brush: negroFoliar, bounds: Rect.fromLTWH(xFolio, yFolio, 0, 0));
						}
					}

					if (_posicionCorrelativo != null && _correlativoCtrl.text.isNotEmpty) {
						final page = docFoliar.pages[_paginaFirma - 1];
						final pos = _posicionCorrelativo!;
						final xBox = pos.dx * page.size.width;
						final yBox = pos.dy * page.size.height;
						final fuenteCorr = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, _fuenteCorrelativo, style: sf.PdfFontStyle.bold);
						final negroCorr = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));
						final texto = _correlativoCtrl.text;
						final sizeTexto = fuenteCorr.measureString(texto);
						final centroX = xBox + (_anchoCorrelativo / 2);
						final centroY = yBox + (_altoCorrelativo / 2);
						const double capHeightRatio = 0.718;
						final double capHeightPts = capHeightRatio * _fuenteCorrelativo;
						final double xFinal = centroX - (sizeTexto.width / 2);
						final double yBaseline = centroY - (capHeightPts / 2);
						page.graphics.drawString(texto, fuenteCorr, brush: negroCorr, bounds: Rect.fromLTWH(xFinal, yBaseline, 0, 0));
					}
					
					if (_posicionQr != null && _urlAnexos != null) {
						final page = docFoliar.pages[_paginaFirma - 1];
						final pos = _posicionQr!;
						final xBox = pos.dx * page.size.width;
						final yBox = pos.dy * page.size.height;
						
						final boundaryQr = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
						if (boundaryQr == null) throw StateError('No se pudo capturar el QR.');
						final qrImageCaptured = await boundaryQr.toImage(pixelRatio: 6.0);
						final datosQr = await qrImageCaptured.toByteData(format: ui.ImageByteFormat.png);
						qrImageCaptured.dispose();
						if (datosQr == null) throw StateError('No se pudo generar la imagen del QR.');
						final url = _urlAnexos!;
						final rectQr = Rect.fromLTWH(xBox + QrVisual.margen, yBox + QrVisual.alto - QrVisual.margen - QrVisual.ladoQr, QrVisual.ladoQr, QrVisual.ladoQr);
						page.graphics.drawImage(sf.PdfBitmap(datosQr.buffer.asUint8List()), rectQr);
						var fuente = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, QrVisual.fuenteUrl);
						final anchoTexto = fuente.measureString(url).width;
						if (anchoTexto > QrVisual.anchoUrl) {
							fuente = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, QrVisual.fuenteUrl * QrVisual.anchoUrl / anchoTexto);
						}
						final medida = fuente.measureString(url);
						final rectUrl = Rect.fromLTWH(xBox + QrVisual.xUrl, yBox + QrVisual.alto - QrVisual.margen - QrVisual.margenInferiorUrl - medida.height, medida.width, medida.height);
						page.graphics.drawString(url, fuente, brush: sf.PdfSolidBrush(sf.PdfColor(0, 0, 0)), bounds: rectUrl);
						page.annotations.add(sf.PdfUriAnnotation(bounds: rectUrl, uri: url));
						page.annotations.add(sf.PdfUriAnnotation(bounds: rectQr, uri: url));
					}

					final foliadoBytes = await docFoliar.save();
					docFoliar.dispose();
					documentoParaFirmar = Uint8List.fromList(foliadoBytes);
				}
			}

			if (_esModoVistoBueno) {
				final decoded = img.decodeImage(pngBytes);
				if (decoded == null) throw Exception('No se pudo decodificar la imagen');
				final bitmap = sf.PdfBitmap(img.encodePng(decoded));
				final document = sf.PdfDocument(inputBytes: documentoParaFirmar);
				for (int numero = 1; numero <= document.pages.count; numero++) {
					final page = document.pages[numero - 1];
					for (final pos in _vistosEnPagina(numero)) {
						page.graphics.drawImage(bitmap, Rect.fromLTWH(pos.dx * page.size.width, pos.dy * page.size.height, _ladoVb, _ladoVb));
					}
				}
				final List<int> resultado = await document.save();
				document.dispose();
				if (!mounted) return;
				Navigator.of(context).pop({'pdfBytes': Uint8List.fromList(resultado), 'requiereFirma': false, 'anexosPendientes': List<File>.from(_anexosPendientes), 'sesionAnexos': _sesionAnexos, 'urlAnexos': _urlAnexos});
			} else {
				final pos = _posicionPorcentual!;
				final pageSize = _tamanos[_paginaFirma - 1];
				double xPuntos = pos.dx * pageSize.width;
				double yPuntos = pos.dy * pageSize.height;
				xPuntos = xPuntos.clamp(0.0, pageSize.width - _anchoFirma);
				yPuntos = yPuntos.clamp(0.0, pageSize.height - _altoFirma);
				if (!mounted) return;
				Navigator.of(context).pop({
					'pdfBytes': documentoParaFirmar,
					'requiereFirma': true,
					'anexosPendientes': List<File>.from(_anexosPendientes),
					'sesionAnexos': _sesionAnexos, 'urlAnexos': _urlAnexos,
					'imagenSello': pngBytes,
					'pagina': _paginaFirma,
					'x': xPuntos,
					'y': yPuntos,
					'ancho': _anchoFirma,
					'alto': _altoFirma,
				});
			}
		} catch (e) {
			debugPrint('[EditorFirma] Error: $e');
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
		} finally {
			if (mounted) {
				setState(() => _procesando = false);
				_detector.reanudar();
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final widgetFantasma = Positioned(
			left: -2000,
			child: Material(
				color: Colors.transparent,
				child: RepaintBoundary(
					key: _selloKey,
					child: SizedBox(
						width: _esModoVistoBueno ? _ladoVb : _anchoFirma,
						height: _esModoVistoBueno ? _ladoVb : _altoFirma,
						child: _esModoVistoBueno ? _selloVb() : SelloFirmaVisual(
							esModoVistoBueno: _esModoVistoBueno,
							hardwareDisponible: _hardwareDisponible,
							nombreFirmante: _nombreFirmante,
							dniFirmante: _dniFirmante,
							cargoSeleccionado: _cargoSeleccionado ?? '',
							motivoSeleccionado: _motivoSeleccionado,
							direccionOficina: _direccionOficina,
							totalPaginas: _totalPaginas,
							imagenFirmaBytes: widget.imagenFirmaBytes,
							imagenVistoBuenoBytes: widget.imagenVistoBuenoBytes,
							anchoFirma: _anchoFirma,
							altoFirma: _altoFirma,
							ladoImagen: _lado,
						),
					),
				),
			),
		);

		final qrFantasma = _urlAnexos != null ? Positioned(
			left: -2000,
			child: Material(
				color: Colors.transparent,
				child: RepaintBoundary(
					key: _qrKey,
					child: QrVisual.imagenQr(_urlAnexos!),
				),
			),
		) : const SizedBox.shrink();

		return Scaffold(
			backgroundColor: context.backgroundLight,
			appBar: AppBar(title: const Text('Firma del documento'), elevation: 0, backgroundColor: context.surfaceWhite, foregroundColor: context.textDark),
			body: Row(
				children: [
					if (_panelLateral == _PanelLateral.referenciales && _referenciales.isNotEmpty)
						DocumentosSidebar(
							nombreArchivo: widget.nombreArchivo,
							referenciales: _referenciales,
							onCerrar: () => setState(() => _panelLateral = _PanelLateral.ninguno),
							onEliminar: _eliminarReferencial,
							onReorder: (oldIndex, newIndex) {
								setState(() {
									if (newIndex > oldIndex) newIndex -= 1;
									final item = _referenciales.removeAt(oldIndex);
									_referenciales.insert(newIndex, item);
									_actualizarDocumentoUnido();
								});
							},
						),
					if (_panelLateral == _PanelLateral.anexos)
						AnexosSlider(
							nombreArchivo: widget.nombreArchivo,
							anexos: _anexosPendientes,
							rutaSeleccionada: _anexoSeleccionado?.path,
							onSeleccionar: (archivo) => setState(() => _anexoSeleccionado = archivo),
							onEliminar: _eliminarAnexo,
							onReiniciar: _reiniciarAnexos,
							puedeReiniciar: _sesionAnexos != null || _reinicioPendiente || _anexosPendientes.isNotEmpty,
							onAgregar: _agregarAnexos,
							onCerrar: () => setState(() {
								_panelLateral = _PanelLateral.ninguno;
								_anexoSeleccionado = null;
							}),
							ocupado: _cargandoAnexos || _procesando || _preparandoEnlace,
						),
					Expanded(
						child: IndexedStack(
							index: _anexoSeleccionado == null ? 0 : 1,
							sizing: StackFit.expand,
							children: [
								Container(
									margin: const EdgeInsets.all(24),
									decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusLg), border: Border.all(color: context.borderColor)),
									child: ClipRRect(
										borderRadius: BorderRadius.circular(context.radiusLg),
										child: Stack(
											key: _stackKey,
											children: [
												if (_documentoUnido.isNotEmpty)
													PdfViewer.data(
														key: ValueKey(_documentoUnido.length),
														_documentoUnido,
														sourceName: widget.nombreArchivo,
														controller: _pdfController,
														params: PdfViewerParams(
															backgroundColor: context.surfaceGrey,
															onViewerReady: (document, controller) {
																setState(() {
																	_totalPaginas = document.pages.length;
																	_tamanos = document.pages.map((p) => Size(p.width, p.height)).toList();
																	if (_posicionPorcentual != null) _posicionPorcentual = _limitar(_posicionPorcentual!, _paginaFirma);
																	if (_posicionCorrelativo != null) _posicionCorrelativo = _limitarCorrelativo(_posicionCorrelativo!, _paginaFirma);
																	if (_posicionQr != null) _posicionQr = _limitarQr(_posicionQr!, _paginaFirma);
																});
															},
															pageOverlaysBuilder: (context, pageRect, page) {
																final List<Widget> overlays = [];
		
																if (_esModoVistoBueno) {
																	final posiciones = _vistosEnPagina(page.pageNumber);
																	final lado = _ladoVb * pageRect.width / page.width;
																	for (int i = 0; i < posiciones.length; i++) {
																		final pos = posiciones[i];
																		overlays.add(Positioned(
																			left: pos.dx * pageRect.width,
																			top: pos.dy * pageRect.height,
																			width: lado, height: lado,
																			child: Stack(children: [
																				Positioned.fill(child: GestureDetector(
																					onPanUpdate: _procesando ? null : (details) => setState(() {
																						final actual = _vistosEnPagina(page.pageNumber)[i];
																						final nuevo = _limitarVb(actual + Offset(details.delta.dx / pageRect.width, details.delta.dy / pageRect.height), page.pageNumber);
																						if (_vbTodas) { _vbReferencia = nuevo; } else { _vbPosiciones[page.pageNumber]![i] = nuevo; }
																					}),
																					child: MouseRegion(cursor: SystemMouseCursors.grab, child: FittedBox(child: _selloVb())),
																				)),
																				Positioned(top: 0, right: 0, child: GestureDetector(
																					onTap: _procesando ? null : () => setState(() {
																						if (_vbTodas) { _vbReferencia = null; } else { _vbPosiciones[page.pageNumber]!.removeAt(i); }
																					}),
																					child: const MouseRegion(cursor: SystemMouseCursors.click, child: Icon(Icons.cancel, color: Colors.red, size: 14)),
																				)),
																			]),
																		));
																	}
																}
																
																if (!_esModoVistoBueno && _posicionPorcentual != null && page.pageNumber == _paginaFirma) {
																	final escala = pageRect.width / page.width;
																	overlays.add(
																		Positioned(
																			left: _posicionPorcentual!.dx * pageRect.width,
																			top: _posicionPorcentual!.dy * pageRect.height,
																			width: _anchoFirma * escala,
																			height: _altoFirma * escala,
																			child: GestureDetector(
																				onPanUpdate: (details) {
																					setState(() {
																						final nuevo = Offset(_posicionPorcentual!.dx + details.delta.dx / pageRect.width, _posicionPorcentual!.dy + details.delta.dy / pageRect.height);
																						_posicionPorcentual = _limitar(nuevo, _paginaFirma);
																					});
																				},
																				child: MouseRegion(
																					cursor: SystemMouseCursors.grab,
																					child: FittedBox(
																						fit: BoxFit.fill,
																						child: SelloFirmaVisual(
																							esModoVistoBueno: _esModoVistoBueno,
																							hardwareDisponible: _hardwareDisponible,
																							nombreFirmante: _nombreFirmante,
																							dniFirmante: _dniFirmante,
																							cargoSeleccionado: _cargoSeleccionado ?? '',
																							motivoSeleccionado: _motivoSeleccionado,
																							direccionOficina: _direccionOficina,
																							totalPaginas: _totalPaginas,
																							imagenFirmaBytes: widget.imagenFirmaBytes,
																							imagenVistoBuenoBytes: widget.imagenVistoBuenoBytes,
																							anchoFirma: _anchoFirma,
																							altoFirma: _altoFirma,
																							ladoImagen: _lado,
																						),
																					),
																				),
																			),
																		),
																	);
																}
		
																if (_correlativoCtrl.text.isNotEmpty && _posicionCorrelativo != null && page.pageNumber == _paginaFirma) {
																	final escala = pageRect.width / page.width;
																	overlays.add(
																		Positioned(
																			left: _posicionCorrelativo!.dx * pageRect.width,
																			top: _posicionCorrelativo!.dy * pageRect.height,
																			width: _anchoCorrelativo * escala,
																			height: _altoCorrelativo * escala,
																			child: GestureDetector(
																				onPanUpdate: (details) {
																					setState(() {
																						final nuevo = Offset(_posicionCorrelativo!.dx + details.delta.dx / pageRect.width, _posicionCorrelativo!.dy + details.delta.dy / pageRect.height);
																						_posicionCorrelativo = _limitarCorrelativo(nuevo, _paginaFirma);
																					});
																				},
																				child: MouseRegion(
																					cursor: SystemMouseCursors.grab,
																					child: FittedBox(
																						fit: BoxFit.fill,
																						child: CorrelativoVisual(
																							texto: _correlativoCtrl.text,
																							fuente: _fuenteCorrelativo,
																							ancho: _anchoCorrelativo,
																							alto: _altoCorrelativo,
																						),
																					),
																				),
																			),
																		),
																	);
																}
		
																if (_urlAnexos != null && _posicionQr != null && page.pageNumber == _paginaFirma) {
																	final escala = pageRect.width / page.width;
																	overlays.add(
																		Positioned(
																			left: _posicionQr!.dx * pageRect.width,
																			top: _posicionQr!.dy * pageRect.height,
																			width: QrVisual.ancho * escala,
																			height: QrVisual.alto * escala,
																			child: GestureDetector(
																				onPanUpdate: (details) {
																					setState(() {
																						final nuevo = Offset(_posicionQr!.dx + details.delta.dx / pageRect.width, _posicionQr!.dy + details.delta.dy / pageRect.height);
																						_posicionQr = _limitarQr(nuevo, _paginaFirma);
																					});
																				},
																				child: MouseRegion(
																					cursor: SystemMouseCursors.grab,
																					child: FittedBox(
																						fit: BoxFit.contain,
																						child: QrVisual(url: _urlAnexos!, resaltadoRojo: false),
																					),
																				),
																			),
																		),
																	);
																}
		
																return overlays;
															},
														),
													),
												widgetFantasma,
												qrFantasma,
		
												if (_totalPaginas > 1)
													Positioned(
														top: 12,
														left: 0,
														right: 0,
														child: Center(
															child: Material(
																color: context.surfaceWhite,
																elevation: 3,
																borderRadius: BorderRadius.circular(context.radiusPill),
																child: Padding(
																	padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
																	child: Row(
																		mainAxisSize: MainAxisSize.min,
																		children: [
																			IconButton(
																				onPressed: _paginaFirma > 1 ? () {
																					setState(() {
																						_paginaFirma = 1;
																						_paginaCtrl.text = '1';
																						if (_posicionPorcentual != null) _posicionPorcentual = _limitar(_posicionPorcentual!, 1);
																						if (_posicionCorrelativo != null) _posicionCorrelativo = _limitarCorrelativo(_posicionCorrelativo!, 1);
																						if (_posicionQr != null) _posicionQr = _limitarQr(_posicionQr!, 1);
																					});
																					_irAPagina(1);
																				} : null,
																				icon: const Icon(Icons.first_page_rounded, size: 20),
																				padding: EdgeInsets.zero,
																				constraints: const BoxConstraints(minWidth: 32),
																				color: context.textDark,
																				tooltip: 'Ir al inicio',
																			),
																			IconButton(
																				onPressed: _paginaFirma > 1 ? () => _cambiarPagina(-1) : null,
																				icon: const Icon(Icons.chevron_left_rounded, size: 20),
																				padding: EdgeInsets.zero,
																				constraints: const BoxConstraints(minWidth: 32),
																				color: context.textDark,
																			),
																			Padding(
																				padding: const EdgeInsets.symmetric(horizontal: 8),
																				child: Row(
																					children: [
																						Text('Página', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textGrey)),
																						const SizedBox(width: 8),
																						Container(
																							width: 36,
																							height: 28,
																							decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusSm)),
																							alignment: Alignment.center,
																							child: TextField(
																								controller: _paginaCtrl,
																								textAlign: TextAlign.center,
																								style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textDark),
																								decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
																								onSubmitted: _irAPaginaInput,
																							),
																						),
																						const SizedBox(width: 8),
																						Text('de $_totalPaginas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textGrey)),
																					],
																				),
																			),
																			IconButton(
																				onPressed: _paginaFirma < _totalPaginas ? () => _cambiarPagina(1) : null,
																				icon: const Icon(Icons.chevron_right_rounded, size: 20),
																				padding: EdgeInsets.zero,
																				constraints: const BoxConstraints(minWidth: 32),
																				color: context.textDark,
																			),
																			IconButton(
																				onPressed: _paginaFirma < _totalPaginas ? () {
																					setState(() {
																						_paginaFirma = _totalPaginas;
																						_paginaCtrl.text = _totalPaginas.toString();
																						if (_posicionPorcentual != null) _posicionPorcentual = _limitar(_posicionPorcentual!, _totalPaginas);
																						if (_posicionCorrelativo != null) _posicionCorrelativo = _limitarCorrelativo(_posicionCorrelativo!, _totalPaginas);
																						if (_posicionQr != null) _posicionQr = _limitarQr(_posicionQr!, _totalPaginas);
																					});
																					_irAPagina(_totalPaginas);
																				} : null,
																				icon: const Icon(Icons.last_page_rounded, size: 20),
																				padding: EdgeInsets.zero,
																				constraints: const BoxConstraints(minWidth: 32),
																				color: context.textDark,
																				tooltip: 'Ir al final',
																			),
																		],
																	),
																),
															),
														),
													),
		
												Positioned.fill(
													child: DragTarget<Uint8List>(
														onAcceptWithDetails: _alSoltar,
														builder: (context, candidateData, rejectedData) {
															return IgnorePointer(child: Container(color: candidateData.isNotEmpty ? context.primaryPurple.withValues(alpha: 0.05) : Colors.transparent));
														},
													),
												),
		
												Positioned.fill(
													child: DragTarget<_ArrastreCorrelativo>(
														onAcceptWithDetails: _alSoltarCorrelativo,
														builder: (context, candidateData, rejectedData) {
															return IgnorePointer(child: Container(color: candidateData.isNotEmpty ? Colors.black.withValues(alpha: 0.05) : Colors.transparent));
														},
													),
												),
		
												Positioned.fill(
													child: DragTarget<_ArrastreQr>(
														onAcceptWithDetails: _alSoltarQr,
														builder: (context, candidateData, rejectedData) {
															return IgnorePointer(child: Container(color: candidateData.isNotEmpty ? Colors.black.withValues(alpha: 0.05) : Colors.transparent));
														},
													),
												),
		
												Positioned(
													top: 12,
													right: 12,
													child: Column(
														children: [
															BotonZoom(icono: Icons.add_rounded, tooltip: 'Acercar', onTap: () { if (_pdfController.isReady) _pdfController.zoomUp(); }),
															const SizedBox(height: 8),
															BotonZoom(icono: Icons.remove_rounded, tooltip: 'Alejar', onTap: () { if (_pdfController.isReady) _pdfController.zoomDown(); }),
															const SizedBox(height: 8),
															BotonZoom(icono: Icons.fit_screen_rounded, tooltip: 'Ajustar página', onTap: () { _irAPagina(_pdfController.pageNumber ?? 1); }),
														],
													),
												),
												Positioned(
													bottom: 24,
													left: 0,
													right: 0,
													child: Center(
														child: Row(
															mainAxisSize: MainAxisSize.min,
															children: [
																// FloatingActionButton(
																// 	// ======================================================
																// 	// BOTÓN DOCUMENTOS REFERENCIALES: NO COMENTAR AÚN
																// 	// ======================================================
																// 	heroTag: 'btn_ref',
																// 	onPressed: _procesando ? null : _agregarReferencial,
																// 	backgroundColor: context.primaryPurple,
																// 	foregroundColor: Colors.white,
																// 	tooltip: _procesando ? 'Verificando documento...' : 'Añadir documento referencial',
																// 	child: _procesando
																// 			? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
																// 			: const Icon(Icons.attach_file_rounded),
																// ),
																// const SizedBox(width: 16),
																FloatingActionButton(
																	// ======================================================
																	// BOTÓN ANEXOS: NO COMENTAR AÚN
																	// ======================================================
																	heroTag: 'btn_anexos',
																	onPressed: (_procesando || _cargandoAnexos || _documentoYaFirmado) ? null : _abrirAnexos,
																	backgroundColor: context.primaryPurple,
																	foregroundColor: Colors.white,
																	tooltip: _documentoYaFirmado ? 'Documento ya firmado' : 'Añadir documento referencial',
																	child: _cargandoAnexos ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload_rounded),
																),
															],
														),
													),
												),
											],
										),
									),
								),
								if (_anexoSeleccionado != null)
									VisorAnexo(key: ValueKey(_anexoSeleccionado!.path), archivo: _anexoSeleccionado!)
								else
									const SizedBox.shrink(),
							],
						),
					),
					if (_anexoSeleccionado != null)
						Container(
							width: 300,
							color: context.surfaceWhite,
							padding: const EdgeInsets.all(24),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									const Icon(Icons.lock_outline, size: 36),
									const SizedBox(height: 16),
									const Text('Modo solo lectura', textAlign: TextAlign.center),
									const SizedBox(height: 12),
									const Text('Selecciona el documento principal para continuar con la firma.'),
									const Spacer(),
									const ElevatedButton(onPressed: null, child: Text('Confirmar firma')),
									TextButton(onPressed: () => setState(() => _anexoSeleccionado = null), child: const Text('Volver al documento principal')),
								],
							),
						)
					else
					Container(
						width: 300,
						decoration: BoxDecoration(color: context.surfaceWhite, border: Border(left: BorderSide(color: context.borderColor))),
						child: Column(
							children: [
								Expanded(
									child: SingleChildScrollView(
										padding: const EdgeInsets.all(24),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.stretch,
											children: [
												Text('Firma del documento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.textDark)),
												const SizedBox(height: 8),
												Text('Elige cómo deseas colocar tu firma antes de firmar el documento.', style: TextStyle(fontSize: 14, color: context.textGrey)),
												const SizedBox(height: 24),
												Container(
													padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
													decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusMd), border: Border.all(color: context.borderColor)),
													child: Row(
														mainAxisAlignment: MainAxisAlignment.spaceBetween,
														children: [
															IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 20), color: context.textDark, onPressed: () => _alternarModo(false)),
															Text(_esModoVistoBueno ? 'Visto Bueno' : 'Firma', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textDark)),
															IconButton(icon: const Icon(Icons.chevron_right_rounded, size: 20), color: context.textDark, onPressed: () => _alternarModo(true)),
														],
													),
												),
												const SizedBox(height: 16),
												Text(_esModoVistoBueno ? 'Motivo de visto bueno' : 'Motivo de firma', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textDark)),
												const SizedBox(height: 4),
												DropdownButtonFormField<String>(
													value: _motivoSeleccionado,
													isExpanded: true,
													decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
													items: (_esModoVistoBueno ? _motivosVbDisponibles : _motivosFirmaDisponibles).map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
													onChanged: (val) { if (val != null) setState(() => _motivoSeleccionado = val); },
												),
												if (_cargosDisponibles.isNotEmpty && !_esModoVistoBueno) ...[
													const SizedBox(height: 12),
													Text('Cargo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textDark)),
													const SizedBox(height: 4),
													DropdownButtonFormField<String>(
														value: _cargoSeleccionado,
														isExpanded: true,
														decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
														items: _cargosDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
														onChanged: (val) { setState(() => _cargoSeleccionado = val); },
													),
												],
												const Divider(height: 32),
												if (!_esModoVistoBueno) ...[
													OutlinedButton.icon(
														onPressed: _colocarManual,
														style: OutlinedButton.styleFrom(
															backgroundColor: context.primaryPurple.withValues(alpha: 0.1),
															foregroundColor: context.primaryPurple,
															side: BorderSide(color: context.primaryPurple),
															padding: const EdgeInsets.symmetric(vertical: 16),
															shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusMd)),
														),
														icon: const Icon(Icons.touch_app_outlined, size: 20),
														label: const Text('Firma manual'),
													),
													const SizedBox(height: 24),
												],
												Center(
													child: Draggable<Uint8List>(
														data: widget.imagenFirmaBytes,
														dragAnchorStrategy: (draggable, context, position) => _esModoVistoBueno ? const Offset(_ladoVb / 2, _ladoVb / 2) : const Offset(_anchoFirma / 2, _altoFirma / 2),
														feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.85, child: _esModoVistoBueno ? _selloVb() : SelloFirmaVisual(esModoVistoBueno: _esModoVistoBueno, hardwareDisponible: _hardwareDisponible, nombreFirmante: _nombreFirmante, dniFirmante: _dniFirmante, cargoSeleccionado: _cargoSeleccionado ?? '', motivoSeleccionado: _motivoSeleccionado, direccionOficina: _direccionOficina, totalPaginas: _totalPaginas, imagenFirmaBytes: widget.imagenFirmaBytes, imagenVistoBuenoBytes: widget.imagenVistoBuenoBytes, anchoFirma: _anchoFirma, altoFirma: _altoFirma, ladoImagen: _lado))),
														childWhenDragging: Opacity(opacity: 0.3, child: Image.memory(_esModoVistoBueno ? widget.imagenVistoBuenoBytes : widget.imagenFirmaBytes, width: 50, height: 50)),
														child: Container(
															padding: const EdgeInsets.all(8),
															decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusMd), border: Border.all(color: context.borderColor)),
															child: Column(
																children: [
																	Image.memory(_esModoVistoBueno ? widget.imagenVistoBuenoBytes : widget.imagenFirmaBytes, width: 50, height: 50),
																	const SizedBox(height: 8),
																	Text('Arrastra el sello hacia\nel documento', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textGrey, fontWeight: FontWeight.w500)),
																],
															),
														),
													),
												),
												const SizedBox(height: 16),
												if (_esModoVistoBueno) ...[
													Container(
														padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
														decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusMd), border: Border.all(color: context.borderColor)),
														child: Row(children: [
															Icon(Icons.layers_outlined, size: 20, color: context.textDark),
															const SizedBox(width: 8),
															Expanded(child: Text('Visto bueno en todas las páginas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textDark))),
															Switch(value: _vbTodas, activeColor: context.primaryPurple, onChanged: _procesando ? null : (val) => setState(() { _vbTodas = val; _reiniciarVb(); })),
														]),
													),
													const SizedBox(height: 16),
												],
												Container(
													padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
													decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusMd), border: Border.all(color: context.borderColor)),
													child: Row(
														mainAxisAlignment: MainAxisAlignment.spaceBetween,
														children: [
															Row(children: [
																Icon(Icons.format_list_numbered_rounded, size: 20, color: context.textDark),
																const SizedBox(width: 8),
																Text('Foliar documento', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textDark)),
															]),
															Switch(value: _foliarDocumento, activeColor: context.primaryPurple, onChanged: (val) => setState(() => _foliarDocumento = val)),
														],
													),
												),
												if (!_documentoYaFirmado) ...[
													const SizedBox(height: 16),
													Container(
														padding: const EdgeInsets.all(12),
														decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusMd), border: Border.all(color: context.borderColor)),
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Row(
																	mainAxisAlignment: MainAxisAlignment.spaceBetween,
																	children: [
																		Text('Correlativo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textDark)),
																		Row(children: [
																			if (_correlativoCtrl.text.isNotEmpty)
																				IconButton(
																					onPressed: () { setState(() { _correlativoCtrl.clear(); _posicionCorrelativo = null; }); },
																					icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
																					padding: EdgeInsets.zero,
																					constraints: const BoxConstraints(),
																					tooltip: 'Quitar correlativo',
																				),
																			const SizedBox(width: 8),
																			IconButton(onPressed: () => setState(() => _fuenteCorrelativo = (_fuenteCorrelativo - 2).clamp(8, 30)), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
																			IconButton(onPressed: () => setState(() => _fuenteCorrelativo = (_fuenteCorrelativo + 2).clamp(8, 30)), icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
																		]),
																	],
																),
																const SizedBox(height: 8),
																if (_correlativoCtrl.text.isNotEmpty)
																	Center(
																		child: Draggable<_ArrastreCorrelativo>(
													data: _ArrastreCorrelativo(_correlativoCtrl.text),
																			dragAnchorStrategy: (draggable, context, position) => const Offset(_anchoCorrelativo / 2, _altoCorrelativo / 2),
																			feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.85, child: CorrelativoVisual(texto: _correlativoCtrl.text, fuente: _fuenteCorrelativo, ancho: _anchoCorrelativo, alto: _altoCorrelativo))),
																			childWhenDragging: Opacity(opacity: 0.3, child: Icon(Icons.drag_indicator, color: context.textGrey)),
																			child: CorrelativoVisual(texto: _correlativoCtrl.text, fuente: _fuenteCorrelativo, ancho: _anchoCorrelativo, alto: _altoCorrelativo),
																		),
																	),
																const SizedBox(height: 8),
																TextField(
																	controller: _correlativoCtrl,
																	maxLength: 5,
																	inputFormatters: [FilteringTextInputFormatter.digitsOnly],
																	decoration: InputDecoration(hintText: 'Ej. 15', filled: true, fillColor: context.surfaceWhite, isDense: true, counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
																	style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
																	onChanged: (val) { setState(() { if (val.trim().isEmpty) _posicionCorrelativo = null; }); },
																),
															],
														),
													),
												],
												if (_urlAnexos != null) ...[
													const SizedBox(height: 16),
													Container(
														padding: const EdgeInsets.all(12),
														decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusMd), border: Border.all(color: context.borderColor)),
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text('Anexos en la Nube', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textDark)),
																const SizedBox(height: 8),
																Center(
																	child: Draggable<_ArrastreQr>(
													data: _ArrastreQr(_urlAnexos!),
																		dragAnchorStrategy: (draggable, context, position) => const Offset(QrVisual.ancho / 2, QrVisual.alto / 2),
																		feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.85, child: QrVisual(url: _urlAnexos!, resaltadoRojo: false))),
																		childWhenDragging: Opacity(opacity: 0.3, child: QrVisual(url: _urlAnexos!, resaltadoRojo: false)),
																		child: QrVisual(
																			url: _urlAnexos!,
																			resaltadoRojo: _posicionQr == null,
																		),
																	),
																),
																if (_posicionQr == null)
																	Padding(
																		padding: const EdgeInsets.only(top: 8),
																		child: Text(
																			'Arrastra el QR al documento',
																			style: TextStyle(color: context.errorRed, fontSize: 12),
																			textAlign: TextAlign.center,
																		),
																	),
															],
														),
													),
												],
											],
										),
									),
								),
								Container(
									padding: const EdgeInsets.all(24),
									decoration: BoxDecoration(border: Border(top: BorderSide(color: context.borderColor))),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											ElevatedButton(
												onPressed: (_procesando || (_esModoVistoBueno ? !_hayVb : _posicionPorcentual == null) || (!_esModoVistoBueno && !_hardwareDisponible) || ((_sesionAnexos != null || _anexosPendientes.isNotEmpty) && _urlAnexos == null) || (_urlAnexos != null && _posicionQr == null)) ? null : _confirmar,
												style: ElevatedButton.styleFrom(backgroundColor: context.primaryPurple, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusPill))),
												child: _procesando
														? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
														: Column(
																mainAxisAlignment: MainAxisAlignment.center,
																children: [
																	Text(_esModoVistoBueno ? 'Confirmar' : 'Confirmar firma', style: const TextStyle(fontSize: 14, height: 1.1, fontWeight: FontWeight.w500)),
																	Text(_esModoVistoBueno ? 'Visto Bueno' : 'digital', style: const TextStyle(fontSize: 14, height: 1.1, fontWeight: FontWeight.w700)),
																],
															),
											),
											const SizedBox(height: 8),
											TextButton(onPressed: () => Navigator.of(context).pop(null), style: TextButton.styleFrom(foregroundColor: context.textGrey, minimumSize: const Size.fromHeight(40)), child: const Text('Cancelar')),
										],
									),
								),
							],
						),
					),
				],
			),
		);
	}
}