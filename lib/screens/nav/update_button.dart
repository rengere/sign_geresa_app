import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/data/github.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

// ==========================================
// CONFIGURACIÓN (cámbialo por tus datos)
// ==========================================
const String _githubUsuario = githubUsuario;
const String _githubRepo = githubRepo;
const Duration _intervaloRevision = Duration(minutes: 30);

/// Script que reemplaza los archivos cuando la app ya se cerró.
/// Escribe un log en %TEMP%\firmador_actualizacion.log
const String _scriptActualizador = r'''
param(
[int]$PidApp,
[string]$Zip,
[string]$Destino,
[string]$Exe
)
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'firmador_actualizacion.log'
try {
"[$(Get-Date)] Esperando a que se cierre la app (PID $PidApp)" | Out-File $log
while (Get-Process -Id $PidApp -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 300 }
Start-Sleep -Seconds 1

$tmp = Join-Path $env:TEMP 'firmador_actualizacion'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive -LiteralPath $Zip -DestinationPath $tmp -Force

$origen = $tmp
$hijos = @(Get-ChildItem -LiteralPath $tmp)
if ($hijos.Count -eq 1 -and $hijos[0].PSIsContainer) { $origen = $hijos[0].FullName }

$copiado = $false
for ($i = 0; $i -lt 10 -and -not $copiado; $i++) {
try {
Copy-Item -Path (Join-Path $origen '*') -Destination $Destino -Recurse -Force
$copiado = $true
} catch {
"[$(Get-Date)] Reintento $($i + 1): $_" | Out-File $log -Append
Start-Sleep -Seconds 1
}
}
if (-not $copiado) { throw 'No se pudieron copiar los archivos nuevos.' }

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $Zip -Force -ErrorAction SilentlyContinue
"[$(Get-Date)] Actualizacion completada" | Out-File $log -Append
} catch {
"[$(Get-Date)] ERROR: $_" | Out-File $log -Append
}
Start-Process -FilePath $Exe
''';

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

	@override
	void initState() {
		super.initState();
		_pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
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
			// Sin internet o GitHub no responde: simplemente no se muestra el botón.
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
				title: Text('Nueva versión ${info.version}'),
				content: SizedBox(
					width: 420,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(
								'Tienes la versión $_versionInstalada. La app se cerrará y se volverá a abrir sola al terminar.',
								style: Theme.of(ctx).textTheme.bodyMedium,
							),
							if (info.notas.isNotEmpty) ...[
								const SizedBox(height: 16),
								Text('Novedades', style: Theme.of(ctx).textTheme.titleSmall),
								const SizedBox(height: 6),
								ConstrainedBox(
									constraints: const BoxConstraints(maxHeight: 180),
									child: SingleChildScrollView(
										child: Text(info.notas, style: Theme.of(ctx).textTheme.bodyMedium),
									),
								),
							],
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

		final carpetaApp = File(Platform.resolvedExecutable).parent.path;
		if (!await _puedeEscribir(carpetaApp)) {
			if (!mounted) return;
			_mensaje('La carpeta de la app no permite escribir:\n$carpetaApp\nMueve la app a una carpeta como el Escritorio o D:\\.', error: true);
			return;
		}
		if (!mounted) return;

		_instalando = true;
		final progreso = ValueNotifier<double?>(null);

		showDialog(
			context: context,
			barrierDismissible: false,
			builder: (_) => PopScope(
				canPop: false,
				child: _DialogoProgreso(progreso: progreso, version: info.version),
			),
		);

		try {
			final zip = await _descargar(info.urlZip, progreso);

			final script = File('${Directory.systemTemp.path}\\firmador_actualizar.ps1');
			await script.writeAsString(_scriptActualizador);

			await Process.start(
				'powershell.exe',
				[
					'-NoProfile',
					'-ExecutionPolicy',
					'Bypass',
					'-WindowStyle',
					'Hidden',
					'-File',
					script.path,
					'-PidApp',
					'$pid',
					'-Zip',
					zip.path,
					'-Destino',
					carpetaApp,
					'-Exe',
					Platform.resolvedExecutable,
				],
				mode: ProcessStartMode.detached,
			);

			exit(0);
		} catch (e) {
			_instalando = false;
			if (!mounted) return;
			Navigator.of(context, rootNavigator: true).pop(); // cierra el diálogo de progreso
			_mensaje('No se pudo actualizar: $e', error: true);
		} finally {
			progreso.dispose();
		}
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

	Future<File> _descargar(String url, ValueNotifier<double?> progreso) async {
		final cliente = http.Client();
		try {
			final peticion = http.Request('GET', Uri.parse(url));
			peticion.headers['User-Agent'] = 'firmador-geresa-updater';
			final resp = await cliente.send(peticion);

			if (resp.statusCode != 200) {
				throw HttpException('Descarga fallida (HTTP ${resp.statusCode})');
			}

			final total = resp.contentLength ?? 0;
			final archivo = File('${Directory.systemTemp.path}\\firmador_actualizacion.zip');
			final sink = archivo.openWrite();
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
			return archivo;
		} finally {
			cliente.close();
		}
	}

	void _mensaje(String texto, {bool error = false}) {
		ScaffoldMessenger.of(context)
			..hideCurrentSnackBar()
			..showSnackBar(
				SnackBar(
					content: Text(texto, style: const TextStyle(color: Colors.white)),
					backgroundColor: error ? context.errorRed : context.textDark,
					behavior: SnackBarBehavior.floating,
					width: 460,
					duration: const Duration(seconds: 6),
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusSm)),
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

		return AnimatedBuilder(
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
		);
	}
}

class _DialogoProgreso extends StatelessWidget {
	final ValueNotifier<double?> progreso;
	final String version;

	const _DialogoProgreso({required this.progreso, required this.version});

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			backgroundColor: context.surfaceWhite,
			surfaceTintColor: Colors.transparent,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusLg)),
			title: Text('Descargando versión $version'),
			content: SizedBox(
				width: 380,
				child: ValueListenableBuilder<double?>(
					valueListenable: progreso,
					builder: (context, valor, _) {
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
									valor == null ? 'Preparando descarga…' : '${(valor * 100).toStringAsFixed(0)} %',
									style: Theme.of(context).textTheme.titleSmall,
								),
								const SizedBox(height: 4),
								Text(
									'La app se reiniciará sola al terminar.',
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