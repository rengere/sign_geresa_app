import 'dart:async';
import 'dart:io';

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

class _WebViewState extends State<WebView> with AutomaticKeepAliveClientMixin {
	// El entorno de WebView2 se inicializa una sola vez por ejecución.
	static Future<void>? _entorno;

	WebviewController _ctrl = WebviewController();
	StreamSubscription<LoadingState>? _subCarga;

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