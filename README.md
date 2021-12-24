# ZusiFahrleitungsDLL

Fahrleitungs-DLLs für Zusi 3, basierend auf dem bei Zusi 3 mitgelieferten Beispiel-Quelltext von Carsten Hölscher.

## DLL "Re 330/250"
Erzeugt Kettenwerk für die Fahrleitungsbauformen Re 330 oder Re 250 der DB.

## DLL "Re 200"
Erzeugt Kettenwerk für die Fahrleitungsbauform Re 200 der DB.

## DLL "Re 160"
Erzeugt Kettenwerk für die Fahrleitungsbauformen Re 160, Re 100 oder Re 75 der DB.

## DLL "Ezs 1007"
Kann eine tragseillose/tragseilarme Fahrleitung nach Ezs 1007 erzeugen. Für Festpunktabspannungen bitte einstweilen die Re-160-DLL verwenden. Zukünftig wäre denkbar, noch einen "Re-60-Modus" für die moderne Form der Einfachfahrleitung zu implementieren, bei der die Länge des Tragseils mit der Längsspannweite variiert.

## Weitere Infos
Programmiersprache ist Delphi 7. Nicht weil ich gerne mit Antiquitäten handele, sondern weil der Beispiel-Quelltext in dieser Sprache vorlag und ich nicht erst ein Portierungs-Projekt starten wollte, und Delphi 7 auch heute noch recht problemlos kostenlos zu bekommen ist. Außerdem sind die DLLs damit ohne Klimmzüge zu den Eigenarten des in Delphi 7 geschriebenen Zusi 3 kompatibel.

Um den Code zum kompilieren zu bringen, müssen die fehlenden Units ergänzt werden aus $Zusi-Programmverzeichnis$ \_Docu\demos\catenary\source

Im Prinzip könnten diese DLLs kollaborativ noch um weitere Arten von Sonderfahrdrähten erweitert werden.


-- A. Meschede