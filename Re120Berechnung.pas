unit Re120Berechnung;

{$MODE Delphi}

interface

uses
  Direct3D9, D3DX9,

  sysutils, Controls, registry, windows, forms, Math, Dialogs, interfaces, LConvEncoding,
  
  ZusiD3DTypenDll, FahrleitungsTypen, OLADLLgemeinsameFkt, Re120ConfigForm;

type

  TEndstueck = (y6m, y6mZ, ausfaedel, Festp, FestpIso, Abschluss);

function Init:Longword; stdcall;
function BauartTyp(i:Longint):PChar; stdcall;
function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
procedure Berechne_YSeil_6m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT:TAnkerpunkt; Abstand,Richtung: single);
function Bezeichnung:PChar; stdcall;
function Gruppe:PChar; stdcall;
procedure Config(AppHandle:HWND); stdcall;

implementation

exports
       AnkerImportDatei,
       Autor,
       BauartTyp,
       BauartVorschlagen,
       Berechnen,
       Bezeichnung,
       Config,
       dllVersion,
       Drahthoehe,
       ErgebnisDateien,
       ErgebnisDraht,
       Fahrleitungstyp,
       Gruppe,
       Init,
       Mastabstand,
       Maststandort,
       NeuerPunkt,
       Reset,
       Systemversatz;

var
    DateiIsolator:string;
    StaerkeFD,StaerkeTS,StaerkeHaenger,StaerkeStuetzrohrhaenger,StaerkeYseil,StaerkeBeiseil,StaerkeAnkerseil,StaerkeZseil,Helligkeit:single;
    Festpunktisolatorposition,IsolatorBaumodus:integer;
    DrahtFarbe:TD3DColorValue;
    BaufunktionAufgerufen,DialogOffen:boolean;

procedure RegistryLesen;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\Re120') then
            begin
              if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
              if reg.ValueExists('Festpunktisolatorposition') then Festpunktisolatorposition := reg.ReadInteger('Festpunktisolatorposition');
              if reg.ValueExists('IsolatorBaumodus') then IsolatorBaumodus := reg.ReadInteger('IsolatorBaumodus');
              if reg.ValueExists('Helligkeit') then Helligkeit := reg.ReadFloat('Helligkeit');
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
            if reg.OpenKey('Re120', true) then
            begin
              reg.WriteString('DateiIsolator', DateiIsolator);
              reg.WriteInteger('Festpunktisolatorposition',Festpunktisolatorposition);
              reg.WriteInteger('IsolatorBaumodus',IsolatorBaumodus);
              reg.WriteFloat('Helligkeit',Helligkeit);
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
  Result:=7;  //muss passen zu den möglichen Rückgabewerten der function BauartTyp
  Reset(true);
  Reset(false);
  DateiIsolator:='Catenary\Deutschland\Einzelteile_Re75-200\Isolator.lod.ls3';
  Festpunktisolatorposition:=10;
  StaerkeFD := 0.006;
  StaerkeTS := 0.0045;
  StaerkeHaenger := 0.00225;
  StaerkeStuetzrohrhaenger := 0.0031;
  StaerkeYseil := 0.00315;
  StaerkeBeiseil := 0.0045;
  StaerkeAnkerseil := 0.0045;
  StaerkeZseil := 0.0045;
  IsolatorBaumodus := 0;
  Helligkeit := 0;
  RegistryLesen;
end;

function BauartTyp(i:Longint):PChar; stdcall;
// Wird vom Editor so oft aufgerufen, wie wir als Result in der init-function übergeben haben. Enumeriert die Bauart-Typen, die diese DLL kennt 
begin
  case i of
  0: Result:='6m Y-Seil';
  1: Result:='Festpunktabspannung';
  2: Result:='Festpunktabspannung mit Isolator';
  3: Result:='Festpunkt mit 6m Y-Seil';
  4: Result:='Ausfädelung';
  5: Result:='Abschluss mit Isolatoren';
  else Result := '6m Y-Seil'
  end;

  //Zusi 3.5 erwartet Codepage 1252 auf der DLL-Schnittstelle
  Result:=PChar(UTF8toCP1252(Result));
end;

function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
// Wir versuchen, aus der vom Editor übergebenen Ankerkonfiguration einen Bauarttypen vorzuschlagen
  function Vorschlagen(Punkte:array of TAnkerpunkt):Longint	;
  var iOben0, iUnten0, iOben1, iUnten1, iOben2, iUnten2, iOben3, iUnten3:integer;
      b:integer;
      pktF, pktT : TAnkerpunkt;
  begin
    Result:=-1;
    iOben0:=0;
    iUnten0:=0;
    iOben1:=0;
    iUnten1:=0;
    iOben2:=0;
    iUnten2:=0;
    iOben3:=0;
    iUnten3:=0;

    //liegt ein Spannpunkt vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAbspannungMastpunktFahrdraht then inc(iUnten0);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAbspannungMastpunktTragseil then inc(iOben0);
    end;
    if (iUnten0=1) and (iOben0=1) then Result:=5;

    //liegt ein Ausfädelungs-Ausleger vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungFahrdraht then inc(iUnten1);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungTragseil then inc(iOben1);
    end;
    if (iUnten1=1) and (iOben1=1) then Result:=4;

    //liegt ein Standard-Ausleger vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungFahrdraht then
        begin
          inc(iUnten2);
          pktF := Punkte[b];
        end;
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungTragseil then
        begin
          inc(iOben2);
          pktT := Punkte[b];
        end;
    end;
    if (iUnten2=1) and (iOben2=1) then
       Result := 0;

  end;

begin
    if A then Result:=Vorschlagen(PunkteA) else Result:=Vorschlagen(PunkteB);

end;

procedure Kettenwerk(EndstueckA,EndstueckB:TEndstueck);
var pktFA, pktFB, pktTA, pktTB, pktYA, pktYB, pktSRA, pktSRB, pktU, pktO:TAnkerpunkt;
    Abstand, Durchhang, Ersthaengerabstand, Letzthaengerabstand, Haengerabstand, AbstandFT, DurchhangAHaenger, DurchhangBHaenger:single;
    vFahrdraht, vTragseil, v, vNeu, vNorm, ErstNormalhaengerpunkt, LetztNormalhaengerpunkt:TD3DVector;
    i, a, zSeilHaenger:integer;
    zSeilA,zSeilB:boolean;

begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  zSeilA := false;
  zSeilB := false;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    BaufunktionAufgerufen := true;
    if EndstueckA in [y6m, y6mZ] then Ersthaengerabstand := 0.5;
    if EndstueckB in [y6m, y6mZ] then Letzthaengerabstand := -0.5;
    if EndstueckA = Ausfaedel then Ersthaengerabstand := 0;
    if EndstueckB = Ausfaedel then Letzthaengerabstand := 0;
    if EndstueckA in [Abschluss] then Ersthaengerabstand := 22.8;
    if EndstueckB in [Abschluss] then Letzthaengerabstand := 22.8;

    if EndstueckA in [y6mZ] then zSeilA := true;
    if EndstueckB in [y6mZ] then zSeilB := true;

    //Feststellen welcher Ankertyp am Fahrdraht zu erwarten ist
    if EndstueckA = Ausfaedel then pktFA:=PunktSuchen(true, 1, Ankertyp_FahrleitungAusfaedelungFahrdraht)
      else
      begin
      if EndstueckA = Abschluss then pktFA:=PunktSuchen(true, 1, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht)
        else pktFA:=PunktSuchen(true, 1, Ankertyp_FahrleitungFahrdraht);
      end;
    if EndstueckB = Ausfaedel then pktFB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAusfaedelungFahrdraht)
      else
      begin
      if EndstueckB = Abschluss then pktFB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht)
        else pktFB:=PunktSuchen(false, 1, Ankertyp_FahrleitungFahrdraht);
      end;
    //Fahrdraht berechnen als Vektor von FA nach FB
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);

    //Spannweite auf Plausibilität prüfen
    if (EndstueckA in [y6m,y6mZ]) and (EndstueckB in [y6m,y6mZ]) then
      begin
        //if (Abstand < 34) or (Abstand > 50.5) then ShowMessage(FormatFloat('0.00',Abstand) + ' m Längsspannweite liegt außerhalb der zulässigen Grenzen bei Stützpunkten im Tunnel (max. 50 m).'); //Aufgrund möglicher Ungenauigkeiten der Maststandorte in Zusi geben wir einen halben Meter Toleranz
      end;
    if not ((EndstueckA in [y6m,y6mZ]) or (EndstueckB in [y6m,y6mZ])) then
      begin
        if (Abstand < 34) or (Abstand > 80.5) then ShowMessage(FormatFloat('0.00',Abstand) + ' m Längsspannweite liegt außerhalb der zulässigen Grenzen der Bauart Re 160 (34 bis 80 m).'); //Aufgrund möglicher Ungenauigkeiten der Maststandorte in Zusi geben wir einen halben Meter Toleranz
      end;

    i:=Math.Ceil((Abstand - Ersthaengerabstand - Letzthaengerabstand)/13.0) - 1;    //max. Hängerabstand in der Bauart Re 120 ist 13,0 m

    Haengerabstand := (Abstand - Ersthaengerabstand - Letzthaengerabstand)/(i+1);
    //ShowMessage( 'Anzahl Hänger '+inttostr(i) + '   Hängerabstand ' + floattostr(Haengerabstand) + '   Längsspannweite ' + floattostr(Abstand) + '   Normalhängerbereich ' + floattostr(LaengeNormalhaengerbereich));

    //Feststellen welcher Ankertyp am Tragseil zu erwarten ist
    if EndstueckA = Ausfaedel then pktTA:=PunktSuchen(true, 1, Ankertyp_FahrleitungAusfaedelungTragseil)
      else
      begin
      if EndstueckA = Abschluss then pktTA:=PunktSuchen(true, 1, Ankertyp_FahrleitungAbspannungMastpunktTragseil)
        else pktTA:=PunktSuchen(true, 1, Ankertyp_FahrleitungTragseil);
      end;
    if EndstueckB = Ausfaedel then pktTB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAusfaedelungTragseil)
      else
      begin
      if EndstueckB = Abschluss then pktTB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAbspannungMastpunktTragseil)
        else pktTB:=PunktSuchen(false, 1, Ankertyp_FahrleitungTragseil);
      end;

    //Prüfung ob notwendige Ankerpunkte vorhanden sind
    if AnkerIstLeer(pktTA) or AnkerIstLeer(pktTB) or AnkerIstLeer(pktFA) or AnkerIstLeer(pktFB) then
    begin
         showmessage('Warnung: Ein notwendiger Fahrdraht-/Tragseil-Ankerpunkt wurde nicht erkannt. Der Fahrdraht kann nicht erzeugt werden.');
         exit; //Abbruch, weil Fahrdraht entarten würde
    end;

    //Tragseil Endpunkte
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);

    //Systemhöhen-Prüfung
    if not (EndstueckA in [Abschluss,Ausfaedel]) then
    begin
      D3DXVec3Subtract(v, pktTA.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
      if (D3DXVec3Length(v) < 1.3) then ShowMessage('Systemhöhe am Ausleger A liegt außerhalb der zulässigen Grenzen (minimal 1,30 m).');
    end;
    if not (EndstueckB in [Abschluss,Ausfaedel]) then
    begin
      D3DXVec3Subtract(v, pktTB.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt);
      if (D3DXVec3Length(v) < 1.3) then ShowMessage('Systemhöhe am Ausleger B liegt außerhalb der zulässigen Grenzen (minimal 1,30 m).');
    end;

    //falls ein Z-Seil gebraucht wird, dann ist es nach dem folgenden Hänger einzubauen:
    if (zSeilA) then
    begin
      case i of
        1: showmessage('Z-Seil kann von der DLL aufgrund zu geringer Längsspannweite nicht korrekt eingebaut werden. Bei tatsächlichem Bedarf bitte beim Autor der DLL melden.');
        2: zSeilHaenger := 1;
      else zSeilHaenger := 2;
      end;
    end;
    if (zSeilB) then
    begin
      case i of
        1: showmessage('Z-Seil kann von der DLL aufgrund zu geringer Längsspannweite nicht korrekt eingebaut werden. Bei tatsächlichem Bedarf bitte beim Autor der DLL melden.');
        2: zSeilHaenger := 1;
      else zSeilHaenger := i-2;
      end;
    end;

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

      DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeHaenger,DrahtFarbe,Helligkeit);

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
      if (a = zSeilHaenger) and (zSeilA or zSeilB) then
      begin
        //Abstand zwischen Fahrdraht und Tragseil sowie Durchhang für  spätere Verwendung speichern
        if zSeilA then
        begin
        D3DXVec3Subtract(v, pktU.PunktTransformiert.Punkt, pktO.PunktTransformiert.Punkt);
        AbstandFT:=D3DXVec3Length(v);
        end;
        DurchhangAHaenger := Durchhang;
      end;
      if (a = (zSeilHaenger + 1)) and (zSeilA or zSeilB) then
      begin
        //Abstand zwischen Fahrdraht und Tragseil sowie Durchhang für  spätere Verwendung speichern
        if zSeilB then
        begin
        D3DXVec3Subtract(v, pktU.PunktTransformiert.Punkt, pktO.PunktTransformiert.Punkt);
        AbstandFT:=D3DXVec3Length(v);
        end;
        DurchhangBHaenger := Durchhang;
      end;
    end;

    // Tragseil-Abschnitte zwischen den Hängern
    for a:=1 to length(ErgebnisArray)-1 do DrahtEintragen(ErgebnisArray[a-1].Punkt2,ErgebnisArray[a].Punkt2,StaerkeTS,DrahtFarbe,Helligkeit);

    //Falls es wegen sehr kurzer Spannweite keine Normalhänger gibt (nicht systemgemäß, kommt aber in der Realität vor) ist die Normalhängerschleife nicht durchgelaufen
    //In diesem Fall muss ein Erst- und Letztnormalhaengerpunkt synthetisiert werden
    if i = 0 then
    begin
      //unterer Kettenwerkpunkt Erstnormalhaenger
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm,Ersthaengerabstand);
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);
      //oberer Kettenwerkpunkt Erstnormalhaenger
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Ersthaengerabstand);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);
      //Punkt absenken
      Durchhang := (0.00076 * sqr(Ersthaengerabstand - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
      ErstNormalhaengerpunkt:=pktO.PunktTransformiert.Punkt;
      //unterer Kettenwerkpunkt Letztnormalhaenger
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm,(Abstand-Letzthaengerabstand));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);
      //oberer Kettenwerkpunkt Letztnormalhaenger
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, (Abstand-Letzthaengerabstand));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);
      //Punkt absenken
      Durchhang := (0.00076 * sqr((Abstand-Letzthaengerabstand) - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
      LetztNormalhaengerpunkt:=pktO.PunktTransformiert.Punkt;

      DrahtEintragen(ErstNormalhaengerpunkt,LetztNormalhaengerpunkt,StaerkeTS,DrahtFarbe,Helligkeit);
    end;

    //Y-Seile und Endstücke
    if EndstueckA in [y6m,y6mZ] then Berechne_YSeil_6m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,Abstand,1);
    if EndstueckB in [y6m,y6mZ] then Berechne_YSeil_6m(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,Abstand,-1);
    //Sonderbehandlung für Ausfädelungs-Endstücke (weil es dort offenbar keinen festen Ersthängerabstand gibt):
    if EndstueckA in [Ausfaedel,Abschluss] then
    begin
      //Verbindung zwischen erstem Normalhänger und Ausleger A
      DrahtEintragen(ErstNormalhaengerpunkt,pktTA.PunktTransformiert.Punkt,StaerkeTS,DrahtFarbe,Helligkeit);

      //ggfs. Isolatoren für Streckentrennung oder Spannwerk einbauen
      if (EndstueckA in [Abschluss]) or ((IsolatorBaumodus > 1) and (EndstueckA = Ausfaedel)) then
      begin
        setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
        LageIsolator(pktTA.PunktTransformiert.Punkt, ErstNormalhaengerpunkt, 2, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel);
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

        setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
        LageIsolator(pktFA.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt, 2, pktU.PunktTransformiert.Punkt, pktU.PunktTransformiert.Winkel);
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
      end;
    end;
    if EndstueckB in [Ausfaedel,Abschluss] then
    begin
      //Verbindung zwischen letztem Normalhänger und Ausleger B
      DrahtEintragen(LetztNormalhaengerpunkt,pktTB.PunktTransformiert.Punkt,StaerkeTS,DrahtFarbe,Helligkeit);

      //ggfs. Isolatoren für Streckentrennung oder Spannwerk einbauen
      if (EndstueckB in [Abschluss]) or ((IsolatorBaumodus > 1) and (EndstueckB = Ausfaedel)) then
      begin
        setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
        LageIsolator(pktTB.PunktTransformiert.Punkt, LetztNormalhaengerpunkt, 2, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel);
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

        setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
        LageIsolator(pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, 2, pktU.PunktTransformiert.Punkt, pktU.PunktTransformiert.Winkel);
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
      end;
    end;

    //bei geerdetem Ausfädelungs-Ausleger Isolator ins Tragseil einbauen
    if (EndstueckA in [Ausfaedel]) and ((IsolatorBaumodus = 1) or (IsolatorBaumodus = 3)) then
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktTA.PunktTransformiert.Punkt, ErstNormalhaengerpunkt, 0.6, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel); //geerdeter Ausleger - Isolator 0,6 m vom Stützpunkt entfernt
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
    end;
    if (EndstueckB in [Ausfaedel]) and ((IsolatorBaumodus = 1) or (IsolatorBaumodus = 3)) then
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktTB.PunktTransformiert.Punkt, LetztNormalhaengerpunkt, 0.6, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel); //geerdeter Ausleger - Isolator 0,6 m vom Stützpunkt entfernt
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
    end;

    //Z-Seil
    if zSeilA and (i > 1) then
    begin
      //unterer vorläufiger z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (zSeilHaenger * Haengerabstand) + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Ersthaengerabstand + (zSeilHaenger * Haengerabstand + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      //Durchhang := (0.00076 * sqr(Ersthaengerabstand + ((i/2) * Haengerabstand + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2) - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0); //Bei dieser Rechenmethode ergibt sich eine leichte Unexaktheit, da wir hier einen etwas anderen Durchhangwert ermitteln als beim Bau der nächstliegenden Normalhänger
      Durchhang := (0.67 * DurchhangAHaenger + 0.33 * DurchhangBHaenger); //gewichteter Durchschnitt des Durchhangs der beiden benachbarten Hänger
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      //endgültiger unterer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (zSeilHaenger * Haengerabstand) + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2) + (sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))); //Länge des z-Seils muss das Fünffache des Abstands zwischen Fahrdraht und Tragseil sein
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeZseil,DrahtFarbe,Helligkeit);
    end;
    if zSeilB and (i > 1) then
    begin
    //if odd(i) then i := i+1;
      //unterer vorläufiger z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + ((zSeilHaenger + 1) * Haengerabstand) - (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + ((zSeilHaenger + 1) * Haengerabstand) - (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      //Durchhang := (0.00076 * sqr(Ersthaengerabstand + ((i/2) * Haengerabstand + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2) - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0); //Bei dieser Rechenmethode ergibt sich eine leichte Unexaktheit, da wir hier einen etwas anderen Durchhangwert ermitteln als beim Bau der nächstliegenden Normalhänger
      Durchhang := (0.33 * DurchhangAHaenger + 0.67 * DurchhangBHaenger); //gewichteter Durchschnitt des Durchhangs der beiden benachbarten Hänger
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      //endgültiger unterer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (zSeilHaenger + 1) * Haengerabstand) - ((Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2 + sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))); //Länge des z-Seils muss das Fünffache des Abstands zwischen Fahrdraht und Tragseil sein
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeZseil,DrahtFarbe,Helligkeit);
    end;


    //Fahrdraht eintragen
    DrahtEintragen(pktFA.PunktTransformiert.Punkt,pktFB.PunktTransformiert.Punkt,StaerkeFD,DrahtFarbe,Helligkeit);
  end;
end;

procedure Berechne_YSeil_6m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT:TAnkerpunkt; Abstand,Richtung:single);
var pktU, pktO:TAnkerpunkt;
    v, vNorm, vNeu, YSeilErsthaengerpunkt,YSeilEndepunkt: TD3DVector;
    Durchhang:single;
begin
    //Erster Hänger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, abs(Richtung) * 0.5);    //erster Hänger in 0,5 m Abstand vom Ausleger, bei Ausleger B nur virtuell
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, abs(Richtung) * 0.5);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 0.82); //Hänger auf 82% Höhe zwischen Fahrdraht und Tragseil (lt. Ezs 486)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilErsthaengerpunkt := pktO.PunktTransformiert.Punkt;
    //Array[0]
    if Richtung = 1 then DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeHaenger,DrahtFarbe,Helligkeit); //Y-Hänger nur bauen wenn Ausleger A

    //Tragseil zwischen Ende Y-Seil und Ausleger
    //unterer Kettenwerkpunkt (nur virtuell, für Berechnungszwecke)
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 3); //3 Meter langes Seil bei Re 120
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 3);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr(3 - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilEndepunkt := pktO.PunktTransformiert.Punkt;
    //Array[5]
    DrahtEintragen(pktT.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeTS,DrahtFarbe,Helligkeit);

    //bei geerdetem Ausleger Isolator ins Tragseil einbauen
    if (IsolatorBaumodus = 1) or (IsolatorBaumodus = 3) then
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktT.PunktTransformiert.Punkt, YSeilEndepunkt, 0.6, pktT.PunktTransformiert.Punkt, pktT.PunktTransformiert.Winkel); //geerdeter Ausleger - Isolator 0,6 m vom Stützpunkt entfernt
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktT.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktT.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
    end;

    //Verbindung zwischen Ende Y-Seil und Ersthänger
    //Array[6]
    DrahtEintragen(YSeilErsthaengerpunkt,pktO.PunktTransformiert.Punkt,StaerkeYseil,DrahtFarbe,Helligkeit);

    //Tragseil zwischen Ende Y-Seil und erstem Normalhänger
    DrahtEintragen(YSeilEndepunkt,ErstNormalhaengerpunkt,StaerkeTS,DrahtFarbe,Helligkeit);
end;


procedure Festpunktabspannung;
var pktDA, pktDB:TAnkerpunkt;
    vDraht:TD3DVector;
begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>0) then
  begin
    BaufunktionAufgerufen := true;
    //Draht berechnen als Vektor von DA nach DB
    pktDA:=PunktSuchen(true, 1, Ankertyp_FahrleitungTragseil);
    pktDB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAnbaupunktAnker);
    D3DXVec3Subtract(vDraht, pktDB.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Punkt);

    //Prüfung ob notwendige Ankerpunkte vorhanden sind
    if AnkerIstLeer(pktDA) or AnkerIstLeer(pktDB) then
    begin
         showmessage('Warnung: Ein notwendiger Fahrdraht-/Tragseil-Ankerpunkt wurde nicht erkannt. Der Fahrdraht kann nicht erzeugt werden.');
         exit; //Abbruch, weil Fahrdraht entarten würde
    end;

    //Fahrdraht eintragen
    DrahtEintragen(pktDA.PunktTransformiert.Punkt,pktDB.PunktTransformiert.Punkt,StaerkeAnkerseil,DrahtFarbe,Helligkeit);

    //Isolator auf dem Festpunktseil
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktDB.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Punkt, (Festpunktisolatorposition * D3DXVec3Length(vDraht))/100, pktDA.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktDA.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktDA.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

  end
end;


procedure KettenwerkAbschluss(Ersthaengerabstand,Letzthaengerabstand:single;AnkommenderAnkertypF,AnkommenderAnkertypT:TAnkerTyp);
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
    pktFA:=PunktSuchen(true, 1, AnkommenderAnkertypF);
    pktFB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);

    i:=Math.Ceil((Abstand - Ersthaengerabstand - Letzthaengerabstand)/13.0); //Anders als bei Normalkettenwerk soll hier der letzte Hänger von der Normalhänger-Schleife gebaut werden
    //LaengeNormalhaengerbereich := (Abstand - Ersthaengerabstand - Letzthaengerabstand);
    Haengerabstand := (Abstand - Ersthaengerabstand - Letzthaengerabstand)/i; //Anders als bei Normalkettenwerk soll hier der letzte Hänger von der Normalhänger-Schleife gebaut werden
    //falls sich bei kurzer Spannweite ein unüblich kurzer Hängerabstand ergibt, keinen Hänger einbauen:
    if (i=1) and (Haengerabstand < 7) then
    begin
      i:=0;
      Haengerabstand := (Abstand - Ersthaengerabstand - Letzthaengerabstand);
    end;
    //ShowMessage( 'Anzahl Hänger '+inttostr(i) + '   Hängerabstand ' + floattostr(Haengerabstand) + '   Längsspannweite ' + floattostr(Abstand) + '   Normalhängerbereich ' + floattostr(LaengeNormalhaengerbereich));

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true, 1, AnkommenderAnkertypT);
    pktTB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAbspannungMastpunktTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);

    //Prüfung ob notwendige Ankerpunkte vorhanden sind
    if AnkerIstLeer(pktTA) or AnkerIstLeer(pktTB) or AnkerIstLeer(pktFA) or AnkerIstLeer(pktFB) then
    begin
         showmessage('Warnung: Ein notwendiger Fahrdraht-/Tragseil-Ankerpunkt wurde nicht erkannt. Der Fahrdraht kann nicht erzeugt werden.');
         exit; //Abbruch, weil Fahrdraht entarten würde
    end;

    //Normalhänger
    if i > 0 then
    begin
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

      DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeHaenger,DrahtFarbe,Helligkeit);

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
    end;

    // Tragseil-Abschnitte zwischen den Hängern
    for a:=1 to length(ErgebnisArray)-1 do DrahtEintragen(ErgebnisArray[a-1].Punkt2,ErgebnisArray[a].Punkt2,StaerkeTS,DrahtFarbe,Helligkeit);

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
    //Sonderfall kurze Spannweite:
    if i = 0 then LetztNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;

    DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeHaenger,DrahtFarbe,Helligkeit);

    //Verbindung zwischen erstem Hänger und erstem Normalhänger
    if i > 0 then DrahtEintragen(ErstNormalhaengerpunkt,pktO.PunktTransformiert.Punkt,StaerkeTS,DrahtFarbe,Helligkeit);

    //Verbindung zwischen erstem Hänger und Ausleger A
    DrahtEintragen(pktTA.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeTS,DrahtFarbe,Helligkeit);

    //Verbindung zwischen letztem Normalhänger und Spannwerk an B
    DrahtEintragen(pktTB.PunktTransformiert.Punkt,LetztNormalhaengerpunkt,StaerkeTS,DrahtFarbe,Helligkeit);

    //Isolator am Spannwerk oben
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktTB.PunktTransformiert.Punkt, Letztnormalhaengerpunkt, 2, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //Isolator am Spannwerk unten
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, 2, pktU.PunktTransformiert.Punkt, pktU.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //bei geerdetem Ausleger Isolator ins Tragseil einbauen
    if (IsolatorBaumodus = 1) or (IsolatorBaumodus = 3) then
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktTA.PunktTransformiert.Punkt, ErstNormalhaengerpunkt, 0.6, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel); //geerdeter Ausleger - Isolator 0,6 m vom Stützpunkt entfernt
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
    end;

    //Fahrdraht eintragen
    DrahtEintragen(pktFA.PunktTransformiert.Punkt,pktFB.PunktTransformiert.Punkt,StaerkeFD,DrahtFarbe,Helligkeit);
  end;
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
    0: BautypA := y6m;
    1: BautypA := Festp;
    2: BautypA := FestpIso;
    3: BautypA := y6mZ;
    4: BautypA := Ausfaedel;
    5: BautypA := Abschluss;
  end;
    case Typ2 of
    0: BautypB := y6m;
    1: BautypB := Festp;
    2: BautypB := FestpIso;
    3: BautypB := y6mZ;
    4: BautypB := Ausfaedel;
    5: BautypB := Abschluss;
  end;


  //hier wird entschieden was wir machen. Zuerst die Sonderfälle:
  if (BautypA=Festp) and (BautypB=FestpIso) then Festpunktabspannung;
  if (BautypA=FestpIso) and (BautypB=Festp) then
  begin //Arrays durchtauschen, da die Bau-Procedure nicht seitenneutral ist
    BaurichtungWechseln;
    Festpunktabspannung;
  end;
  if (BautypA=Ausfaedel) and (BautypB=Abschluss) then KettenwerkAbschluss(0.5,22.8,Ankertyp_FahrleitungAusfaedelungFahrdraht,Ankertyp_FahrleitungAusfaedelungTragseil);      //Ausfädelung an A, Isolatoren an B; Letzthängerabstand 25,0 m wegen hängerfreiem Seil, Isolatorlänge und Abstand Isolator zu Spannwerk
  if (BautypA=Abschluss) and (BautypB=Ausfaedel) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei Abschlüssen nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkAbschluss(0.5,22.8,Ankertyp_FahrleitungAusfaedelungFahrdraht,Ankertyp_FahrleitungAusfaedelungTragseil);
  end;

  //einige unsinnige Kombinationen abfangen
  if (BautypA in [Festp,FestpIso]) and (BautypB in [y6m, y6mZ, ausfaedel, Abschluss]) then BaufunktionAufgerufen := true;
  if (BautypA in [y6m, y6mZ, ausfaedel, Abschluss]) and (BautypB in [Festp,FestpIso]) then BaufunktionAufgerufen := true;
  if (BautypA in [Abschluss]) and (BautypB in [y6mZ, Abschluss]) then BaufunktionAufgerufen := true;
  if (BautypA in [y6mZ, Abschluss]) and (BautypB in [Abschluss]) then BaufunktionAufgerufen := true;

  if ((BautypA in [y6m]) and (BautypB in [Abschluss])) or ((BautypA in [Abschluss]) and (BautypB in [y6m])) then showmessage('Kettenwerk von Abschluss direkt auf Y-Seil ist sehr ungewöhnlich. Bitte prüfen ob dies wirklich vorbildgerecht ist.');

  //Der catch-all für alle sonstigen Kombinationen (hoffentlich nur sinnvolle);
  if not BaufunktionAufgerufen then Kettenwerk(BautypA,BautypB);

  if not BaufunktionAufgerufen then ShowMessage('Die gewählte Bauart-Kombination ist nicht implementiert. Bei tatsächlichem Bedarf bitte beim Autor der DLL melden.');

  Result.iDraht:=length(ErgebnisArray);
  Result.iDatei:=length(ErgebnisArrayDateien);
end;


function Bezeichnung:PChar; stdcall;
begin
  Result:='Re 120'
end;

function Gruppe:PChar; stdcall;
// Teilt dem Editor die Objektgruppe mit, die er bei den verknüpften Dateien vermerken soll
begin
  Result:='Kettenwerk Re 120';
end;

procedure Config(AppHandle:HWND); stdcall;
var Formular:TFormFahrleitungConfig;
begin
  if not DialogOffen then
  begin
  DialogOffen:=true;
  //Application.Handle:=AppHandle;
  Application.Initialize;
  Formular:=TFormFahrleitungConfig.Create(Application);
  Formular.LabeledEditIsolator.Text:=DateiIsolator;
  Formular.TrackBarFestpunktisolator.Position := Festpunktisolatorposition;
  Formular.RadioGroupZusatzisolatoren.ItemIndex := IsolatorBaumodus;
  if Helligkeit = 0 then Formular.RadioGroupZwangshelligkeit.ItemIndex := 0;
  if SameValue(Helligkeit,0.07,0.01) then Formular.RadioGroupZwangshelligkeit.ItemIndex := 1;

  Formular.ShowModal;

  if Formular.ModalResult=mrOK then
  begin
    DateiIsolator:=(Formular.LabeledEditIsolator.Text);
    IsolatorBaumodus:=Formular.RadioGroupZusatzisolatoren.ItemIndex;
    Festpunktisolatorposition := Formular.TrackBarFestpunktisolator.Position;
    if Formular.RadioGroupZwangshelligkeit.ItemIndex = 0 then Helligkeit := 0;
    if Formular.RadioGroupZwangshelligkeit.ItemIndex = 1 then Helligkeit := 0.07;
    RegistrySchreiben;
    RegistryLesen;
  end;

  //Application.Handle:=0;
  Formular.Free;
  DialogOffen:=false;
  end;
end;

end.
