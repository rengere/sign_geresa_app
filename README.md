# Firmador GERESA Cusco — firma y verificación con DNIe real

Estructura:

```
firmador_geresa/
  lib/        -> App Flutter (frontend: pantallas Firmar y Verificar)
  signer/     -> API de firma en Java (Maven)
  pubspec.yaml
```

## Cómo funciona (resumen)

El `signer/` habla **directo con el chip del DNIe** usando comandos
APDU (ISO 7816-4/7816-8) sobre PC/SC, vía `javax.smartcardio` +
`jnasmartcardio` (librería abierta, no es de RENIEC). El protocolo
(AID de la aplicación, identificador del archivo del certificado,
comandos de PIN y firma) se documentó analizando el bytecode del
software oficial de RENIEC — el código de `signer/dnie/` es una
reimplementación propia, no código copiado.

Paquete `pe.gob.geresacusco.firmador.dnie`:

- `DnieCard` — el protocolo en sí: seleccionar la aplicación, leer el
  certificado de firma, verificar el PIN, firmar.
- `DnieSignatureToken` — conecta ese protocolo con DSS (la librería de
  firma PAdES), implementando la interfaz `SignatureTokenConnection`.
- `DniePrivateKeyEntry` — adapta el certificado del DNIe al formato que
  espera DSS.
- `PinIncorrectoException` / `TarjetaBloqueadaException` — errores de
  PIN, con los intentos restantes cuando aplica.

Como todo pasa por PC/SC (el estándar que cualquier lector homologado
por Windows ya habla), esto funciona con cualquier lector, no solo
con el miniLector Bit4id.

## 1. Compilar y correr el signer

```bash
cd signer
mvn clean package
java -jar target/firmador-signer.jar
```

Debería imprimir: `Firmador GERESA Cusco escuchando en http://127.0.0.1:8000`

## 2. Probar en orden, ANTES de tocar Flutter

**Primero**, con el DNIe insertado, sin necesidad de PIN:

```
http://127.0.0.1:8000/lector/titular
```

Esto debería devolver el sujeto del certificado de firma (tu nombre).
Si falla aquí, el problema está en la lectura del certificado — avísame
el mensaje de error exacto antes de seguir.

**Luego**, probar `/firmar` con un PDF real y tu PIN real (puedes
usar curl o Insomnia/Postman, no hace falta Flutter todavía):

```bash
curl -X POST http://127.0.0.1:8000/firmar \
  -F "pdf=@prueba.pdf" \
  -F "pin=TU_PIN" \
  -F "dni=TU_DNI" \
  --output prueba_firmada.pdf
```

Si todo funciona, `prueba_firmada.pdf` debería abrir bien y mostrar la
firma en cualquier lector de PDF. Si la tarjeta responde con un error
de "Respuesta inesperada" en el paso de firma, el detalle casi seguro
está en cómo se arma el `DigestInfo` antes de enviarlo al chip — está
señalado con un comentario en `DnieSignatureToken.construirDigestInfo`,
es el punto más sensible a ajustar con hardware real.

**Después**, probar `/verificar` con ese mismo PDF firmado:

```bash
curl -X POST http://127.0.0.1:8000/verificar \
  -F "pdf=@prueba_firmada.pdf"
```

Debería confirmar que el documento está íntegro y que la firma es
criptográficamente válida.

## 3. Recién ahí, correr Flutter

```bash
flutter pub get
flutter create --platforms=windows .
flutter run -d windows
```

El flujo ya construido (seleccionar PDF, escribir DNI, verificar
lector, escribir PIN, firmar) debería funcionar sin cambios — el campo
de PIN ahora sí se usa de verdad, a diferencia del intento anterior con
`Windows-MY`.

## Pendiente a propósito (siguiente iteración)

- Backup/archivo automático de los documentos firmados.
- Certificados raíz de RENIEC/IOFE para que `/verificar` confirme la
  cadena de confianza completa (hoy valida integridad y firma
  criptográfica, no la cadena).
- Sello de tiempo (TSA) y verificación de revocación (OCSP).
- Empaquetado final con `jpackage` + el build de Flutter, en un solo
  instalador.
- Soporte explícito para DNIe v1/v2 (hoy solo se implementó el
  protocolo de la versión 3, la más común).
