import 'dart:io';

/// Carpeta del usuario actual de Windows. Ejemplo: C:\Users\RenatoLuna
String get _carpetaUsuario {
	final env = Platform.environment;
	return env['USERPROFILE'] ?? env['HOME'] ?? Directory.systemTemp.path;
}

/// Donde se guarda data.json. Ejemplo: C:\Users\RenatoLuna\AppData\Roaming\gtk
String get folderPath {
	final appData = Platform.environment['APPDATA'] ?? '$_carpetaUsuario\\AppData\\Roaming';
	return '$appData\\gtk';
}


// /// Escritorio del usuario. Si Windows lo tiene dentro de OneDrive
// /// (muy común), usa esa ubicación.
// String get _escritorio {
// 	final directo = '$_carpetaUsuario\\Desktop';
// 	if (Directory(directo).existsSync()) return directo;

// 	final oneDrive = Platform.environment['OneDrive'];
// 	if (oneDrive != null) {
// 		final alterno = '$oneDrive\\Desktop';
// 		if (Directory(alterno).existsSync()) return alterno;
// 	}
// 	return directo;
// }

// /// Carpeta de PDFs. Ejemplo: C:\Users\RenatoLuna\Desktop\test_pdf
// String get rutaCarpetas => '$_escritorio\\test_pdf';