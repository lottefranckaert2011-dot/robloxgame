# Clean The Library 📖 [Nightmare]

Een namaak van het Roblox-spel **Clean The Library** (van de groep *Retro Library*), in een **Nightmare**-versie met een monster.
Het origineel speel je hier: <https://www.roblox.com/games/109881277752094/Clean-The-Library>.

De prachtige bibliotheek is één grote rommel: overal liggen boeken op de grond. Zet ze allemaal terug in de juiste kast
voordat de tijd op is. Maar **wees stil**: *De Bibliothecaresse* sluipt door de gangen…

## Snel spelen

1. Open **Roblox Studio**.
2. Kies *File → Open from File…* en open `build/CleanTheLibraryNightmare.rbxlx`.
3. Druk op **Play** (F5).

Om met vrienden te spelen: *File → Publish to Roblox*.

> Wil je dat munten en sleutels bewaard blijven? Zet dan in Studio *Game Settings → Security →
> Enable Studio Access to API Services* aan (en publiceer het spel).

## Hoe speel je

| Toets | Wat het doet |
| --- | --- |
| **E** | Boek oppakken / boeken in de kast terugzetten / verstoppen in een kast |
| **1 – 4** | Magie gebruiken (eerst kopen in het Magie-menu) |
| **Shift** | Sprinten. Pas op: sprinten maakt lawaai! |
| **G** | Laat de boeken die je draagt vallen |
| **F** | Winkel |
| **C** | Magie |
| **M** | Assistent |
| **Z** | Instellingen |

Op een telefoon of tablet tik je gewoon op de knoppen in beeld.

- Elk boek heeft een **code** zoals `1H` of `2G` op de rug. De groene bordjes op de kasten tonen dezelfde code.
- Er zijn **31 kastsecties**: `1A`–`1N` op de begane grond en `2A`–`2Q` op de eerste verdieping (via de oprit rechts).
- Je kunt in het begin **3 boeken** tegelijk dragen.
- Ruim je alle boeken op voordat de **20 minuten** om zijn, dan win je extra munten.
- Rechtsonder zie je hoeveel boeken er terug staan (📚) en hoeveel je draagt (📖).

### Munten uitgeven

- **Winkel (F)**: *Grotere Tas* (meer boeken dragen) en *Snelle Schoenen* (sneller lopen).
- **Magie (C)**: vier vaardigheden voor de vakjes 1–4. 👁 *Inzicht* laat boeken in de buurt oplichten,
  🧭 *Kastgids* wijst met een lichtstraal de goede kast aan, 🧲 *Verzamelen* trekt de dichtstbijzijnde boeken naar je toe
  en ✨ *Auto-plaatsen* laat al je boeken vanzelf naar de goede kast vliegen.
- **Assistent (M)**: *Uil Oehoe* laat af en toe een boek naar de goede kast zweven.

### De Nightmare

- Na 20 seconden wordt **De Bibliothecaresse** wakker. Ze loopt rond over beide verdiepingen,
  komt af op lawaai (sprinten, een boek in de verkeerde kast) en zit iedereen achterna die ze ziet.
- Hoe meer boeken er terug staan, hoe sneller ze wordt.
- Een rode, kloppende rand op je scherm betekent dat ze dichtbij is.
- Verstop je in een **houten kast**. Maar als ze ziet dat je erin kruipt, trekt ze je eruit!
- Word je gepakt, dan vliegen je boeken terug door de bibliotheek.

### Verborgen sleutels

Ergens in de bibliotheek liggen vier gloeiende sleutels. Ze geven een upgrade die blijft:

| Sleutel | Upgrade |
| --- | --- |
| Karmijnrode Achthoek | Je springt veel hoger |
| Gouden Diamant | +3 boeken dragen |
| Azuurblauwe Ster | +3 boeken dragen |
| Smaragdgroene Klaver | Je sprint veel sneller |

## Aanpassen

Bijna alles staat in [`src/shared/Config.luau`](src/shared/Config.luau): speeltijd, aantal boeken per sectie,
snelheid van het monster, prijzen in de winkel, namen van secties en boektitels, enzovoort.

De hele bibliotheek wordt met code gebouwd zodra je op Play drukt (je ziet hem dus niet in de editor).
Wil je modellen uit de Creator Store gebruiken, zoals planten, lampen of beelden? Sleep ze dan in Studio
vanuit de *Toolbox* in de Workspace. Ze blijven gewoon staan naast de bibliotheek. Handige plekken om naar te kijken:
de begane grond loopt van x −120 tot 120 en z −80 tot 80, en de eerste verdieping ligt op hoogte 24.

| Bestand | Wat erin zit |
| --- | --- |
| `src/server/LibraryBuilder.luau` | Bouwt de bibliotheek: muren met bogen en pilaren, dakraam, kasten met bordjes, lampen, planten, tafels |
| `src/server/BookService.luau` | Boeken verspreiden, oppakken, dragen en terugzetten |
| `src/server/ShopService.luau` | Winkel, magie en de assistent |
| `src/server/MonsterService.luau` | De AI van De Bibliothecaresse (patrouilleren, horen, zien, jagen) |
| `src/server/KeyService.luau` | De vier sleutels en hun upgrades |
| `src/server/HideService.luau` | Verstoppen in kasten |
| `src/server/RoundService.luau` | Rondes: pauze → opruimen → gewonnen/verloren |
| `src/server/DataService.luau` | Munten, sleutels en records opslaan |
| `src/client/*` | Scherm (HUD), besturing, vaardigheden en griezel-effecten |

### Werken met Rojo

Het project gebruikt [Rojo](https://rojo.space/) 7.4. Na een wijziging in `src/`:

```sh
rojo build default.project.json -o build/CleanTheLibraryNightmare.rbxlx   # nieuw place-bestand
rojo serve                                                                # of: live synchroniseren met de Rojo-plugin in Studio
```

De geluiden zijn ingebouwde Roblox-geluiden; in `Config.SoundIds` kun je ze vervangen door eigen sound IDs.
