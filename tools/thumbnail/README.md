# Icoon en thumbnail maken

Een 3D-scène (three.js) met Roblox-achtige blokpoppetjes, die als afbeelding wordt opgeslagen.

```sh
cd tools/thumbnail
npm install
python3 -m http.server 8765 --bind 127.0.0.1 &   # de scène moet via http geladen worden
node render.js                                    # maakt icon.png (512x512) en thumb.png (1920x1080)
```

Pas `scene.html` aan om poppetjes, kleuren, tekst of camera te veranderen.
De lettertypes (Luckiest Guy en Creepster) vallen onder de SIL Open Font License.
