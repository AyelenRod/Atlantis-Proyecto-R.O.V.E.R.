// Servidor mínimo para publicar la exportación web de Godot (carpeta deploy/web) en Railway,
// Render, Fly.io o cualquier host de Node. No hay backend de juego: solo archivos estáticos.
// Las dos cabeceras COOP/COEP son obligatorias para que Godot 4 web funcione con hilos.
const express = require("express");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;
const WEB = path.join(__dirname, "web");

app.use((req, res, next) => {
  res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
  res.setHeader("Cross-Origin-Embedder-Policy", "require-corp");
  next();
});
app.use(express.static(WEB, {
  setHeaders: (res, filePath) => {
    if (filePath.endsWith(".wasm")) res.setHeader("Content-Type", "application/wasm");
    if (filePath.endsWith(".pck")) res.setHeader("Content-Type", "application/octet-stream");
  },
}));
app.get("/salud", (_req, res) => res.send("ok"));

app.listen(PORT, () => console.log(`Misión Espacial web en el puerto ${PORT}`));
