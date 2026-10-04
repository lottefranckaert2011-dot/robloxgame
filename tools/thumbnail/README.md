# Icoon en thumbnail maken

Een 3D-scène (three.js) met Roblox-achtige blokpoppetjes, die als afbeelding wordt opgeslagen.

```sh
cd tools/thumbnail
npm install
python3 -m http.server 8765 --bind 127.0.0.1 &   # de scène moet via http geladen worden
node render_before_after.js                       # het huidige icoon + de voor/na-thumbnail (icon2.png, thumb2.png)
node render.js                                    # de nachtversie (icon.png, thumb.png)
```

Pas `before_after.html` (huidige afbeeldingen) of `scene.html` (nachtversie) aan om poppetjes, kleuren, tekst of camera te veranderen.
De lettertypes (Luckiest Guy en Creepster) vallen onder de SIL Open Font License.
