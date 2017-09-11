# ZusiFahrleitungsDLL

Fahrleitungs-DLL für Zusi 3, basierend auf dem bei Zusi 3 mitgelieferten Beispiel-Quelltext von Carsten Hölscher.

Derzeit kann das Ding Abspannungen für Streckentrennungen erzeugen, die zwei zusätzliche Isolatoren in der Nähe der Ausfädelungs-Ausleger haben. Alle sonstigen Funktionen der DLL sind als experimentell zu sehen.

Programmiersprache ist Delphi 7. Nicht weil ich gerne mit Antiquitäten handele, sondern weil der Beispiel-Quelltext in dieser Sprache vorlag und ich nicht erst ein Portierungs-Projekt starten wollte, und Delphi 7 auch heute noch recht problemlos kostenlos zu bekommen ist. Außerdem ist die DLL damit ohne Klimmzüge zu den Eigenarten des in Delphi 7 geschriebenen Zusi 3 kompatibel.

Um das Ding zum kompilieren zu bringen, müssen die fehlenden Units ergänzt werden aus $Zusi-Programmverzeichnis$ \_Docu\demos\catenary\source

Im Prinzip könnte diese DLL kollaborativ noch um weitere Arten von Sonderfahrdrähten erweitert werden.


-- A. Meschede