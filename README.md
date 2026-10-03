# Clean The Library 📖 [Nightmare]

Een namaak van het Roblox-spel **Clean The Library** (van de groep *Retro Library*), in een griezelige **Nightmare**-versie.
Het origineel speel je hier: <https://www.roblox.com/games/109881277752094/Clean-The-Library>.

Het is midden in de nacht en de bibliotheek is één grote rommel. Zet alle boeken terug in de juiste kast
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
| **E** | Boek oppakken / boeken in de kast terugzetten / verstoppen in een kluisje |
| **Shift** | Sprinten. Pas op: sprinten maakt lawaai! |
| **F** | Zaklamp aan/uit. Jij ziet meer, maar zij ziet jou ook van verder weg |
| **Q** | **Inzicht**: laat de boeken in de buurt oplichten (afkoeltijd 30 s) |
| **T** | **Kastgids**: een lichtstraal wijst naar de kast van je boek (afkoeltijd 20 s) |
| **G** | Laat de boeken die je draagt vallen |

Op een telefoon of tablet staan dezelfde acties als knoppen rechts op het scherm.

- Elk boek heeft een **code** zoals `1H` of `2G`. Het bordje boven elke kast toont de code en het onderwerp.
- Er zijn **31 kastsecties**: `1A`–`1N` op de begane grond en `2A`–`2Q` op de eerste verdieping (via de oprit rechts).
- Je kunt in het begin **3 boeken** tegelijk dragen.
- Zet je een boek in de **verkeerde kast**, dan hoort het monster dat van ver weg.
- Ruim je alle boeken op voordat de **20 minuten** om zijn, dan win je munten.

### De Nightmare

- Het is donker, lampen flikkeren en er hangt mist.
- Na 20 seconden wordt **De Bibliothecaresse** wakker. Ze patrouilleert over beide verdiepingen,
  komt af op lawaai (sprinten, foute kast) en jaagt op iedereen die ze ziet.
- Hoe meer boeken er terug staan, hoe sneller ze wordt.
- Een rode, kloppende rand op je scherm betekent dat ze dichtbij is.
- Verstop je in een **kluisje**. Maar als ze ziet dat je erin kruipt, trekt ze je eruit!
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
snelheid van het monster, namen van secties en boektitels, enzovoort.

| Bestand | Wat erin zit |
| --- | --- |
| `src/server/LibraryBuilder.luau` | Bouwt de bibliotheek: vloeren, oprit, kasten, bordjes, lampen, tafels, kluisjes |
| `src/server/BookService.luau` | Boeken verspreiden, oppakken, dragen en terugzetten |
| `src/server/MonsterService.luau` | De AI van De Bibliothecaresse (patrouilleren, horen, zien, jagen) |
| `src/server/KeyService.luau` | De vier sleutels en hun upgrades |
| `src/server/HideService.luau` | Verstoppen in kluisjes |
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
