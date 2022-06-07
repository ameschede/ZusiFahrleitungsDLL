unit OLADLLgemeinsameFkt; //von mehreren Fahrleitungs-DLL einheitlich gebrauchte Funktionen

{$MODE Delphi}

interface

uses
  Direct3D9, d3dx9,
  sysutils, windows, math,
  ZusiD3DTypenDll,FahrleitungsTypen,
  Forms, Graphics, Controls;

var
  ErgebnisArray:array of TLinie;
  ErgebnisArrayDateien:array of TVerknuepfung;
  PunkteA, PunkteB, PunkteTemp: array of TAnkerpunkt;

function Fahrleitungstyp:TFahrleitungstyp; stdcall;
function dllVersion:PChar; stdcall;
function Autor:PChar; stdcall;
procedure Systemversatz(s:single); stdcall;
procedure Reset(A:Boolean); stdcall;
procedure NeuerPunkt(A:Boolean; Punkt:TAnkerpunkt); stdcall;
function PunktSuchen(A:Boolean; i:integer; ATyp:TAnkerTyp):TAnkerpunkt;
function AnkerIstLeer(pAnker:TAnkerpunkt):Boolean;
procedure LageIsolator(Pkt1, Pkt2:TD3DVector; l:single; var xyz, xyzphi:TD3DVector);
procedure BaurichtungWechseln;
function ErgebnisDraht(i:Longword):TLinie; stdcall;
function ErgebnisDateien(i:Longword):TVerknuepfung; stdcall;
function Drahthoehe:single; stdcall;
function Mastabstand(Kruemmung:single; MastAbstand:single):single; stdcall;
procedure Maststandort(StrMitte, StreckenMitteNachfolger:TD3DVector; Winkel, Ueberhoehung, Helligkeitswert:single; Rechts:Boolean; var MastKoordinate, WinkelVektor:TD3DVector; var Dateiname:PChar); stdcall;
function AnkerImportDatei(i:Longword; var AnkerIndex:Longword; var Dateiname:PChar):Boolean; stdcall;
procedure HighDPI(FromDPI: Integer);
procedure ScaleDPI(Control: TControl; FromDPI: Integer);

implementation

function Fahrleitungstyp:TFahrleitungstyp; stdcall;
//Wird nur für Automatik-Modus gebraucht; gibt an welche Sorte Fahrleitung wir verlegen
begin
  Result:=Fahrl_15kV16Hz;
end;

function dllVersion:PChar; stdcall;

  function GetOwnVersion: String;
  Var
    VerInfoSize : DWORD;
    VerInfo : Pointer;
    VerValueSize : DWORD;
    VerValue : PVSFixedFileInfo;
    V1, V2, V3, V4 : Word;
    Dummy : DWORD;
    DllName: array[0..MAX_PATH-1] of char;

  Begin
    GetModuleFileName(hinstance, DllName, sizeof(DllName)-1);
    VerInfoSize := GetFileVersionInfoSize(DllName, Dummy);
    GetMem(VerInfo, VerInfoSize);
    GetFileVersionInfo(DllName, 0, VerInfoSize, VerInfo);
    VerQueryValue(VerInfo, '\', Pointer(VerValue), VerValueSize);
    With VerValue^ Do
    Begin
      V1 := dwFileVersionMS Shr 16;
      V2 := dwFileVersionMS And $FFFF;
      V3 := dwFileVersionLS Shr 16;
      V4 := dwFileVersionLS And $FFFF;
    End;
    FreeMem(VerInfo, VerInfoSize);
    Result := ' ' + IntToSTr(V1) + '.' + IntToSTr(V2) + '.' + IntToSTr(V3)
  +
      '.' + IntToStr(V4);
  end;

begin
  Result:=pChar(GetOwnVersion);
end;


function Autor:PChar; stdcall;
begin
  Result:='Alwin Meschede'
end;


procedure Systemversatz(s:single); stdcall;
//Wird nur für Automatik-Modus gebraucht
begin
//nicht implementiert
end;


procedure Reset(A:Boolean); stdcall;
// Internen Zustand der DLL auf 0 setzen
begin
  setlength(ErgebnisArray, 0);
  setlength(ErgebnisArrayDateien, 0);
  if A then setlength(PunkteA, 0)
       else setlength(PunkteB, 0);
end;


procedure NeuerPunkt(A:Boolean; Punkt:TAnkerpunkt); stdcall;
// Wenn der Benutzer ein Fahrleitungsbauteil angeklickt hat, ruft der Editor für
// jeden Anker des Bauteils diese Funktion auf. Damit werden der DLL die
// Positionen der Ankerpunkte bekanntgemacht
begin
  if A then
  begin
    setlength(PunkteA, length(PunkteA)+1);
    PunkteA[length(PunkteA)-1]:=Punkt;
  end
  else
  begin
    setlength(PunkteB, length(PunkteB)+1);
    PunkteB[length(PunkteB)-1]:=Punkt;
  end;
end;


function PunktSuchen(A:Boolean; i:integer; ATyp:TAnkerTyp):TAnkerpunkt;
// sucht den i. Punkt vom Typ ATyp
var b,iGefunden:integer;
    LeerAnker:TAnkerpunkt;
begin
  //Result-Variable zumindest so weit initialisieren, dass sie ggfs. von AnkerIstLeer erkannt werden kann
  LeerAnker.PunktTransformiert.Punkt.x :=0;
  LeerAnker.PunktTransformiert.Punkt.y :=0;
  LeerAnker.PunktTransformiert.Punkt.z :=0;
  Result := LeerAnker;
  b:=0;
  iGefunden:=0;
  if A then
  begin
    while (b<=length(PunkteA)-1) and not(iGefunden > i) do
    begin
      if PunkteA[b].Ankertyp=ATyp then
      begin
        inc(iGefunden);
        Result:=PunkteA[b];
      end;
      inc(b);
    end;
  end
  else
  begin
    while (b<=length(PunkteB)-1) and not(iGefunden > i) do
    begin
      if PunkteB[b].Ankertyp=ATyp then
      begin
        inc(iGefunden);
        Result:=PunkteB[b];
      end;
      inc(b);
    end;
  end;
end;


function AnkerIstLeer(pAnker:TAnkerpunkt):Boolean;
begin;
  if (pAnker.PunktTransformiert.Punkt.x = 0) and (pAnker.PunktTransformiert.Punkt.y = 0) and (pAnker.PunktTransformiert.Punkt.z = 0) then
    Result := true
  else
    Result := false;
end;


procedure LageIsolator(Pkt1, Pkt2:TD3DVector; l:single; var xyz, xyzphi:TD3DVector);
  // berechnt die Position eines Isolators auf dem Draht
var v, vNorm, h:TD3DVector;
      Winkelz, Winkelx:single;
begin
    D3DXVec3Subtract(v, Pkt2, Pkt1);
    D3DXVec3Normalize(vNorm, v);
    D3DXVec3Scale(h, vNorm, l);
    D3DXVec3Add(xyz, h, Pkt1);

    Winkelz:=arctan2(Pkt2.y-Pkt1.y, Pkt2.x-Pkt1.x);
    Winkelx:=arctan2(Pkt2.z-Pkt1.z, sqrt(sqr(Pkt2.x-Pkt1.x)+sqr(Pkt2.y-Pkt1.y)));
    xyzphi.x:=-Winkelx;
    xyzphi.y:=0;
    xyzphi.z:=Winkelz+Pi/2;
end;


procedure BaurichtungWechseln;
begin
  PunkteTemp:=PunkteA;
  PunkteA:=PunkteB;
  PunkteB:=PunkteTemp;
end;


function ErgebnisDraht(i:Longword):TLinie; stdcall;
// wird vom Editor je nach Länge des Result-Arrays der function Berechnen
// aufgerufen, um sich nach und nach die berechneten Drähte abzuholen
begin
  if (i>=0) and (i<=length(ErgebnisArray)-1) then Result:=ErgebnisArray[i];
end;


function ErgebnisDateien(i:Longword):TVerknuepfung; stdcall;
// wird vom Editor je nach Länge des Result-Arrays der function Berechnen
// aufgerufen, um sich nach und nach die berechneten verknüpften Dateien abzuholen
begin
  if (i>=0) and (i<=length(ErgebnisArrayDateien)-1) then Result:=ErgebnisArrayDateien[i];
end;


function Drahthoehe:single; stdcall;
// wir machen derzeit keine Drahthöhenberechnung für den Automatikmodus und
// geben stumpf immer 5,50 m zurück.
begin
  Result:=5.5;
end;


function Mastabstand(Kruemmung:single; MastAbstand:single):single; stdcall;
// wird nur für Automatikmodus gebraucht. Nicht implementiert, deshalb gibt sie immer stumpf 80 m zurück.
begin
  Result:=80;
end;


procedure Maststandort(StrMitte, StreckenMitteNachfolger:TD3DVector; Winkel, Ueberhoehung, Helligkeitswert:single; Rechts:Boolean; var MastKoordinate, WinkelVektor:TD3DVector; var Dateiname:PChar); stdcall;
// wird nur für Automatikmodus gebraucht. Nicht implementiert
begin

end;


function AnkerImportDatei(i:Longword; var AnkerIndex:Longword; var Dateiname:PChar):Boolean; stdcall;
// Wird nur für Automatikmodus gebraucht; Nicht implementiert
begin
  Result:=false;
end;

procedure HighDPI(FromDPI: Integer);
var
  i: Integer;
begin
  for i:=0 to Screen.FormCount-1 do
    ScaleDPI(Screen.Forms[i],FromDPI);
end;

procedure ScaleDPI(Control: TControl; FromDPI: Integer);
var
  n: Integer;
  WinControl: TWinControl;
begin
  if Screen.PixelsPerInch = FromDPI then exit;

  with Control do begin
    Left:=ScaleX(Left,FromDPI);
    Top:=ScaleY(Top,FromDPI);
    Width:=ScaleX(Width,FromDPI);
    Height:=ScaleY(Height,FromDPI);
    Font.Height := ScaleY(Font.GetTextHeight('Hg'),FromDPI);
  end;

  if Control is TWinControl then begin
    WinControl:=TWinControl(Control);
    if WinControl.ControlCount > 0 then begin
      for n:=0 to WinControl.ControlCount-1 do begin
        if WinControl.Controls[n] is TControl then begin
          ScaleDPI(WinControl.Controls[n],FromDPI);
        end;
      end;
    end;
  end;
end;

end.
 
