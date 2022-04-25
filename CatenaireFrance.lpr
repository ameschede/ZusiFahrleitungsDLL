library CatenaireFrance;

{$MODE Delphi}

{ Wichtiger Hinweis zur DLL-Speicherverwaltung: ShareMem muss sich in der
  ersten Unit der unit-Klausel der Bibliothek und des Projekts befinden (Projekt-
  Quelltext anzeigen), falls die DLL Prozeduren oder Funktionen exportiert, die
  Strings als Parameter oder Funktionsergebnisse übergeben. Das gilt für alle
  Strings, die von oder an die DLL übergeben werden -- sogar für diejenigen, die
  sich in Records und Klassen befinden. Sharemem ist die Schnittstellen-Unit zur
  Verwaltungs-DLL für gemeinsame Speicherzugriffe, BORLNDMM.DLL.
  Um die Verwendung von BORLNDMM.DLL zu vermeiden, können Sie String-
  Informationen als PChar- oder ShortString-Parameter übergeben. }
  

uses
  OLADLLgemeinsameFkt in 'OLADLLgemeinsameFkt.pas',
  CatenaireFranceBerechnung in 'CatenaireFranceBerechnung.pas',
  CatenaireFranceConfigForm in 'CatenaireFranceConfigForm.pas' {FormFahrleitungConfig},
  FahrleitungsTypen in 'FahrleitungsTypen.pas',
  ZusiD3DTypenDll in 'ZusiD3DTypenDll.pas';

{$SetPEFlags $20}
{$R *.res}

begin
end.
