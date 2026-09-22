class_name NameParts
extends Resource
## Wortbausteine für den Namensgenerator (Daten: data/items/name_parts.tres).
##
## Magisch: "<Grundform> <Zusatz>", der Zusatz kommt vom stärksten Affix, zum Beispiel
## "Langschwert der Glut". Selten: zusammengesetztes Wort aus zwei Listen, zum Beispiel
## "Grabeszorn". Legendär: "<Grundform> <Aspektname ohne 'Aspekt '>".

## Namenszusatz im Genitiv je Stat, zum Beispiel "der Wut".
@export var suffixes: Dictionary[Enums.Stat, String] = {}
## Erste Hälfte seltener Namen, zum Beispiel "Grabes".
@export var rare_first: PackedStringArray = []
## Zweite Hälfte seltener Namen (klein geschrieben), zum Beispiel "zorn".
@export var rare_second: PackedStringArray = []
