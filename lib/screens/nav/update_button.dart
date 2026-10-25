import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart' show extractFileToDisk;
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/data/github.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

// ==========================================
// CONFIGURACIÓN
// ==========================================
const String _githubUsuario = githubUsuario;
const String _githubRepo = githubRepo;
const Duration _intervaloRevision = Duration(minutes: 30);

/// Los archivos reemplazados se renombran con este sufijo y se borran al reiniciar.
const String _sufijoRespaldo = '.upd_old';
const String _carpetaTemporal = '_actualizacion_tmp';
const String _listaRespaldos = '_respaldos_actualizacion.txt';

class _InfoActualizacion {
	final String version;
	final String urlZip;
	final String notas;

	const _InfoActualizacion({
		required this.version,
		required this.urlZip,
		required this.notas,
	});
}

class _Cambio {
	final String objetivo;
	final String? respaldo;

	const _Cambio(this.objetivo, this.respaldo);
}

/// Está fuera de la clase a propósito: así el hilo secundario solo recibe
/// dos textos y no arrastra la ventana ni el estado de la app.
Future<void> _extraerZip(String rutaZip, String rutaDestino) {
	return Isolate.run(() => extractFileToDisk(rutaZip, rutaDestino));
}

/// Botón flotante que aparece solo cuando hay una versión nueva en GitHub.
class UpdateButton extends StatefulWidget {
	const UpdateButton({super.key});

	@override
	State<UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends State<UpdateButton> with SingleTickerProviderStateMixin {
	late final AnimationController _pulso;
	Timer? _timer;

	_InfoActualizacion? _nueva;
	String _versionInstalada = '';
	bool _revisando = false;
	bool _instalando = false;

	String get _carpetaApp => File(Platform.resolvedExecutable).parent.path;

	@override
	void initState() {
		super.initState();
		_pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
		unawaited(_limpiarRestos());
		_revisar();
		_timer = Timer.periodic(_intervaloRevision, (_) => _revisar());
	}

	@override
	void dispose() {
		_timer?.cancel();
		_pulso.dispose();
		super.dispose();
	}

	// ==========================================
	// LIMPIEZA DE RESTOS DE LA ACTUALIZACIÓN ANTERIOR
	// ==========================================
	Future<void> _limpiarRestos() async {
		await Future<void>.delayed(const Duration(seconds: 5));
		try {
			final carpeta = _carpetaApp;
			await _borrarCarpeta(Directory('$carpeta\\$_carpetaTemporal'));

			final lista = File('$carpeta\\$_listaRespaldos');
			if (!await lista.exists()) return;

			final pendientes = <String>[];
			for (final ruta in await lista.readAsLines()) {
				if (ruta.trim().isEmpty) continue;
				try {
					final archivo = File(ruta);
					if (await archivo.exists()) await archivo.delete();
				} catch (_) {
					pendientes.add(ruta);
				}
			}

			if (pendientes.isEmpty) {
				await lista.delete();
			} else {
				await lista.writeAsString(pendientes.join('\n'));
			}
		} catch (_) {}
	}

	// ==========================================
	// REVISAR GITHUB
	// ==========================================
	Future<void> _revisar() async {
		if (_revisando || _instalando) return;
		_revisando = true;
		try {
			final instalada = (await PackageInfo.fromPlatform()).version;

			final resp = await http.get(
				Uri.parse('https://api.github.com/repos/$_githubUsuario/$_githubRepo/releases/latest'),
				headers: {
					'Accept': 'application/vnd.github+json',
					'User-Agent': 'firmador-geresa-updater',
				},
			).timeout(const Duration(seconds: 10));

			if (resp.statusCode != 200) return;

			final datos = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
			final tag = (datos['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^[vV]'), '');
			final assets = (datos['assets'] as List? ?? []).cast<Map<String, dynamic>>();
			final zip = assets.firstWhere(
				(a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.zip'),
				orElse: () => <String, dynamic>{},
			);
			final url = zip['browser_download_url'] as String?;

			if (!mounted) return;
			setState(() {
				_versionInstalada = instalada;
				_nueva = (url != null && _esMasNueva(tag, instalada))
						? _InfoActualizacion(version: tag, urlZip: url, notas: (datos['body'] as String? ?? '').trim())
						: null;
			});
		} catch (_) {
		} finally {
			_revisando = false;
		}
	}

	List<int> _partes(String v) {
		return v.split('+').first.split('-').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
	}

	bool _esMasNueva(String remota, String local) {
		final r = _partes(remota);
		final l = _partes(local);
		for (var i = 0; i < 3; i++) {
			final a = i < r.length ? r[i] : 0;
			final b = i < l.length ? l[i] : 0;
			if (a != b) return a > b;
		}
		return false;
	}

	// ==========================================
	// ACCIÓN DEL BOTÓN
	// ==========================================
	Future<void> _alPresionar() async {
		final info = _nueva;
		if (info == null || _instalando) return;

		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				backgroundColor: ctx.surfaceWhite,
				surfaceTintColor: Colors.transparent,
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
				// Tamaño estático del diálogo
				content: SizedBox(
					width: 450,
					height: 400, 
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							// Icono superior
							Container(
								padding: const EdgeInsets.all(16),
								decoration: BoxDecoration(
									color: ctx.primaryPurple.withOpacity(0.1),
									shape: BoxShape.circle,
								),
								child: Icon(Icons.system_update_rounded, size: 40, color: ctx.primaryPurple),
							),
							const SizedBox(height: 16),
							Text(
								'Nueva versión disponible',
								style: Theme.of(ctx).textTheme.titleLarge,
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 8),
							// Mostrar versiones (sin GitHub)
							Container(
								padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
								decoration: BoxDecoration(
									color: ctx.surfaceGrey,
									borderRadius: BorderRadius.circular(20),
								),
								child: Text(
									'De la versión $_versionInstalada a la ${info.version}',
									style: TextStyle(color: ctx.textGrey, fontSize: 13, fontWeight: FontWeight.w500),
								),
							),
							const SizedBox(height: 16),
							
							// Notas de la versión con scroll
							if (info.notas.isNotEmpty) ...[
								Align(
									alignment: Alignment.centerLeft,
									child: Text('Novedades', style: Theme.of(ctx).textTheme.titleSmall),
								),
								const SizedBox(height: 6),
								Expanded(
									child: Container(
										width: double.infinity,
										padding: const EdgeInsets.all(12),
										decoration: BoxDecoration(
											color: ctx.surfaceGrey.withOpacity(0.3),
											borderRadius: BorderRadius.circular(ctx.radiusSm),
											border: Border.all(color: ctx.borderColor),
										),
										child: SingleChildScrollView(
											child: Text(info.notas, style: Theme.of(ctx).textTheme.bodyMedium),
										),
									),
								),
							] else
								const Spacer(),

							// Icono de check al final
							const SizedBox(height: 12),
							Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade400, size: 28),
							const SizedBox(height: 8),
							Text(
								'La app se cerrará y reiniciará sola.',
								style: TextStyle(color: ctx.textGrey, fontSize: 12),
								textAlign: TextAlign.center,
							),
						],
					),
				),
				actions: [
					OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Más tarde')),
					ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Actualizar ahora')),
				],
			),
		);

		if (confirmar != true || !mounted) return;
		await _instalar(info);
	}

	// ==========================================
	// DESCARGAR E INSTALAR
	// ==========================================
	Future<void> _instalar(_InfoActualizacion info) async {
		if (kDebugMode) {
			_mensaje('Modo debug: la instalación está desactivada para no pisar tu build de desarrollo. Pruébala con la versión release.');
			return;
		}

		final carpetaApp = _carpetaApp;
		if (!await _puedeEscribir(carpetaApp)) {
			await _mostrarFalla(
				'La carpeta donde está la aplicación no permite guardar archivos:\n$carpetaApp\n\nMueve la aplicación a una carpeta propia, como Documentos o el Escritorio, y ábrela desde ahí.',
			);
			return;
		}
		if (!mounted) return;

		_instalando = true;
		final progreso = ValueNotifier<double?>(null);
		final etapa = ValueNotifier<String>('Descargando');

		showDialog(
			context: context,
			barrierDismissible: false,
			builder: (_) => PopScope(
				canPop: false,
				child: _DialogoProgreso(progreso: progreso, etapa: etapa, version: info.version),
			),
		);

		final zip = File('${Directory.systemTemp.path}\\firmador_actualizacion.zip');
		final temporal = Directory('$carpetaApp\\$_carpetaTemporal');
		final cambios = <_Cambio>[];

		try {
			await _descargar(info.urlZip, zip, progreso);

			etapa.value = 'Preparando archivos';
			progreso.value = null;
			await _borrarCarpeta(temporal);
			await temporal.create(recursive: true);
			await _extraerZip(zip.path, temporal.path);

			var origen = temporal;
			final hijos = await temporal.list().toList();
			if (hijos.length == 1 && hijos.first is Directory) {
				origen = hijos.first as Directory;
			}

			final nombreExe = Platform.resolvedExecutable.split('\\').last;
			if (!await File('${origen.path}\\$nombreExe').exists()) {
				throw StateError('El paquete descargado no contiene $nombreExe.');
			}

			etapa.value = 'Instalando';
			await _aplicar(origen, carpetaApp, cambios);

			final lista = File('$carpetaApp\\$_listaRespaldos');
			final previos = await lista.exists() ? await lista.readAsLines() : <String>[];
			final nuevos = cambios.where((c) => c.respaldo != null).map((c) => c.respaldo!);
			await lista.writeAsString([...previos, ...nuevos].join('\n'));

			etapa.value = 'Reiniciando';
			await _borrarCarpeta(temporal);
			await _borrarArchivo(zip);

			await Process.start(
				Platform.resolvedExecutable,
				const <String>[],
				workingDirectory: carpetaApp,
				mode: ProcessStartMode.detached,
			);
			await Future<void>.delayed(const Duration(milliseconds: 800));
			exit(0);
		} catch (e) {
			await _revertir(cambios);
			await _borrarCarpeta(temporal);
			await _borrarArchivo(zip);
			_instalando = false;
			if (!mounted) return;
			Navigator.of(context, rootNavigator: true).pop();
			await _mostrarFalla(_texto(e));
		}
	}

	Future<void> _aplicar(Directory origen, String destino, List<_Cambio> cambios) async {
		final nuevos = <File>[];
		await for (final e in origen.list(recursive: true, followLinks: false)) {
			if (e is File) nuevos.add(e);
		}

		for (final nuevo in nuevos) {
			final relativa = nuevo.path.substring(origen.path.length + 1);
			final objetivo = File('$destino\\$relativa');

			await objetivo.parent.create(recursive: true);

			String? respaldo;
			if (await objetivo.exists()) {
				respaldo = await _rutaRespaldo(objetivo.path);
				try {
					await objetivo.rename(respaldo);
				} catch (e) {
					throw StateError('No se pudo reemplazar "$relativa". ${_texto(e)}');
				}
			}
			cambios.add(_Cambio(objetivo.path, respaldo));

			try {
				await nuevo.rename(objetivo.path);
			} catch (_) {
				await nuevo.copy(objetivo.path);
			}
		}
	}

	Future<String> _rutaRespaldo(String ruta) async {
		var candidato = '$ruta$_sufijoRespaldo';
		if (await File(candidato).exists()) {
			try {
				await File(candidato).delete();
			} catch (_) {
				candidato = '$ruta.${DateTime.now().millisecondsSinceEpoch}$_sufijoRespaldo';
			}
		}
		return candidato;
	}

	Future<void> _revertir(List<_Cambio> cambios) async {
		for (final c in cambios.reversed) {
			try {
				final actual = File(c.objetivo);
				if (await actual.exists()) await actual.delete();
			} catch (_) {}

			final respaldo = c.respaldo;
			if (respaldo != null) {
				try {
					await File(respaldo).rename(c.objetivo);
				} catch (_) {}
			}
		}
	}

	Future<void> _borrarCarpeta(Directory carpeta) async {
		try {
			if (await carpeta.exists()) await carpeta.delete(recursive: true);
		} catch (_) {}
	}

	Future<void> _borrarArchivo(File archivo) async {
		try {
			if (await archivo.exists()) await archivo.delete();
		} catch (_) {}
	}

	Future<bool> _puedeEscribir(String carpeta) async {
		try {
			final prueba = File('$carpeta\\.escritura_test');
			await prueba.writeAsString('ok');
			await prueba.delete();
			return true;
		} catch (_) {
			return false;
		}
	}

	Future<void> _descargar(String url, File destino, ValueNotifier<double?> progreso) async {
		final cliente = http.Client();
		try {
			final peticion = http.Request('GET', Uri.parse(url));
			peticion.headers['User-Agent'] = 'firmador-geresa-updater';
			final resp = await cliente.send(peticion);

			if (resp.statusCode != 200) {
				throw HttpException('La descarga falló (código ${resp.statusCode}).');
			}

			final total = resp.contentLength ?? 0;
			final sink = destino.openWrite();
			try {
				var recibido = 0;
				await for (final trozo in resp.stream) {
					sink.add(trozo);
					recibido += trozo.length;
					if (total > 0) progreso.value = recibido / total;
				}
			} finally {
				await sink.close();
			}
		} finally {
			cliente.close();
		}
	}

	String _texto(Object e) {
		if (e is FileSystemException) {
			final ruta = e.path != null && e.path!.isNotEmpty ? ': ${e.path}' : '';
			final sistema = e.osError != null ? ' (${e.osError!.message})' : '';
			return '${e.message}$ruta$sistema';
		}
		return e.toString().replaceFirst('Bad state: ', '');
	}

	// ==========================================
	// MENSAJES
	// ==========================================
	void _mensaje(String texto, {bool error = false}) {
		ScaffoldMessenger.of(context)
			..hideCurrentSnackBar()
			..showSnackBar(
				SnackBar(
					content: Text(texto, style: const TextStyle(color: Colors.white)),
					backgroundColor: error ? context.errorRed : context.textDark,
					behavior: SnackBarBehavior.floating,
					width: 460,
					duration: const Duration(seconds: 10),
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusSm)),
				),
			);
	}

	/// Diálogo de respaldo: explica el problema y da las instrucciones.
	Future<void> _mostrarFalla(String motivo) async {
		if (!mounted) return;
		var copiado = false;

		await showDialog<void>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (ctx, setLocal) => AlertDialog(
					backgroundColor: ctx.surfaceWhite,
					surfaceTintColor: Colors.transparent,
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
					title: const Text('No se pudo actualizar automáticamente'),
					content: SizedBox(
						width: 460,
						child: SingleChildScrollView(
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(motivo, style: Theme.of(ctx).textTheme.bodyMedium),
									const SizedBox(height: 16),
									Text('Puedes actualizar manualmente:', style: Theme.of(ctx).textTheme.titleSmall),
									const SizedBox(height: 6),
									Text('1. Abre el enlace de descarga y descarga el archivo ".zip".', style: Theme.of(ctx).textTheme.bodyMedium),
									const SizedBox(height: 4),
									Text('2. Extrae el zip en una carpeta propia, como Documentos o el Escritorio.', style: Theme.of(ctx).textTheme.bodyMedium),
									const SizedBox(height: 4),
									Text('3. Abre la aplicación desde esa carpeta nueva.', style: Theme.of(ctx).textTheme.bodyMedium),
								],
							),
						),
					),
					actions: [
						ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
					],
				),
			),
		);
	}

	// ==========================================
	// BUILD
	// ==========================================
	@override
	Widget build(BuildContext context) {
		final info = _nueva;
		if (info == null) return const SizedBox.shrink();

		return Padding(
			// Este Padding empuja el botón 10px a la izquierda y 10px abajo
			padding: const EdgeInsets.only(left: 10, bottom: 10),
			child: AnimatedBuilder(
				animation: _pulso,
				builder: (context, child) {
					final t = Curves.easeInOut.transform(_pulso.value);
					return Container(
						decoration: BoxDecoration(
							shape: BoxShape.circle,
							boxShadow: [
								BoxShadow(
									color: context.primaryPurple.withValues(alpha: 0.45 * (1 - t)),
									blurRadius: 6 + 14 * t,
									spreadRadius: 1 + 5 * t,
								),
							],
						),
						child: child,
					);
				},
				child: Badge(
					smallSize: 10,
					backgroundColor: context.accentOrange,
					child: FloatingActionButton.small(
						heroTag: 'btn_actualizar',
						tooltip: 'Nueva versión ${info.version} disponible',
						backgroundColor: context.primaryPurple,
						foregroundColor: Colors.white,
						elevation: 2,
						onPressed: _alPresionar,
						child: const Icon(Icons.browser_updated),
					),
				),
			),
		);
	}
}

class _DialogoProgreso extends StatelessWidget {
	final ValueNotifier<double?> progreso;
	final ValueNotifier<String> etapa;
	final String version;

	const _DialogoProgreso({required this.progreso, required this.etapa, required this.version});

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			backgroundColor: context.surfaceWhite,
			surfaceTintColor: Colors.transparent,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusLg)),
			title: Text('Actualizando a la versión $version'),
			content: SizedBox(
				width: 380,
				child: AnimatedBuilder(
					animation: Listenable.merge([progreso, etapa]),
					builder: (context, _) {
						final valor = progreso.value;
						return Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								ClipRRect(
									borderRadius: BorderRadius.circular(context.radiusPill),
									child: LinearProgressIndicator(
										value: valor,
										minHeight: 8,
										color: context.primaryPurple,
										backgroundColor: context.surfaceGrey,
									),
								),
								const SizedBox(height: 12),
								Text(
									valor == null ? '${etapa.value}…' : '${etapa.value} ${(valor * 100).toStringAsFixed(0)} %',
									style: Theme.of(context).textTheme.titleSmall,
								),
								const SizedBox(height: 4),
								Text(
									'No cierres la aplicación. Se reiniciará sola al terminar.',
									style: Theme.of(context).textTheme.bodyMedium,
								),
							],
						);
					},
				),
			),
		);
	}
}