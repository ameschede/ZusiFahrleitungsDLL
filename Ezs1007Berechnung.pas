unit Ezs1007Berechnung;

interface

uses
  Direct3D9, d3dx9, 
  
  sysutils, Controls, registry, windows, forms, Math,
  
  ZusiD3DTypenDll, FahrleitungsTypen, Ezs1007ConfigForm;

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

var ErgebnisArray:array of TLinie;
    ErgebnisArrayDateien:array of TVerknuepfung;
    PunkteTemp, PunkteA, PunkteB: array of TAnkerpunkt;
    DateiIsolator:string;
    Drahtstaerke:single;
    Drahtkennzahl :integer;


procedure RegistryLesen;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\Ezs1007') then
            begin
              if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
              if reg.ValueExists('DrahtStaerke') then
              begin
                Drahtkennzahl:=reg.ReadInteger('DrahtStaerke');
                case Drahtkennzahl of
                0: Drahtstaerke := 0.015;  // Zusi Legacy-Drahtstärke
                1: Drahtstaerke := 0.006;  // Draht Ri 100
                end;
              end;
            end;
  finally
    reg.Free;
  end;
end;



procedure RegistrySchreiben;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
    if reg.OpenKey('Software', False) then
    begin
      if reg.OpenKey('Zusi3', true)  then
      begin
        if reg.OpenKey('lib', true) then
        begin
          if reg.OpenKey('catenary', true) then
          begin
            if reg.OpenKey('Ezs1007', true) then
            begin
              reg.WriteString('DateiIsolator', DateiIsolator);
              reg.WriteInteger('Drahtstaerke',Drahtkennzahl);
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
  Drahtkennzahl:=1;
  Drahtstaerke:=0.006;
  RegistryLesen;
end;

function BauartTyp(i:Longint):PChar; stdcall;
// Wird vom Editor so oft aufgerufen, wie wir als Result in der init-function übergeben haben. Enumeriert die Bauart-Typen, die diese DLL kennt 
begin
  case i of
  0: Result:='Ezs 1007 am Ausleger';
  1: Result:='Abschluß mit Isolator';
  else Result := 'Ezs 1007 am Ausleger'
  end;
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
  var iOben0, iUnten0, iOben2, iUnten2:integer;
      b:integer;
  begin
    Result:=-1;
    iOben0:=0;
    iUnten0:=0;
    iOben2:=0;
    iUnten2:=0;

    //liegt ein Spannpunkt vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAbspannungMastpunktFahrdraht then Result:=1;
    end;

    //liegt ein Standard-Ausleger vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungFahrdraht then inc(iUnten2);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungTragseil then inc(iOben2);
    end;
    if (iUnten2=1) and (iOben2=1) then Result:=0;


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

procedure Ezs1007AmAuslegerAufAbschlussMitIsolator;
var pktFA, pktFB, pktTA, pktTB, pktU :TAnkerpunkt;
    vFahrdraht, v, vNorm:TD3DVector;
    DrahtFarbe:TD3DColorValue;
begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    //Fahrdraht berechnen als Vektor von FA nach FB
    pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungFahrdraht);
    pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungTragseil);
    pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAbspannungMastpunktTragseil);


    //Tragseil am Ausleger A
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, 5);    //Tragseil von 5 m Länge am Ausleger A
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
{
    //Stützrohrhänger Ausleger A
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
}

    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;


    //Isolator an der Ausfädelung unten
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, 2, pktU.PunktTransformiert.Punkt, pktU.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

  end
end;

procedure Ezs1007AmAusleger;
var pktFA, pktFB, pktTA, pktTB, pktU :TAnkerpunkt;
    vFahrdraht, vTragseil, v, vNorm:TD3DVector;
    DrahtFarbe:TD3DColorValue;
begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    //Fahrdraht berechnen als Vektor von FA nach FB
    pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungFahrdraht);
    pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungTragseil);
    pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);


    //Tragseil am Ausleger A
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, 5);    //Tragseil von 5 m Länge am Ausleger A
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
{
    //Stützrohrhänger Ausleger A
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Stützrohrhänger Ausleger B
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
}
    //Tragseil am Ausleger B
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, -5);    //Tragseil von 5 m Länge am Ausleger B
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt, v);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;


    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

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
  //Das Radspannwerk muss immer an A liegen. Ggfs. wird es deshalb passend hingedreht.
  if (Typ1=0) and (Typ2=1) then Ezs1007AmAuslegerAufAbschlussMitIsolator;
  if (Typ1=1) and (Typ2=0) then
  begin //Arrays durchtauschen, da die Bau-Procedure nicht seitenneutral ist
    PunkteTemp:=PunkteA;
    PunkteA:=PunkteB;
    PunkteB:=PunkteTemp;
    Ezs1007AmAuslegerAufAbschlussMitIsolator;
  end;

  if (Typ1=0) and (Typ2=0) then Ezs1007AmAusleger;

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
  Result:='Ezs 1007'
end;

function Drahthoehe:single; stdcall;
// wir machen derzeit keine Drahthöhenberechnung für den Automatikmodus und
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
var Formular:TFormEzs1007Config;
begin
  Application.Handle:=AppHandle;
  Formular:=TFormEzs1007Config.Create(Application);
  Formular.LabeledEditIsolator.Text:=DateiIsolator;
  Formular.RadioGroupDrahtstaerke.ItemIndex := Drahtkennzahl;

  Formular.ShowModal;

  if Formular.ModalResult=mrOK then
  begin
    DateiIsolator:=(Formular.LabeledEditIsolator.Text);
    Drahtkennzahl:=Formular.RadioGroupDrahtstaerke.ItemIndex;
    RegistrySchreiben;
    RegistryLesen;
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
