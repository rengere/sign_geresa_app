import 'dart:io';

const String _pubspec = 'pubspec.yaml';

Future<void> main(List<String> args) async {
	final simular = args.contains('--simular');

	_linea('');
	_linea('=== Publicar nueva version${simular ? ' (SIMULACION)' : ''} ===');
	_linea('');

	// 1. Comprobaciones previas
	if (!File(_pubspec).existsSync()) {
		_salir('No encuentro pubspec.yaml. Ejecuta el script desde la carpeta del proyecto:\n  dart tools\\publicar.dart');
	}
	if (!Directory('.git').existsSync()) {
		_salir('Esta carpeta no es un repositorio de git (no existe la carpeta .git).');
	}
	try {
		await Process.run('git', ['--version']);
	} on ProcessException {
		_salir('No encuentro git en esta PC.');
	}

	// 2. Leer la version actual
	final original = File(_pubspec).readAsStringSync();
	final patron = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?', multiLine: true);
	final coincidencia = patron.firstMatch(original);
	if (coincidencia == null) {
		_salir('No pude leer la linea "version:" de pubspec.yaml. Formato esperado: version: 1.0.0+1');
	}

	final mayor = int.parse(coincidencia.group(1)!);
	final menor = int.parse(coincidencia.group(2)!);
	final parche = int.parse(coincidencia.group(3)!);
	final compilacion = coincidencia.group(4) == null ? null : int.parse(coincidencia.group(4)!);

	final actual = '$mayor.$menor.$parche${compilacion == null ? '' : '+$compilacion'}';
	final versionNueva = '$mayor.$menor.${parche + 1}';
	final lineaNueva = compilacion == null ? versionNueva : '$versionNueva+${compilacion + 1}';
	final etiqueta = 'v$versionNueva';

	// 3. Comprobaciones de git
	final rama = await _leer(['rev-parse', '--abbrev-ref', 'HEAD']);
	if (rama.isEmpty || rama == 'HEAD') {
		_salir('No estas en una rama (HEAD separado). Cambia a tu rama principal con: git checkout main');
	}
	final remoto = await _leer(['remote', 'get-url', 'origin']);

	if ((await _leer(['tag', '--list', etiqueta])).isNotEmpty) {
		_salir('La etiqueta $etiqueta ya existe en tu PC. Revisa con: git tag');
	}
	if ((await _leer(['ls-remote', '--tags', 'origin', 'refs/tags/$etiqueta'])).isNotEmpty) {
		_salir('La etiqueta $etiqueta ya existe en GitHub. Alguien publico esa version antes.');
	}

	// 4. Pedir el comentario
	_linea('Version actual : $actual');
	_linea('Version nueva  : $lineaNueva');
	_linea('Etiqueta       : $etiqueta');
	_linea('Rama           : $rama');
	_linea('');

	stdout.write('Comentario del commit: ');
	final comentario = (stdin.readLineSync() ?? '').trim();
	if (comentario.isEmpty) {
		_salir('El comentario no puede estar vacio.');
	}
	final mensajeFinal = '$comentario (v$versionNueva)';

	// 5. Resumen y confirmacion
	_linea('');
	_linea('Se hara lo siguiente:');
	_linea('  1. pubspec.yaml -> version: $lineaNueva');
	_linea('  2. git add .');
	_linea('  3. git commit -m "$mensajeFinal"');
	_linea('  4. git push origin $rama');
	_linea('  5. git tag $etiqueta');
	_linea('  6. git push origin $etiqueta');
	_linea('');

	if (simular) {
		_linea('Simulacion: no se cambio nada.');
		return;
	}

	stdout.write('Continuar? (s/n): ');
	final respuesta = (stdin.readLineSync() ?? '').trim().toLowerCase();
	if (!['s', 'si', 'sí', 'y', 'yes'].contains(respuesta)) {
		_linea('Cancelado. No se cambio nada.');
		return;
	}

	// 6. Ejecutar
	_linea('');
	File(_pubspec).writeAsStringSync(
		original.replaceFirstMapped(patron, (_) => 'version: $lineaNueva'),
	);
	_linea('pubspec.yaml actualizado a $lineaNueva');

	final pasos = <List<String>>[
		['add', '.'],
		['commit', '-m', mensajeFinal],
		['push', 'origin', rama],
		['tag', etiqueta],
		['push', 'origin', etiqueta],
	];

	for (var i = 0; i < pasos.length; i++) {
		final bien = await _git(pasos[i]);
		if (bien) continue;

		stderr.writeln('');
		if (i < 2) {
			// El commit todavia no se hizo: se deja pubspec.yaml como estaba.
			File(_pubspec).writeAsStringSync(original);
			stderr.writeln('ERROR: fallo "git ${pasos[i].first}". No se publico nada y pubspec.yaml volvio a $actual.');
		} else {
			stderr.writeln('ERROR: fallo "git ${pasos[i].first}". El commit YA esta guardado en tu PC.');
			stderr.writeln('Cuando resuelvas el problema (internet o credenciales), ejecuta lo que falta, uno por uno:');
			for (var j = i; j < pasos.length; j++) {
				stderr.writeln('  git ${pasos[j].join(' ')}');
			}
		}
		exit(1);
	}

	_linea('');
	_linea('Listo: $etiqueta publicada en git.');
	final actions = _urlActions(remoto);
	if (actions != null) {
		_linea('Sigue la compilacion aqui: $actions');
	}
	_linea('Cuando termine (unos 5 minutos), las apps instaladas mostraran el boton de actualizar.');
}

void _linea(String texto) => stdout.writeln(texto);

Never _salir(String mensaje) {
	stderr.writeln('');
	stderr.writeln('ERROR: $mensaje');
	exit(1);
}

/// Ejecuta git mostrando su salida en pantalla (permite ver avisos y pedir credenciales).
Future<bool> _git(List<String> args) async {
	stdout.writeln('> git ${args.join(' ')}');
	final proceso = await Process.start('git', args, mode: ProcessStartMode.inheritStdio);
	return await proceso.exitCode == 0;
}

/// Ejecuta git y devuelve su texto de salida. Si falla, termina el script.
Future<String> _leer(List<String> args) async {
	final r = await Process.run('git', args);
	if (r.exitCode != 0) {
		_salir('Fallo "git ${args.join(' ')}":\n${r.stderr}');
	}
	return (r.stdout as String).trim();
}

String? _urlActions(String remoto) {
	final m = RegExp(r'github\.com[:/](.+?)(?:\.git)?$').firstMatch(remoto);
	return m == null ? null : 'https://github.com/${m.group(1)}/actions';
}