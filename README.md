# ZusiFahrleitungsDLL

Fahrleitungs-DLL f�r Zusi 3, basierend auf dem bei Zusi 3 mitgelieferten Beispiel-Quelltext von Carsten H�lscher.

Derzeit kann das Ding Abspannungen f�r Streckentrennungen erzeugen, die zwei zus�tzliche Isolatoren in der N�he der Ausf�delungs-Ausleger haben. Im Moment gelten dabei folgende Einschr�nkungen:

- Das Radspannwerk muss immer Anbaupunkt A sein, die Ausf�delung immer Anbaupunkt B. Sonst baut die DLL nichts.
- Der Durchhang des Tragseils ist in der aktuellen Version deaktiviert, weil ich es noch nicht hinbekommen habe auf ein durchh�ngendes Tragseil einen Isolator passend aufzuf�deln.
- Bei bestimmten Konstellationen der beteiligten Ankerpunkte zueinander werden die Isolatoren um 90 � gedreht platziert. Das kann im Nachgang dann von Hand korrigiert werden. Hier ist ein smarterer Algorithmus zur Bestimmung der Winkel f�llig.

Programmiersprache ist Delphi 7. Nicht weil ich gerne mit Antiquit�ten handele, sondern weil der Beispiel-Quelltext in dieser Sprache vorlag und ich nicht erst ein Portierungs-Projekt starten wollte, und Delphi 7 auch heute noch recht problemlos kostenlos zu bekommen ist. Au�erdem ist die DLL damit ohne Klimmz�ge zu den Eigenarten des in Delphi 7 geschriebenen Zusi 3 kompatibel.

Um das Ding zum kompilieren zu bringen, m�ssen die fehlenden Units erg�nzt werden aus $Zusi-Programmverzeichnis$\_Docu\demos\catenary\source

Im Prinzip k�nnte diese DLL kollaborativ noch um weitere Arten von Sonderfahrdr�hten erweitert werden.


-- A. Meschede