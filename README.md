# ZusiFahrleitungsDLL
Fahrleitungs-DLLs für Zusi 3, basierend auf dem bei Zusi 3 mitgelieferten Beispiel-Quelltext von Carsten Hölscher.

## DLL "Re 330/250"
Erzeugt Kettenwerk für die Fahrleitungsbauformen Re 330 oder Re 250 der DB.

## DLL "Re 200"
Erzeugt Kettenwerk für die Fahrleitungsbauformen Re 200 und Re 200 mod der DB.

## DLL "Re 160"
Erzeugt Kettenwerk für die Fahrleitungsbauformen Re 160, Re 100 oder Re 75 der DB.

## DLL "Re 120"
Erzeugt Kettenwerk für die Fahrleitungsbauform Re 120 der DB.

## DLL "Ezs 1007"
Kann eine tragseillose/tragseilarme Fahrleitung nach Ezs 1007 erzeugen. Für Festpunktabspannungen bitte einstweilen die Re-160-DLL verwenden. Zukünftig wäre denkbar, noch einen "Re-60-Modus" für die moderne Form der Einfachfahrleitung zu implementieren, bei der die Länge des Tragseils mit der Längsspannweite variiert.

## DLL "Catenaire France"
Erzeugt Kettenwerk der französischen Fahrleitungsbauart V350 STI.

## Weitere Infos
Updates der DLLs werden in der Regel über den Weg offizieller Zusi-Programmupdates verteilt.

Entwicklungsumgebung ist Lazarus.
Um den Code zum kompilieren zu bringen, müssen die beiden Units FahrleitungsTypen.pas und ZusiD3DTypenDll.pas übernommen werden aus $Zusi-Programmverzeichnis$ \_Docu\demos\catenary\source

Im Prinzip könnten diese DLLs kollaborativ noch um weitere Arten von Sonderfahrdrähten erweitert werden.


-- A. Meschede