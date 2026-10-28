import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

class WebView extends StatefulWidget {
	final String url;
	final String titulo;

	/// Carpeta donde se guardan cookies y datos. Si es null usa
	/// %LOCALAPPDATA%\gtk\webview
	final String? carpetaDatos;

	/// Carpeta con el WebView2 Runtime "fixed version" (opcional, solo si
	/// quieres empaquetar el runtime con tu app portable).
	final String? rutaRuntimeFijo;

	const WebView({
		super.key,
		required this.url,
		this.carpetaDatos,
		this.rutaRuntimeFijo, required this.titulo,
	});

	@override
	State<WebView> createState() => _WebViewState();
}

/// Una descarga iniciada desde la página web.
class _Descarga {
	final String url;
	String ruta;
	int recibidos = 0;
	int total = 0;
	bool completada = false;

	_Descarga({
		required this.url,
		required this.ruta,
		// this.recibidos = 0,
		// this.total = 0,
		// this.completada = false,
	});

	String get nombre {
		final fuente = ruta.isNotEmpty ? ruta : (Uri.tryParse(url)?.pathSegments.lastOrNull ?? url);
		final nombre = fuente.split(RegExp(r'[\\/]')).last;
		return nombre.isEmpty ? 'archivo' : nombre;
	}

	double? get progreso => total > 0 ? (recibidos / total).clamp(0.0, 1.0) : null;

	String get estado {
		if (completada) return 'Descargado · ${_tamano(total > 0 ? total : recibidos)}';
		if (total > 0) {
			return 'Descargando… ${(recibidos / total * 100).clamp(0, 100).toStringAsFixed(0)} % · ${_tamano(recibidos)} de ${_tamano(total)}';
		}
		return 'Descargando… ${_tamano(recibidos)}';
	}
}

String _tamano(int bytes) {
	if (bytes < 1024) return '$bytes B';
	final kb = bytes / 1024;
	if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
	final mb = kb / 1024;
	if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
	return '${(mb / 1024).toStringAsFixed(2)} GB';
}

class _WebViewState extends State<WebView> with AutomaticKeepAliveClientMixin {
	// El entorno de WebView2 se inicializa una sola vez por ejecución.
	static Future<void>? _entorno;

	WebviewController _ctrl = WebviewController();
	StreamSubscription<LoadingState>? _subCarga;
	StreamSubscription<WebviewDownloadEvent>? _subDescargas;

	final Map<String, _Descarga> _descargas = {};

	bool _listo = false;
	bool _cargando = false;
	String? _error;

	/// Mantiene la página viva al cambiar de pestaña (no recarga).
	@override
	bool get wantKeepAlive => true;

	@override
	void initState() {
		super.initState();
		_iniciar();
	}

	@override
	void dispose() {
		_subCarga?.cancel();
		_subDescargas?.cancel();
		_ctrl.dispose();
		super.dispose();
	}

	// ==========================================
	// INICIALIZACIÓN
	// ==========================================
	String _carpetaPorDefecto() {
		final base = Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
		return '$base\\gtk\\webview';
	}

	Future<void> _inicializarEntorno() async {
		final carpeta = widget.carpetaDatos ?? _carpetaPorDefecto();
		await Directory(carpeta).create(recursive: true);
		try {
			await WebviewController.initializeEnvironment(
				userDataPath: carpeta,
				browserExePath: widget.rutaRuntimeFijo,
			);
		} on PlatformException catch (e) {
			// Ya estaba configurado (hot restart o reintento): se continúa.
			if (e.code != 'environment_already_initialized') rethrow;
		}
	}

	Future<void> _prepararEntorno() async {
		try {
			await (_entorno ??= _inicializarEntorno());
		} catch (_) {
			_entorno = null; // permite reintentar
			rethrow;
		}
	}

	Future<void> _iniciar() async {
		try {
			final version = await WebviewController.getWebViewVersion();
			if (version == null && widget.rutaRuntimeFijo == null) {
				throw StateError('runtime_no_instalado');
			}

			await _prepararEntorno();
			await _ctrl.initialize();

			_subCarga = _ctrl.loadingState.listen((s) {
				if (mounted) setState(() => _cargando = s == LoadingState.loading);
			});

			// Debe suscribirse ANTES de cargar la página: los eventos que llegan
			// sin nadie escuchando se pierden.
			_subDescargas = _ctrl.onDownloadEvent.listen(_alDescargar);

			await _ctrl.setBackgroundColor(Colors.white);
			// Los enlaces que abren ventana nueva se cargan en la misma vista.
			await _ctrl.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
			await _ctrl.loadUrl(widget.url);

			if (!mounted) return;
			setState(() {
				_listo = true;
				_error = null;
			});
		} catch (e) {
			if (!mounted) return;
			final sinRuntime = e.toString().contains('runtime_no_instalado') || e.toString().contains('environment_creation_failed');
			setState(() {
				_listo = false;
				_error = sinRuntime
						? 'Este equipo no tiene el componente WebView2 Runtime de Microsoft, necesario para mostrar páginas web.'
						: 'No se pudo iniciar el navegador integrado.\n$e';
			});
		}
	}

	/// Descarta el controlador anterior y empieza de cero con uno nuevo.
	void _reintentar() {
		_subCarga?.cancel();
		_subCarga = null;
		_subDescargas?.cancel();
		_subDescargas = null;
		_ctrl.dispose();
		_ctrl = WebviewController();
		setState(() {
			_error = null;
			_listo = false;
			_cargando = false;
		});
		_iniciar();
	}

	// ==========================================
	// DESCARGAS
	// ==========================================
	void _alDescargar(WebviewDownloadEvent e) {
		if (!mounted) return;
		final clave = e.resultFilePath.isNotEmpty ? e.resultFilePath : e.url;

		setState(() {
			final d = _descargas.putIfAbsent(clave, () => _Descarga(url: e.url, ruta: e.resultFilePath));
			if (e.resultFilePath.isNotEmpty) d.ruta = e.resultFilePath;
			d.recibidos = e.bytesReceived;
			d.total = e.totalBytesToReceive;

			switch (e.kind) {
				case WebviewDownloadEventKind.downloadStarted:
					d.completada = false;
				case WebviewDownloadEventKind.downloadProgress:
					break;
				case WebviewDownloadEventKind.downloadCompleted:
					d.completada = true;
					if (d.total <= 0) d.total = d.recibidos;
			}
		});
	}

	void _aviso(String mensaje, {bool error = false}) {
		if (!mounted) return;
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

	Future<bool> _existe(_Descarga d) async {
		if (d.ruta.isEmpty) {
			_aviso('No se conoce la ubicación de este archivo.', error: true);
			return false;
		}
		if (!await File(d.ruta).exists()) {
			_aviso('El archivo ya no existe en: ${d.ruta}', error: true);
			return false;
		}
		return true;
	}

	Future<void> _abrir(_Descarga d) async {
		if (!await _existe(d)) return;
		try {
			await Process.run('rundll32', ['url.dll,FileProtocolHandler', d.ruta]);
		} catch (e) {
			_aviso('No se pudo abrir el archivo: $e', error: true);
		}
	}

	Future<void> _mostrarEnCarpeta(_Descarga d) async {
		if (!await _existe(d)) return;
		try {
			// Ruta absoluta y con barras de Windows (\): si no, el Explorador
			// ignora la selección y abre otra carpeta.
			final ruta = File(d.ruta).absolute.path.replaceAll('/', r'\');
			await Process.run('explorer.exe', ['/select,', ruta]);
		} catch (e) {
			_aviso('No se pudo abrir la carpeta: $e', error: true);
		}
	}

	Future<void> _guardarCopia(_Descarga d) async {
		if (!await _existe(d)) return;
		try {
			final destino = await FilePicker.platform.saveFile(
				dialogTitle: 'Guardar copia de ${d.nombre}',
				fileName: d.nombre,
			);
			if (destino == null || destino == d.ruta) return;
			await File(d.ruta).copy(destino);
			_aviso('Copia guardada correctamente');
		} catch (e) {
			_aviso('No se pudo guardar la copia: $e', error: true);
		}
	}

	// ==========================================
	// BUILD
	// ==========================================
	@override
	Widget build(BuildContext context) {
		super.build(context); // requerido por AutomaticKeepAliveClientMixin

		return Scaffold(
			appBar: AppBar(title: Text(widget.titulo)),
			backgroundColor: context.backgroundLight,
			body: _contenido(context),
		);
	}

	Widget _contenido(BuildContext context) {
		if (_error != null) return _vistaError(context);

		if (!_listo) {
			return Center(child: CircularProgressIndicator(color: context.primaryPurple));
		}

		final recientes = _descargas.entries.toList().reversed.take(3).toList();

		return Stack(
			children: [
				Positioned.fill(child: Webview(_ctrl)),
				if (_cargando)
					Positioned(
						top: 0,
						left: 0,
						right: 0,
						child: LinearProgressIndicator(
							minHeight: 3,
							color: context.primaryPurple,
							backgroundColor: context.surfaceGrey,
						),
					),
				if (recientes.isNotEmpty)
					Positioned(
						right: 16,
						bottom: 16,
						width: 400,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								for (final e in recientes)
									Padding(
										padding: const EdgeInsets.only(top: 8),
										child: _TarjetaDescarga(
											descarga: e.value,
											onAbrir: () => _abrir(e.value),
											onCarpeta: () => _mostrarEnCarpeta(e.value),
											onGuardar: () => _guardarCopia(e.value),
											onCerrar: () => setState(() => _descargas.remove(e.key)),
										),
									),
							],
						),
					),
			],
		);
	}

	Widget _vistaError(BuildContext context) {
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
							child: Icon(Icons.public_off_outlined, size: 36, color: context.textGrey),
						),
						SizedBox(height: context.spaceMd),
						Text('Navegador no disponible', style: Theme.of(context).textTheme.titleLarge),
						SizedBox(height: context.spaceSm),
						Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
						SizedBox(height: context.spaceMd),
						ElevatedButton(onPressed: _reintentar, child: const Text('Reintentar')),
					],
				),
			),
		);
	}
}

class _TarjetaDescarga extends StatelessWidget {
	final _Descarga descarga;
	final VoidCallback onAbrir;
	final VoidCallback onCarpeta;
	final VoidCallback onGuardar;
	final VoidCallback onCerrar;

	const _TarjetaDescarga({
		required this.descarga,
		required this.onAbrir,
		required this.onCarpeta,
		required this.onGuardar,
		required this.onCerrar,
	});

	@override
	Widget build(BuildContext context) {
		final d = descarga;
		final textos = Theme.of(context).textTheme;

		return Material(
			color: context.surfaceWhite,
			elevation: 6,
			shadowColor: Colors.black26,
			borderRadius: BorderRadius.circular(context.radiusMd),
			child: Padding(
				padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								Icon(
									d.completada ? Icons.check_circle_rounded : Icons.downloading_rounded,
									color: d.completada ? context.primaryPurple : context.textGrey,
								),
								const SizedBox(width: 10),
								Expanded(
									child: Text(d.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: textos.titleMedium),
								),
								IconButton(
									tooltip: 'Cerrar',
									onPressed: onCerrar,
									icon: const Icon(Icons.close_rounded, size: 18),
								),
							],
						),
						if (!d.completada) ...[
							ClipRRect(
								borderRadius: BorderRadius.circular(context.radiusPill),
								child: LinearProgressIndicator(
									value: d.progreso,
									minHeight: 6,
									color: context.primaryPurple,
									backgroundColor: context.surfaceGrey,
								),
							),
							const SizedBox(height: 8),
						],
						Text(d.estado, style: textos.bodyMedium),
						if (d.completada) ...[
							const SizedBox(height: 4),
							Wrap(
								spacing: 4,
								children: [
									TextButton.icon(
										onPressed: onAbrir,
										icon: const Icon(Icons.open_in_new_rounded, size: 16),
										label: const Text('Abrir'),
									),
									TextButton.icon(
										onPressed: onCarpeta,
										icon: const Icon(Icons.folder_open_outlined, size: 16),
										label: const Text('Mostrar en carpeta'),
									),
									TextButton.icon(
										onPressed: onGuardar,
										icon: const Icon(Icons.save_alt_rounded, size: 16),
										label: const Text('Guardar copia…'),
									),
								],
							),
						],
					],
				),
			),
		);
	}
}