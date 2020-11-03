library RE160ErweiterteFunktionen;

{ Wichtiger Hinweis zur DLL-Speicherverwaltung: ShareMem muss sich in der
  ersten Unit der unit-Klausel der Bibliothek und des Projekts befinden (Projekt-
  Quelltext anzeigen), falls die DLL Prozeduren oder Funktionen exportiert, die
  Strings als Parameter oder Funktionsergebnisse �bergeben. Das gilt f�r alle
  Strings, die von oder an die DLL �bergeben werden -- sogar f�r diejenigen, die
  sich in Records und Klassen befinden. Sharemem ist die Schnittstellen-Unit zur
  Verwaltungs-DLL f�r gemeinsame Speicherzugriffe, BORLNDMM.DLL.
  Um die Verwendung von BORLNDMM.DLL zu vermeiden, k�nnen Sie String-
  Informationen als PChar- oder ShortString-Parameter �bergeben. }
  

uses
  FastMM4,
  OLADLLgemeinsameFkt in 'OLADLLgemeinsameFkt.pas',
  Fahrleitungsberechnung in 'Fahrleitungsberechnung.pas',
  FahrleitungConfigForm in 'FahrleitungConfigForm.pas' {FormFahrleitungConfig},
  FahrleitungsTypen in 'FahrleitungsTypen.pas',
  ZusiD3DTypenDll in 'ZusiD3DTypenDll.pas',
  Direct3D9 in 'Direct3D9.pas',
  d3dx9 in 'd3dx9.pas',
  DXFile in 'DXFile.pas';

{$SetPEFlags $20}
{$R *.res}

begin
end.
