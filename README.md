# Examen GAD-2401 · Tema 1 y subtema 2.1.1

Examen web de opción múltiple (30 preguntas, 90 minutos) para *Análisis y visualización de datos*, con monitoreo por cámara web y panel en vivo para el docente. Son dos archivos estáticos, sin servidor propio:

- `index.html`: el examen que contestan los alumnos.
- `monitor.html`: el panel del docente (requiere iniciar sesión).
- `supabase_setup.sql`: tablas, bucket y permisos.

## Qué hace el examen

- Pide nombre y matrícula, **prueba la cámara** y abre el examen en **pantalla completa**.
- Cuenta como **falta**: salir de pantalla completa, minimizar, cambiar de pestaña o ventana, copiar, cortar, pegar, atajos de herramientas de desarrollo, captura de pantalla, **apagar, tapar o desconectar la cámara** y recargar la página.
- Con **más de 5 faltas** (la sexta) el examen se termina solo y se muestra el resultado.
- Temporizador de 90 minutos; al llegar a cero se entrega automáticamente.
- Panel de estado de preguntas (sin contestar, contestada, marcada, actual); se puede avanzar, retroceder y cambiar respuestas.
- Preguntas y opciones en orden aleatorio por alumno.
- El alumno ve su propia cámara en vivo durante el examen, para que sepa que está activa.

## Monitoreo con cámara

- Cada **20 s** se toma una foto pequeña (320 px, con fecha y hora impresas), y también al inicio, al final y **en cada falta**. Se suben a un bucket privado de Supabase.
- Cada **15 s** el examen reporta su estado: preguntas contestadas, faltas y tiempo restante.
- Se marca una foto como **oscura** si el brillo promedio es muy bajo (cámara tapada o poca luz). Es una alerta para el docente, no una falta.
- El panel `monitor.html` muestra una tarjeta por alumno con su última foto, estado (En curso, Sin señal, Cámara apagada, Finalizado), faltas, avance y tiempo restante. Las tarjetas con alertas suben al principio. Al hacer clic se ve el historial de faltas y la galería completa de fotos.
- La pestaña **Resultados** lista las calificaciones y las exporta a CSV.

Es monitoreo casi en tiempo real con fotografías, no video continuo. Para transmisión de video en vivo haría falta WebRTC con un servidor TURN, que queda fuera de este proyecto.

## Puesta en marcha

### 1. Supabase
1. Crea un proyecto en <https://supabase.com>.
2. En **SQL Editor** pega todo `supabase_setup.sql` y ejecútalo. Crea la tabla de resultados, la de eventos, el bucket `capturas-examen` y los permisos.
3. En **Authentication → Users** crea tu usuario docente (correo y contraseña).
4. En **Authentication → Sign In / Providers → Email**, desactiva el registro de nuevos usuarios (*Allow new users to sign up*). Cualquier usuario autenticado puede ver las fotos, así que solo tú debes existir.
5. En **Project Settings → API** copia la **Project URL** y la clave **anon public**.

### 2. Configura los archivos
En `index.html` y en `monitor.html`, bloque `CONFIG`, reemplaza:

```js
SUPABASE_URL: 'https://TU-PROYECTO.supabase.co',
SUPABASE_ANON_KEY: 'TU_ANON_PUBLIC_KEY',
```

La clave `anon` es pública por diseño; la protección la dan las políticas: los alumnos solo pueden **insertar** y no leer nada. **Nunca pongas la clave `service_role` en estos archivos.**

En `index.html` también puedes ajustar `CAPTURE_SECS`, `HEARTBEAT_SECS`, `CAPTURE_W`, `JPEG_QUALITY`, `DURATION_MIN` y `MAX_VIOLATIONS`. Si cambias `EXAM_ID`, cámbialo igual en `monitor.html`.

### 3. Publica en GitHub
1. Sube `index.html`, `monitor.html` (y opcionalmente el README y el SQL) a un repositorio.
2. **Settings → Pages → Deploy from a branch → `main` / root**.
3. Alumnos: `https://TU-USUARIO.github.io/TU-REPO/`. Docente: `https://TU-USUARIO.github.io/TU-REPO/monitor.html`.

La cámara solo funciona en **HTTPS** (GitHub Pages ya lo es) o en `localhost`.

## Privacidad y datos personales

Las fotografías son datos personales. Antes de aplicar el examen:

- Informa a los alumnos y publica el aviso de privacidad de tu institución. El examen ya incluye una casilla de consentimiento y reglas visibles antes de empezar.
- Usa las fotos solo para supervisar este examen y define cuánto tiempo se conservan.
- Cuando termines la revisión, borra las fotos desde **Storage → capturas-examen** o con SQL:

```sql
delete from storage.objects where bucket_id = 'capturas-examen';
delete from public.monitoreo_eventos where examen = 'GAD-2401-U1-2.1.1';
```

## Limitaciones que conviene conocer

- **La detección corre en el navegador del alumno.** Disuade y deja evidencia, pero no es infalible: no ve un segundo dispositivo ni una máquina virtual. Las fotos ayudan a revisar, pero no identifican personas ni detectan por sí solas a alguien más en la habitación; las revisa el docente.
- **La clave de respuestas va dentro de `index.html`.** Un alumno técnico podría leerla. Para más seguridad, la calificación se puede mover a una función de Supabase.
- **Cualquiera con la clave `anon` podría insertar eventos o fotos falsas** (no leer ni borrar). Si ves actividad rara, compara contra los resultados guardados.
- **El bloqueo de repetir el examen es local** (`localStorage`). Revisa duplicados por matrícula.
- **Safari en iPhone no admite pantalla completa en páginas web**, así que el examen debe hacerse en computadora con cámara.
- Si el alumno no tiene cámara o la niega, no puede iniciar. Con `CAMERA_REQUIRED: false` el examen funciona sin cámara.
- Para reiniciar un examen en tu equipo durante pruebas: `localStorage.removeItem('gad2401_sesion_v1')` en la consola del navegador.
