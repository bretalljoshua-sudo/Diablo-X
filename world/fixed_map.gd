class_name FixedMap
extends Resource
## Handgebaute Karte (das Dorf). Wird von VillageMap in ein LevelLayout übersetzt.
##
## Zeichen (Zeile = z, Spalte = x):
##   ,  Wiese               .  Weg               :  Erde
##   R  Felsen (Rand)       T  Baum              F  Zaun
##   H  Haus (Block)        D  Haustür (Rand eines Hauses)
##   W  Brunnen             l  Laterne mit Licht m  Marktstand
##   M  Händler (Marker)    C  Truhe (Marker)    @  Startpunkt
##   E  Eingang zu den Katakomben (Ausgang zur Ebene 1)
##   a  Ankunft, wenn man aus den Katakomben zurückkommt

@export var id: StringName = &""
@export var theme: StringName = &"village"
@export var pattern: PackedStringArray = PackedStringArray()
