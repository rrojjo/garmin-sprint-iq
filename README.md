# Series — Garmin Forerunner 55

Cronómetro Connect IQ con vueltas manuales, frecuencia cardíaca e historial.
Guarda actividades como carrera en pista con el nombre «Series».

START inicia o pausa; BACK marca una vuelta durante la marcha. El menú de pausa
permite reanudar, guardar o descartar. UP/DOWN desplazan el historial. Mantener UP
en reposo abre los ajustes. Se conservan las décimas del cronómetro grande y las
centésimas del historial, los colores y los avisos configurables.

La vista solicita actualizaciones cada 50 ms durante la marcha. Compone la
pantalla en un búfer propio y presenta siempre una imagen completa para evitar
franjas negras. Entre los refrescos generales de un segundo, solo recalcula el
cronómetro si cambia la décima visible. Al marcar LAP muestra la vuelta cerrada
durante cuatro segundos mientras la siguiente continúa cronometrándose.
Las pausas detienen también la grabación FIT de Garmin.

## Compilar en Windows

Requiere el SDK Connect IQ instalado y la clave privada local `developer_key`.
La clave y los archivos generados están excluidos de Git.

Desde la carpeta `stopwatch`, en PowerShell:

```powershell
$seriesSdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg" -Raw).Trim()
& "$seriesSdk\bin\monkeyc.bat" -f monkey.jungle -d fr55 -o bin/Series.prg -y ../developer_key -w -l 3 -r -O 2
```

Para instalar, copiar `Series.prg` en `GARMIN/APPS` del FR55 conectado por USB.
Sustituir la instalación anterior de esta app; evitar mantener dos copias con
nombres distintos. La compilación no instala nada automáticamente en el reloj.

## Verificación

Con el simulador Connect IQ abierto, desde `stopwatch`:

```powershell
& "$seriesSdk\bin\monkeyc.bat" -f monkey.jungle -d fr55 -o bin/Series-tests.prg -y ../developer_key -w -l 3 -t
& "$seriesSdk\bin\monkeydo.bat" bin/Series-tests.prg fr55 /t
& "$seriesSdk\bin\monkeyc.bat" -f integration.jungle -d fr55 -o bin/Series-integration.prg -y ../developer_key -w -l 3
& "$seriesSdk\bin\monkeydo.bat" bin/Series-integration.prg fr55
```

Las cinco pruebas verifican pausas, acumulación de tiempos, recuperación en
pausa, formato, guardado al salir y visualización de la vuelta durante cuatro
segundos sin detener el cronómetro. La aplicación de integración usa el reloj
real del simulador, la vista de producción y la grabación nativa: marca dos
vueltas, pausa tres segundos, reanuda y guarda la vuelta final. Informa del
tiempo activo, las vueltas, la cadencia y las décimas omitidas. Borra la superficie
de pantalla antes de cada actualización para reproducir el fallo de las franjas
y comprobar la presentación de la imagen completa. No se incluye en el
ejecutable instalable.

Los FIT del simulador se generan en
`%TEMP%\com.garmin.connectiq\GARMIN\Activities`. Para inspeccionar el FIT de
integración, ejecutar esta prueba en una sesión nueva del simulador: las pruebas
unitarias aceleradas pueden dejar mensajes residuales en el grabador simulado.

La recuperación tras un cierre inesperado conserva el último checkpoint local;
si Garmin perdió la grabación nativa, no puede reconstruir muestras históricas.
Queda por validar la fluidez y el consumo en el reloj físico, así como la
presentación de la actividad sincronizada en Garmin Connect.
