# ZusiFahrleitungsDLL

Fahrleitungs-DLLs f�r Zusi 3, basierend auf dem bei Zusi 3 mitgelieferten Beispiel-Quelltext von Carsten H�lscher.

## DLL "Re 330/250"
Erzeugt Kettenwerk f�r die Fahrleitungsbauformen Re 330 oder Re 250 der DB.

## DLL "Re 200"
Erzeugt Kettenwerk f�r die Fahrleitungsbauform Re 200 der DB.

## DLL "Re 160"
Erzeugt Kettenwerk f�r die Fahrleitungsbauformen Re 160, Re 100 oder Re 75 der DB.

## DLL "Ezs 1007"
Kann eine tragseillose/tragseilarme Fahrleitung nach Ezs 1007 erzeugen. F�r Festpunktabspannungen bitte einstweilen die Re-160-DLL verwenden. Zuk�nftig w�re denkbar, noch einen "Re-60-Modus" f�r die moderne Form der Einfachfahrleitung zu implementieren, bei der die L�nge des Tragseils mit der L�ngsspannweite variiert.

## Weitere Infos
Programmiersprache ist Delphi 7. Nicht weil ich gerne mit Antiquit�ten handele, sondern weil der Beispiel-Quelltext in dieser Sprache vorlag und ich nicht erst ein Portierungs-Projekt starten wollte, und Delphi 7 auch heute noch recht problemlos kostenlos zu bekommen ist. Au�erdem sind die DLLs damit ohne Klimmz�ge zu den Eigenarten des in Delphi 7 geschriebenen Zusi 3 kompatibel.

Um den Code zum kompilieren zu bringen, m�ssen die fehlenden Units erg�nzt werden aus $Zusi-Programmverzeichnis$ \_Docu\demos\catenary\source

Im Prinzip k�nnten diese DLLs kollaborativ noch um weitere Arten von Sonderfahrdr�hten erweitert werden.


-- A. Meschede