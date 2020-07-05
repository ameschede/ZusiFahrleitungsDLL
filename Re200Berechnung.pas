unit Re200Berechnung;

interface

uses
  Direct3D9, d3dx9, 
  
  sysutils, Controls, registry, windows, forms, Math, Dialogs,
  
  ZusiD3DTypenDll, FahrleitungsTypen, Re200ConfigForm;

type

  TEndstueck = (y24m, y18m, y14m, y12m, y24mZ, y18mZ, y14mZ, y12mZ, ausfaedel, Festp, FestpIso, Abschluss, SH13, SH03);

function Init:Longword; stdcall;
function BauartTyp(i:Longint):PChar; stdcall;
function Fahrleitungstyp:TFahrleitungstyp; stdcall;
procedure Systemversatz(s:single); stdcall;
procedure Reset(A:Boolean); stdcall;
procedure NeuerPunkt(A:Boolean; Punkt:TAnkerpunkt); stdcall;
function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
procedure Berechne_YSeil_18m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY:TAnkerpunkt; Abstand,Richtung: single);
procedure Berechne_YSeil_14m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY:TAnkerpunkt; Abstand,Richtung: single);
procedure Berechne_YSeil_24m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY:TAnkerpunkt; Abstand,Richtung: single);
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
    PunkteA, PunkteB, PunkteTemp: array of TAnkerpunkt;
    DateiIsolator:string;
    Drahtstaerke:single;
    Drahtkennzahl,Festpunktisolatorposition:integer;
    DrahtFarbe:TD3DColorValue;
    BaufunktionAufgerufen:boolean;

procedure RegistryLesen;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\Re200') then
            begin
              if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
              if reg.ValueExists('Festpunktisolatorposition') then Festpunktisolatorposition := reg.ReadInteger('Festpunktisolatorposition');
              if reg.ValueExists('DrahtStaerke') then
              begin
                Drahtkennzahl:=reg.ReadInteger('DrahtStaerke');
                case Drahtkennzahl of
                0: Drahtstaerke := 0.006;   // Draht Ri 100
                1: Drahtstaerke := 0.015;   // Zusis Legacy-Drahtstärke
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
            if reg.OpenKey('Re200', true) then
            begin
              reg.WriteString('DateiIsolator', DateiIsolator);
              reg.WriteInteger('Drahtstaerke',Drahtkennzahl);
              reg.WriteInteger('Festpunktisolatorposition',Festpunktisolatorposition);
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
  Result:=10;  //muss passen zu den möglichen Rückgabewerten der function BauartTyp
  Reset(true);
  Reset(false);
  DateiIsolator:='Catenary\Deutschland\Einzelteile_Re75-200\Isolator.lod.ls3';
  Drahtkennzahl:=0;
  Festpunktisolatorposition:=10;
  Drahtstaerke:=0.006;
  RegistryLesen;
end;

function BauartTyp(i:Longint):PChar; stdcall;
// Wird vom Editor so oft aufgerufen, wie wir als Result in der init-function übergeben haben. Enumeriert die Bauart-Typen, die diese DLL kennt 
begin
  case i of
  0: Result:='(K) 18m Y-Seil';
  1: Result:='(L) 14m Y-Seil';
  2: Result:='Festpunktabspannung';
  3: Result:='Festpunktabspannung mit Isolator';
  4: Result:='(K) Festpunkt mit 18m Y-Seil';
  5: Result:='(L) Festpunkt mit 14m Y-Seil';
  6: Result:='Ausfädelung';
  7: Result:='Abschluss mit Isolatoren';
  8: Result:='(QTW freie Strecke) 24m Y-Seil';
  9: Result:='(QTW fr. Strecke) Festpunkt mit 24m Y-Seil';
  10: Result:='(Tunnel SH 11) 12m Y-Seil';
  11: Result:='Stützpunkt SH < 13';
  12: Result:='(SH 03) Stützpunkt unter Bauwerk'
  else Result := '(K) 18m Y-Seil'
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
  var iOben0, iUnten0, iOben1, iUnten1, iOben2, iUnten2:integer;
      b:integer;
  begin
    Result:=-1;
    iOben0:=0;
    iUnten0:=0;
    iOben1:=0;
    iUnten1:=0;
    iOben2:=0;
    iUnten2:=0;

    //liegt ein Spannpunkt vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAbspannungMastpunktFahrdraht then inc(iUnten0);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAbspannungMastpunktTragseil then inc(iOben0);
    end;
    if (iUnten0=1) and (iOben0=1) then Result:=7;

    //liegt ein Ausfädelungs-Ausleger vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungFahrdraht then inc(iUnten1);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungTragseil then inc(iOben1);
    end;
    if (iUnten1=1) and (iOben1=1) then Result:=6;

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
    LeerAnker:TAnkerpunkt;
begin
  //Result-Variable zumindest so weit initialisieren, dass sie ggfs. von AnkerIstLeer erkannt werden kann
  LeerAnker.PunktTransformiert.Punkt.x :=0;
  LeerAnker.PunktTransformiert.Punkt.y :=0;
  LeerAnker.PunktTransformiert.Punkt.z :=0;
  Result := LeerAnker;
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

procedure KettenwerkMitYSeil(EndstueckA,EndstueckB:TEndstueck;zSeil:boolean);
var pktFA, pktFB, pktTA, pktTB, pktYA, pktYB, pktU, pktO:TAnkerpunkt;
    Abstand, Durchhang, {LaengeNormalhaengerbereich,} Ersthaengerabstand, Letzthaengerabstand, Haengerabstand, AbstandFT, DurchhangNahhaenger, DurchhangFernhaenger:single;
    vFahrdraht, vTragseil, v, vNeu, vNorm, ErstNormalhaengerpunkt, LetztNormalhaengerpunkt:TD3DVector;
    i, a:integer;

begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    BaufunktionAufgerufen := true;
    if EndstueckA = y18m then Ersthaengerabstand := 6;
    if EndstueckB = y18m then Letzthaengerabstand := 6;
    if EndstueckA = y14m then Ersthaengerabstand := 2.5;
    if EndstueckB = y14m then Letzthaengerabstand := 2.5;
    if EndstueckA = y24m then Ersthaengerabstand := 7;
    if EndstueckB = y24m then Letzthaengerabstand := 7;
    if EndstueckA = Ausfaedel then Ersthaengerabstand := 0;
    if EndstueckB = Ausfaedel then Letzthaengerabstand := 0;

    pktYA:=PunktSuchen(true, 0, Ankertyp_FahrleitungHaengerseil);
    pktYB:=PunktSuchen(false, 0, Ankertyp_FahrleitungHaengerseil);

    //Fahrdraht berechnen als Vektor von FA nach FB
    pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungFahrdraht);
    if Letzthaengerabstand = 0 then pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAusfaedelungFahrdraht)
    else pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);
    if (Abstand < 34) or (Abstand > 80) then ShowMessage(floattostr(Math.RoundTo(Abstand,-2)) + ' m Längsspannweite liegt außerhalb der zulässigen Grenzen der Bauart Re 200 (34 bis 80 m)');

    {
     Vorbildgerechte Hängerteilung Re 200:
     Stützpunkt K: 1. Hänger 2,5 m vom Stützpunkt; 2. Hänger 6,0 m vom Stützpunkt;
     Stützpunkt L: 1. Hänger 2,5 m vom Stützpunkt;
     sonst maximal 11,50 m;
    }
    i:=Math.Ceil((Abstand - Ersthaengerabstand - Letzthaengerabstand)/11.5) - 1;
    if odd(i) then i :=i+1; //ungerade Anzahl Normalhänger ist in Re 200 nicht zulässig. Deshalb im Zweifel einen Hänger mehr einbauen.
    //LaengeNormalhaengerbereich := (Abstand - Ersthaengerabstand - Letzthaengerabstand);
    Haengerabstand := (Abstand - Ersthaengerabstand - Letzthaengerabstand)/(i+1);
    //ShowMessage( 'Anzahl Hänger '+inttostr(i) + '   Hängerabstand ' + floattostr(Haengerabstand) + '   Längsspannweite ' + floattostr(Abstand) + '   Normalhängerbereich ' + floattostr(LaengeNormalhaengerbereich));

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungTragseil);
    if Letzthaengerabstand = 0 then pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAusfaedelungTragseil)
    else pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);

    //Systemhöhen-Prüfung
    D3DXVec3Subtract(v, pktTA.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    if (D3DXVec3Length(v) < 1.3) then ShowMessage('Systemhöhe am Ausleger A liegt außerhalb der zulässigen Grenzen dieser DLL (minimal 1,30 m).');
    D3DXVec3Subtract(v, pktTB.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt);
    if (D3DXVec3Length(v) < 1.3) then ShowMessage('Systemhöhe am Ausleger B liegt außerhalb der zulässigen Grenzen dieser DLL (minimal 1,30 m).');


    //Normalhänger
    for a:=1 to i do
    begin
      //unterer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (a * Haengerabstand)));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Ersthaengerabstand + (a * Haengerabstand));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      Durchhang := (0.00076 * sqr(Ersthaengerabstand + (a * Haengerabstand) - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      if a = 1 then
      begin
      //oberen Punkt des ersten Hängers für spätere Verwendung speichern
      ErstNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
      if a = (i) then
      begin
      //oberen Punkt des letzten Hängers für spätere Verwendung speichern
      LetztNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
      if (a = (i/2)) and zSeil then
      begin
        //Abstand zwischen Fahrdraht und Tragseil sowie Durchhang für  spätere Verwendung speichern
        D3DXVec3Subtract(v, pktU.PunktTransformiert.Punkt, pktO.PunktTransformiert.Punkt);
        AbstandFT:=D3DXVec3Length(v);
        DurchhangNahhaenger := Durchhang;
      end;
      if (a = (i/2) + 1) and zSeil then
      begin
        //Durchhang für  spätere Verwendung speichern
        DurchhangFernhaenger := Durchhang;
      end;
    end;


    // Tragseil-Abschnitte zwischen den Hängern
    for a:=1 to length(ErgebnisArray)-1 do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErgebnisArray[a-1].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[a].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;


    //Y-Seile
    if EndstueckA = y18m then Berechne_YSeil_18m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,pktYA,Abstand,1);
    if EndstueckB = y18m then Berechne_YSeil_18m(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,pktYB,Abstand,-1);
    if EndstueckA = y14m then Berechne_YSeil_14m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,pktYA,Abstand,1);
    if EndstueckB = y14m then Berechne_YSeil_14m(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,pktYB,Abstand,-1);
    if EndstueckA = y24m then Berechne_YSeil_24m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,pktYA,Abstand,1);
    if EndstueckB = y24m then Berechne_YSeil_24m(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,pktYB,Abstand,-1);
    if EndstueckB = Ausfaedel then
    begin
      //Verbindung zwischen letztem Normalhänger und Ausleger B
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=LetztNormalhaengerpunkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTB.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Z-Seil
    if zSeil then
    begin
      //unterer vorläufiger z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + ((i/2) * Haengerabstand) + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Ersthaengerabstand + ((i/2) * Haengerabstand + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      //Durchhang := (0.00076 * sqr(Ersthaengerabstand + ((i/2) * Haengerabstand + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2) - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0); //Bei dieser Rechenmethode ergibt sich eine leichte Unexaktheit, da wir hier einen etwas anderen Durchhangwert ermitteln als beim Bau der nächstliegenden Normalhänger
      Durchhang := (0.67 * DurchhangNahhaenger + 0.33 * DurchhangFernhaenger); //gewichteter Durchschnitt des Durchhangs der beiden benachbarten Hänger
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      //endgültiger unterer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + ((i/2) * Haengerabstand) + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2) + (sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))); //Länge des z-Seils muss das Fünffache des Abstands zwischen Fahrdraht und Tragseil sein
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

  end;
end;

procedure Berechne_YSeil_18m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY:TAnkerpunkt; Abstand,Richtung:single);
var pktU, pktO:TAnkerpunkt;
    v, vNorm, vNeu, YSeilErsthaengerpunkt,YseilZweithaengerpunkt,YSeilEndepunkt: TD3DVector;
    Durchhang:single;
begin
    //Erster Hänger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 2.5);    //erster Hänger in 2,5 m Abstand vom Ausleger
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 2.5);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 0.53); //Hänger auf 53% Höhe zwischen Fahrdraht und Tragseil (lt. Ezs 2521)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilErsthaengerpunkt := pktO.PunktTransformiert.Punkt;
    //Array[0]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Zweiter Hänger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 6);    //zweiter Hänger in 6.0 m Abstand vom Ausleger
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 6);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 0.67); //Hänger auf 67% Höhe zwischen Fahrdraht und Tragseil  (lt. Ezs 2521)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilZweithaengerpunkt := pktO.PunktTransformiert.Punkt;
    //Array[1]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung im Y-Seil zwischen Erst- und Zweithänger
    //Array[2]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilErsthaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=YSeilZweithaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung im Y-Seil zwischen Ersthänger und Nullpunkt am Ausleger
    //oberer Kettenwerkpunkt
    //Punkt absenken
    D3DXVec3Subtract(v, pktT.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 0.47); //47% Höhe zwischen Fahrdraht und Tragseil (lt. Ezs 2521)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, vNeu);
    //Array[3]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilErsthaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Anbindung Y-Seil an den Ausleger, unter Nutzung des für Array[3] berechneten Punkts
    //Array[4]
    if not AnkerIstLeer(pktY) then
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktY.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Tragseil zwischen Ende Y-Seil und Ausleger
    //unterer Kettenwerkpunkt (nur virtuell, für Berechnungszwecke)
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 9);
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 9);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr(9 - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilEndepunkt := pktO.PunktTransformiert.Punkt;
    //Array[5]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktT.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung zwischen Ende Y-Seil und Zweithänger
    //Array[6]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilZweithaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ende Y-Seil und erstem Normalhänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilEndepunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

end;

procedure Berechne_YSeil_14m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY:TAnkerpunkt; Abstand,Richtung:single);
var pktU, pktO:TAnkerpunkt;
    v, vNorm, vNeu, YSeilErsthaengerpunkt,YSeilEndepunkt: TD3DVector;
    Durchhang:single;
begin
    //Erster Hänger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 2.5);    //erster Hänger in 2,5 m Abstand vom Ausleger
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 2.5);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 0.53); //Hänger auf 53% Höhe zwischen Fahrdraht und Tragseil (lt. Ezs 2521)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilErsthaengerpunkt := pktO.PunktTransformiert.Punkt;
    //Array[0]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung im Y-Seil zwischen Ersthänger und Nullpunkt am Ausleger
    //oberer Kettenwerkpunkt
    //Punkt absenken
    D3DXVec3Subtract(v, pktT.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 0.47); //47% Höhe zwischen Fahrdraht und Tragseil (lt. Ezs 2521)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, vNeu);
    //Array[3]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilErsthaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Anbindung Y-Seil an den Ausleger, unter Nutzung des für Array[3] berechneten Punkts
    //Array[4]
    if not AnkerIstLeer(pktY) then
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktY.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Tragseil zwischen Ende Y-Seil und Ausleger
    //unterer Kettenwerkpunkt (nur virtuell, für Berechnungszwecke)
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 7);
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 7);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr(7 - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilEndepunkt := pktO.PunktTransformiert.Punkt;
    //Array[5]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktT.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung zwischen Ende Y-Seil und Ersthänger
    //Array[6]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilErsthaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ende Y-Seil und erstem Normalhänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilEndepunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

end;

procedure Berechne_YSeil_24m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY:TAnkerpunkt; Abstand,Richtung:single);
var pktU, pktO:TAnkerpunkt;
    v, vNorm, vNeu, YSeilErsthaengerpunkt,YSeilEndepunkt: TD3DVector;
    Durchhang:single;
    mr:cardinal;
begin
    //Erster Hänger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 7);    //erster Hänger in 7,0 m Abstand vom Ausleger
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 7);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 0.53); //Hänger auf 53% Höhe zwischen Fahrdraht und Tragseil (lt. Ezs 2521)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilErsthaengerpunkt := pktO.PunktTransformiert.Punkt;
    //Array[0]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung im Y-Seil zwischen Ersthänger und Nullpunkt am Ausleger
    //oberer Kettenwerkpunkt
    //Punkt absenken
    D3DXVec3Subtract(v, pktT.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 0.47); //47% Höhe zwischen Fahrdraht und Tragseil (lt. Ezs 2521)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, vNeu);
    //Array[3]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilErsthaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    mr := MessageDlg('Zusätzlichen Hänger einbauen (liegt in Hauptfahrrichtung 1 m vor dem Quertragwerk)?',mtConfirmation,[mbYes,mbNo],0);
    if mr = IDYES then
    begin
      //unterer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, Richtung * 1);    //1,0 m Abstand vom Ausleger
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

      //oberer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Richtung * 1);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

      //Punkt absenken
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, 0.48); //magische Zahl, empirisch ermittelt ;-)
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Tragseil zwischen Ende Y-Seil und Ausleger
    //unterer Kettenwerkpunkt (nur virtuell, für Berechnungszwecke)
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 12);
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 12);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr(12 - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilEndepunkt := pktO.PunktTransformiert.Punkt;
    //Array[5]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktT.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung zwischen Ende Y-Seil und Ersthänger
    //Array[6]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilErsthaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ende Y-Seil und erstem Normalhänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilEndepunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

end;

procedure Festpunktabspannung;
var pktDA, pktDB:TAnkerpunkt;
    vDraht:TD3DVector;
begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    BaufunktionAufgerufen := true;
    //Draht berechnen als Vektor von DA nach DB
    pktDA:=PunktSuchen(true,  0, Ankertyp_FahrleitungTragseil);
    pktDB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAnbaupunktAnker);
    D3DXVec3Subtract(vDraht, pktDB.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Punkt);

    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktDA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktDB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=0.0045; //Bronzeseil 50/7, abweichend von der Standard-Drahtstärke der DLL
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Isolator auf dem Festpunktseil
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktDB.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Punkt, (Festpunktisolatorposition * D3DXVec3Length(vDraht))/100, pktDA.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktDA.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktDA.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

  end
end;

procedure KettenwerkAbschluss(Ersthaengerabstand,Letzthaengerabstand:single);
var pktFA, pktFB, pktTA, pktTB, pktU, pktO:TAnkerpunkt;
    Abstand, Durchhang, LaengeNormalhaengerbereich, Haengerabstand:single;
    vFahrdraht, vTragseil, v, vNeu, vNorm, ErstNormalhaengerpunkt, LetztNormalhaengerpunkt:TD3DVector;
    i, a:integer;

begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    BaufunktionAufgerufen := true;
    //Fahrdraht berechnen als Vektor von FA nach FB
    pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungAusfaedelungFahrdraht);
    pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);

    i:=Math.Ceil((Abstand - Ersthaengerabstand - Letzthaengerabstand)/11.5); //Anders als bei Normalkettenwerk soll hier der letzte Hänger von der Normalhänger-Schleife gebaut werden
    if odd(i) then i :=i+1; //ungerade Anzahl Normalhänger ist in Re 200 nicht zulässig. Deshalb im Zweifel einen Hänger mehr einbauen.
    LaengeNormalhaengerbereich := (Abstand - Ersthaengerabstand - Letzthaengerabstand);
    Haengerabstand := (Abstand - Ersthaengerabstand - Letzthaengerabstand)/i; //Anders als bei Normalkettenwerk soll hier der letzte Hänger von der Normalhänger-Schleife gebaut werden
    ShowMessage( 'Anzahl Hänger '+inttostr(i) + '   Hängerabstand ' + floattostr(Haengerabstand) + '   Längsspannweite ' + floattostr(Abstand) + '   Normalhängerbereich ' + floattostr(LaengeNormalhaengerbereich));

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungAusfaedelungTragseil);
    pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAbspannungMastpunktTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);


    //Normalhänger
    for a:=1 to i do
    begin
      //unterer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (a * Haengerabstand)));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Ersthaengerabstand + (a * Haengerabstand));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      Durchhang := (0.00076 * sqr(Ersthaengerabstand + (a * Haengerabstand) - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      if a = 1 then
      begin
      //oberen Punkt des ersten Hängers für spätere Verwendung speichern
      ErstNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
      if a = (i) then
      begin
      //oberen Punkt des letzten Hängers für spätere Verwendung speichern
      LetztNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
    end;


    // Tragseil-Abschnitte zwischen den Hängern
    for a:=1 to length(ErgebnisArray)-1 do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErgebnisArray[a-1].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[a].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      //v:=ErgebnisArray[a].Punkt2;
    end;

    //Verbindung zwischen letztem Normalhänger und Spannwerk an B
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Isolator am Spannwerk oben
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktTB.PunktTransformiert.Punkt, pktO.PunktTransformiert.Punkt, 2, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //Isolator am Spannwerk unten
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, 2, pktU.PunktTransformiert.Punkt, pktU.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);


    //erster  Hänger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Ersthaengerabstand);
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Ersthaengerabstand);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr(Ersthaengerabstand - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung zwischen erstem Hänger und erstem Normalhänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung zwischen erstem Hänger und Ausleger A
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;


    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

  end;
end;

procedure BaurichtungWechseln;
begin
  PunkteTemp:=PunkteA;
  PunkteA:=PunkteB;
  PunkteB:=PunkteTemp;
end;

function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
// Der Benutzer hat auf 'Ausführen' geklickt.
// Rückgabe: Anzahl der Linien
var BautypA, BautypB : TEndstueck;

begin
  //zunächst nochmal Grundzustand herstellen
  setlength(ErgebnisArray, 0);
  setlength(ErgebnisArrayDateien, 0);
  BaufunktionAufgerufen := false;

  //Übersetzung zwischen den von Zusi übergebenen Longints und unseren Bautypen
  case Typ1 of
    0: BautypA := y18m;
    1: BautypA := y14m;
    2: BautypA := Festp;
    3: BautypA := FestpIso;
    4: BautypA := y18mZ;
    5: BautypA := y14mZ;
    6: BautypA := Ausfaedel;
    7: BautypA := Abschluss;
    8: BautypA := y24m;
    9: BautypA := y24mZ;
    10: BautypA := y12m;
    11: BautypA := SH13;
    12: BautypA := SH03
  end;
    case Typ2 of
    0: BautypB := y18m;
    1: BautypB := y14m;
    2: BautypB := Festp;
    3: BautypB := FestpIso;
    4: BautypB := y18mZ;
    5: BautypB := y14mZ;
    6: BautypB := Ausfaedel;
    7: BautypB := Abschluss;
    8: BautypB := y24m;
    9: BautypB := y24mZ;
    10: BautypB := y12m;
    11: BautypB := SH13;
    12: BautypB := SH03
  end;

  //wenn wir mehrere Sorten Fahrdrähte verlegen können, wird hier entschieden was wir machen
  if (BautypA=y18m) and (BautypB=y18m) then KettenwerkMitYSeil(y18m,y18m,false);      //beide Y-Seile Typ 18m
  if (BautypA=y14m) and (BautypB=y14m) then KettenwerkMitYSeil(y14m,y14m,false);      //beide Y-Seile Typ 14m
  if (BautypA=y24m) and (BautypB=y24m) then KettenwerkMitYSeil(y24m,y24m,false);      //beide Y-Seile Typ 24m
  if (BautypA=y18m) and (BautypB=y14m) then KettenwerkMitYSeil(y18m,y14m,false);      //Y-Seil 18m + 14m
  if (BautypA=y18m) and (BautypB=y24m) then KettenwerkMitYSeil(y18m,y24m,false);      //Y-Seil 18m + 24m
  if (BautypA=y14m) and (BautypB=y18m) then KettenwerkMitYSeil(y14m,y18m,false);      //Y-Seil 14m + 18m
  if (BautypA=y14m) and (BautypB=y24m) then KettenwerkMitYSeil(y14m,y24m,false);      //Y-Seil 14m + 24m
  if (BautypA=y24m) and (BautypB=y18m) then KettenwerkMitYSeil(y24m,y18m,false);      //Y-Seil 24m + 18m
  if (BautypA=y24m) and (BautypB=y14m) then KettenwerkMitYSeil(y24m,y14m,false);      //Y-Seil 24m + 14m
  if (BautypA=Festp) and (BautypB=FestpIso) then Festpunktabspannung;
  if (BautypA=FestpIso) and (BautypB=Festp) then
  begin //Arrays durchtauschen, da die Bau-Procedure nicht seitenneutral ist
    BaurichtungWechseln;
    Festpunktabspannung;
  end;
  if (BautypA=y18mZ) and (BautypB=y18m) then KettenwerkMitYSeil(y18m,y18m,true);      //beide Y-Seile Typ 18m, z-Seil an A
  if (BautypA=y18m) and (BautypB=y18mZ) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei z-Seil nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkMitYSeil(y18m,y18m,true)
  end;
  if (BautypA=y18mZ) and (BautypB=y14m) then KettenwerkMitYSeil(y18m,y14m,true);      //Y-Seil 18m + 14m, z-Seil an A
  if (BautypA=y14m) and (BautypB=y18mZ) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei z-Seil nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkMitYSeil(y18m,y14m,true)
  end;
  if (BautypA=y14mZ) and (BautypB=y18m) then KettenwerkMitYSeil(y14m,y18m,true);      //Y-Seil 14m + 18m, z-Seil an A
  if (BautypA=y18m) and (BautypB=y14mZ) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei z-Seil nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkMitYSeil(y14m,y18m,true)
  end;
  if (BautypA=y14mZ) and (BautypB=y14m) then KettenwerkMitYSeil(y14m,y14m,true);      //beide Y-Seile Typ 14m, z-Seil an A
  if (BautypA=y14m) and (BautypB=y14mZ) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei z-Seil nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkMitYSeil(y14m,y14m,true)
  end;
  if (BautypA=y24mZ) and (BautypB=y24m) then KettenwerkMitYSeil(y14m,y14m,true);      //beide Y-Seile Typ 24m, z-Seil an A
  if (BautypA=y24m) and (BautypB=y24mZ) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei z-Seil nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkMitYSeil(y24m,y24m,true)
  end;
  if (BautypA=Ausfaedel) and (BautypB=Abschluss) then KettenwerkAbschluss(0.5,22.8);      //Ausfädelung an A, Isolatoren an B; Letzthängerabstand 22,8 m wegen 20 m hängerfreiem Seil, 0,8 m Isolatorlänge und 2,0 m Abstand Isolator zu Spannwerk
  if (BautypA=Abschluss) and (BautypB=Ausfaedel) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei Abschlüssen nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkAbschluss(0.5,22.8);
  end;
  if (BautypA=y18m) and (BautypB=Ausfaedel) then KettenwerkMitYSeil(y18m,Ausfaedel,false);  //Y-Seil 18m auf Ausfädelung
  if (BautypA=Ausfaedel) and (BautypB=y18m) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei z-Seil nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkMitYSeil(y18m,Ausfaedel,false)
  end;
  if (BautypA=y14m) and (BautypB=Ausfaedel) then KettenwerkMitYSeil(y14m,Ausfaedel,false);  //Y-Seil 14m auf Ausfädelung
  if (BautypA=Ausfaedel) and (BautypB=y14m) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei z-Seil nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkMitYSeil(y14m,Ausfaedel,false)
  end;
  if (BautypA=y24m) and (BautypB=Ausfaedel) then KettenwerkMitYSeil(y24m,Ausfaedel,false);  //Y-Seil 24m auf Ausfädelung
  if (BautypA=Ausfaedel) and (BautypB=y24m) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei z-Seil nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkMitYSeil(y24m,Ausfaedel,false)
  end;

  if BaufunktionAufgerufen = false then ShowMessage('Die gewählte Bauart-Kombination ist nicht implementiert. Bei tatsächlichem Bedarf bitte beim Autor der DLL melden.');

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
  Result:='Re 200'
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
var Formular:TFormFahrleitungConfig;
begin
  Application.Handle:=AppHandle;
  Formular:=TFormFahrleitungConfig.Create(Application);
  Formular.LabeledEditIsolator.Text:=DateiIsolator;
  Formular.RadioGroupDrahtstaerke.ItemIndex := Drahtkennzahl;
  Formular.TrackBarFestpunktisolator.Position := Festpunktisolatorposition;

  Formular.ShowModal;

  if Formular.ModalResult=mrOK then
  begin
    DateiIsolator:=(Formular.LabeledEditIsolator.Text);
    Drahtkennzahl:=Formular.RadioGroupDrahtstaerke.ItemIndex;
    Festpunktisolatorposition := Formular.TrackBarFestpunktisolator.Position;
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
