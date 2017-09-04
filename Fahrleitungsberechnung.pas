unit Fahrleitungsberechnung;

interface

uses
  Direct3D9, d3dx9, 
  
  sysutils, Controls, registry, windows, forms,
  
  ZusiD3DTypenDll, FahrleitungsTypen, FahrleitungConfigForm;

function Init:Longword; stdcall;
function BauartTyp(i:Longint):PChar; stdcall;
function Fahrleitungstyp:TFahrleitungstyp; stdcall;
procedure Systemversatz(s:single); stdcall;
procedure Reset(A:Boolean); stdcall;
procedure NeuerPunkt(A:Boolean; Punkt:TAnkerpunkt); stdcall;
function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
function ErgebnisDraht(i:Longword):TLinie; stdcall;
function ErgebnisDateien(i:Longword):TVerknuepfung; stdcall;
function dllVersion:PChar; stdcall;
function Autor:PChar; stdcall;
function Bezeichnung:PChar; stdcall;
function Drahthoehe:single; stdcall;
function Gruppe:PChar; stdcall;
procedure Config(AppHandle:HWND); stdcall;
function Mastabstand(Kruemmung:single; MastAbstand:single):single; stdcall;
procedure Maststandort(StrMitte, StreckenMitteNachfolger:TD3DVector; Winkel, Ueberhoehung, Helligkeitswert:single; Rechts:Boolean; var MastKoordinate, WinkelVektor:TD3DVector; var Dateiname:PChar); stdcall;
function AnkerImportDatei(i:Longword; var AnkerIndex:Longword; var Dateiname:PChar):Boolean; stdcall;

exports Init,
        BauartTyp,
        Fahrleitungstyp,
        Systemversatz,
        Reset,
        NeuerPunkt,
        BauartVorschlagen,
        Berechnen,
        ErgebnisDraht,
        ErgebnisDateien,
        dllVersion,
        Autor,
        Bezeichnung,
        Drahthoehe,
        Gruppe,
        Config,
        Mastabstand,
        Maststandort,
        AnkerImportDatei;


implementation

uses Classes;

const MaxAbstandSenkrecht = 10;

var ErgebnisArray:array of TLinie;
    ErgebnisArrayDateien:array of TVerknuepfung;
    PunkteA, PunkteB: array of TAnkerpunkt;
    KruemmungAktuell:single;
    RechtsAktuell:Boolean;
    DateiIsolator:string;


procedure RegistryLesen;
var reg: TRegistry;
begin
  try
    reg:=TRegistry.Create;
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\Re160ErweiterteFunktionen') then
            begin
              if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
            end;
  finally
    reg.Free;
  end;
end;



procedure RegistrySchreiben;
var reg: TRegistry;
begin
  try
    reg:=TRegistry.Create;
    reg.RootKey:=HKEY_CURRENT_USER;
    if reg.OpenKey('Software', False) then
    begin
      if reg.OpenKey('Zusi3', true)  then
      begin
        if reg.OpenKey('lib', true) then
        begin
          if reg.OpenKey('catenary', true) then
          begin
            if reg.OpenKey('Re160ErweiterteFunktionen', true) then
            begin
              reg.WriteString('DateiIsolator', DateiIsolator);
            end;
          end;
        end;
      end;
    end;
  finally
    reg.Free;
  end;
end;


function Init:Longword; stdcall;
// Rückgabe: Anzahl der Bauarttypen
begin
  Result:=2;  //muss passen zu den möglichen Rückgabewerten der function BauartTyp
  Reset(true);
  Reset(false);
  DateiIsolator:='Catenary\Deutschland\Einzelteile_Re75-200\Isolator.lod.ls3';
  RegistryLesen;
end;

function BauartTyp(i:Longint):PChar; stdcall;
// Wird vom Editor so oft aufgerufen, wie wir als Result in der init-function übergeben haben. Enumeriert die Bauart-Typen, die diese DLL kennt 
begin
  if i=0 then Result:='Abschluß mit Isolatoren';
  if i=1 then Result:='Ausfädelung mit Isolatoren'
end;


function Fahrleitungstyp:TFahrleitungstyp; stdcall;
//Wird nur für Automatik-Modus gebraucht; gibt an welche Sorte Fahrleitung wir verlegen
begin
  Result:=Fahrl_15kV16Hz;
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

function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
// Wir versuchen, aus der vom Editor übergebenen Ankerkonfiguration einen Bauarttypen vorzuschlagen
  function Vorschlagen(Punkte:array of TAnkerpunkt):Longint	;
  var iOben0, iUnten0, iOben1, iUnten1:integer;
      b:integer;
  begin
    Result:=-1;
    iOben0:=0;
    iUnten0:=0;
    iOben1:=0;
    iUnten1:=0;

    //liegt ein Spannpunkt vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAbspannungMastpunktFahrdraht then inc(iUnten0);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAbspannungMastpunktTragseil then inc(iOben0);
    end;
    if (iUnten0=1) and (iOben0=1) then Result:=0;

    //liegt ein Ausfädelungs-Ausleger vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungFahrdraht then inc(iUnten1);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungTragseil then inc(iOben1);
    end;
    if (iUnten1=1) and (iOben1=1) then Result:=1;
  end;

begin
  if A then Result:=Vorschlagen(PunkteA)
       else Result:=Vorschlagen(PunkteB);
end;


function PunktSuchen(A:Boolean; i:integer; ATyp:TAnkerTyp):TAnkerpunkt;
// sucht den i. Punkt vom Typ ATyp
var b:integer;
    gefunden:Boolean;
begin
  b:=0;
  gefunden:=false;
  if A then
  begin
    while (b<=length(PunkteA)-1) and (not gefunden) do
    begin
      if PunkteA[b].Ankertyp=ATyp then
      begin
        gefunden:=true;
        Result:=PunkteA[b];
      end;
      inc(b);
    end;
  end
  else
  begin
    while (b<=length(PunkteB)-1) and (not gefunden) do
    begin
      if PunkteB[b].Ankertyp=ATyp then
      begin
        gefunden:=true;
        Result:=PunkteB[b];
      end;
      inc(b);
    end;
  end;
end;

procedure KettenwerkAusfaedelungMitIsolator;
const DrahtR = 0.015;
var pktFA, pktFB, pktTA, pktTB, pktU, pktO:TAnkerpunkt;
    Abstand, Durchhang:single;
    vFahrdraht, vTragseil, v, vNeu:TD3DVector;
    i, a:integer;
    DrahtFarbe:TD3DColorValue;
begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    //Fahrdraht berechnen als Vektor von FA nach FB
    pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht);
    pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAusfaedelungFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);
    i:=round(Abstand/MaxAbstandSenkrecht+0.5);

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungAbspannungMastpunktTragseil);
    pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAusfaedelungTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);
    Durchhang:=Abstand/55;   // größere Zahl = weniger Durchhang
    for a:=1 to i do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      //unterer Kettenwerkpunkt
      D3DXVec3Scale(v, vFahrdraht, (a-0.5)/i);
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer Kettenwerkpunkt
      D3DXVec3Scale(v, vTragseil, (a-0.5)/i);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

//  TODO: Durchhang des Tragseils scharfschalten
      //Punkt absenken
//      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
//      D3DXVec3Scale(vNeu, v, 0.75/Durchhang+Durchhang*Sqr((a-0.5)/(i)-0.5));
//      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtR;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;


    // Tragseil
    for a:=1 to length(ErgebnisArray)-1 do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErgebnisArray[a-1].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[a].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtR;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      v:=ErgebnisArray[a].Punkt2;
    end;
    // "Halbe Endfelder"
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[0].Punkt2;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtR;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=v;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtR;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtR;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Isolator an der Ausfädelung unten
    D3DXVec3Scale(v, vFahrdraht, 0.03);
    D3DXVec3Subtract(pktU.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt, v);
    //Dateien eintragen
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
    //wir nehmen den Mittelwert der Winkel an den beiden Ankerpunkten als Winkel unseres Isolators.
    //TODO: Algorithmus entwickeln, der korrekte Ergebnisse unabhängig von der Ausrichtung der Ausleger ermittelt
    D3DXVec3Add(pktU.PunktTransformiert.Winkel, pktFA.PunktTransformiert.Winkel, pktFB.PunktTransformiert.Winkel);
    D3DXVec3Scale(pktU.PunktTransformiert.Winkel, pktU.PunktTransformiert.Winkel, 0.5);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //Isolator an der Ausfädelung oben
    D3DXVec3Scale(v, vTragseil, 0.03);
    D3DXVec3Subtract(pktO.PunktTransformiert.Punkt, pktTB.PunktTransformiert.Punkt, v);
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
    D3DXVec3Add(pktO.PunktTransformiert.Winkel, pktTA.PunktTransformiert.Winkel, pktTB.PunktTransformiert.Winkel);
    D3DXVec3Scale(pktO.PunktTransformiert.Winkel, pktO.PunktTransformiert.Winkel, 0.5);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //Isolator am Radspannwerk oben
    D3DXVec3Scale(v, vTragseil, 0.04);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt,v);
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
    D3DXVec3Add(pktO.PunktTransformiert.Winkel, pktTA.PunktTransformiert.Winkel, pktTB.PunktTransformiert.Winkel);
    D3DXVec3Scale(pktO.PunktTransformiert.Winkel, pktO.PunktTransformiert.Winkel, 0.5);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //Isolator am Radspannwerk unten
    D3DXVec3Scale(v, vFahrdraht, 0.04);
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt,v);
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
    D3DXVec3Add(pktU.PunktTransformiert.Winkel, pktFA.PunktTransformiert.Winkel, pktFB.PunktTransformiert.Winkel);
    D3DXVec3Scale(pktU.PunktTransformiert.Winkel, pktU.PunktTransformiert.Winkel, 0.5);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
  end
end;


function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
// Der Benutzer hat auf 'Ausführen' geklickt.
// Rückgabe: Anzahl der Linien
begin
  //zunächst nochmal Grundzustand herstellen
  setlength(ErgebnisArray, 0);
  setlength(ErgebnisArrayDateien, 0);

  //wenn wir mehrere Sorten Fahrdrähte verlegen können, wird hier entschieden was wir machen
  //TODO: Derzeit muss noch das Radspannwerk immer an A liegen.
  if (Typ1=0) and (Typ2=1) then KettenwerkAusfaedelungMitIsolator;
  
  Result.iDraht:=length(ErgebnisArray);
  Result.iDatei:=length(ErgebnisArrayDateien);
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

function Bezeichnung:PChar; stdcall;
begin
  Result:='Re 160 Erweiterte Funktionen'
end;

function Drahthoehe:single; stdcall;
// wir machen derzeit keine Drahthöhenberechnung für dne Automatikmodus und
// geben stumpf immer 5,50 m zurück.
begin
  Result:=5.5;
end;

function Gruppe:PChar; stdcall;
// Teilt dem Editor die Objektgruppe mit, die er bei den verknüpften Dateien vermerken soll
begin
  Result:=Gruppefahrleitung;
end;

procedure Config(AppHandle:HWND); stdcall;
var Formular:TFormFahrleitungConfig;
begin
  Application.Handle:=AppHandle;
  Formular:=TFormFahrleitungConfig.Create(Application);
  Formular.LabeledEditIsolator.Text:=DateiIsolator;

  Formular.ShowModal;

  if Formular.ModalResult=mrOK then
  begin
    DateiIsolator:=(Formular.LabeledEditIsolator.Text);
    RegistrySchreiben;
  end;

  Application.Handle:=0;
  Formular.Free;
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



end.
