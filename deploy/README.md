# Publicar Misión Espacial (GitHub + Railway o Vercel)

El juego es un solo proyecto de Godot. Para la web, Godot lo exporta a HTML5 (`index.html` + `.js` + `.wasm` + `.pck`).
No hay backend: solo hay que servir esos archivos con dos cabeceras HTTP que Godot web necesita (COOP y COEP).

## 1. Exportar la versión web desde Godot
1. Editor → Administrar plantillas de exportación → Descargar e instalar (solo la primera vez).
2. Proyecto → Exportar → preset **Web** (ya está configurado en `export_presets.cfg`).
3. Exportar proyecto → guardar en `deploy/web/index.html`.
4. Probar en local: `cd deploy`, `npm install`, `npm start` → http://localhost:3000

## 2. Subir el proyecto a GitHub
```bash
cd mision_espacial
git init
git add .
git commit -m "Misión Espacial - Polipops"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/mision-espacial.git
git push -u origin main
```
El `.gitignore` ya excluye `.godot/` y los respaldos. Si `deploy/web/index.pck` pesa más de 100 MB, instala Git LFS
(`git lfs install && git lfs track "*.pck"`) antes del `git add`.

## 3a. Railway (recomendado por el mentor)
1. railway.app → New Project → Deploy from GitHub repo → elige el repositorio.
2. Settings del servicio → **Root Directory**: `deploy`. Railway detecta `package.json` y ejecuta `npm start`.
3. Settings → Networking → **Generate Domain**. Ese enlace es el juego.
Cada `git push` vuelve a desplegar. Para actualizar: exportar de nuevo a `deploy/web` y hacer push.

## 3b. Vercel
1. vercel.com → Add New Project → importa el repositorio.
2. **Root Directory**: `deploy/web` · Framework: *Other* · sin build command.
3. Copia `deploy/vercel.json` dentro de `deploy/web/` (pone las cabeceras COOP/COEP) y haz push.
4. Deploy. El dominio `*.vercel.app` es el juego.

## 3c. itch.io (lo más rápido para una demo)
Comprime el contenido de `deploy/web` en un zip, crea el proyecto en itch.io como *HTML*, sube el zip, marca
"This file will be played in the browser" y, en Embed options, "SharedArrayBuffer support".

## Si la página carga pero el juego no arranca
Abre la consola del navegador: si menciona `SharedArrayBuffer`, faltan las cabeceras COOP/COEP (en Railway con este
`server.js` no pasa; en Vercel revisa que `vercel.json` esté dentro de `deploy/web`). El multijugador en red local (ENet) no
funciona en la versión web: ahí queda el modo por relevos en la misma pantalla.
