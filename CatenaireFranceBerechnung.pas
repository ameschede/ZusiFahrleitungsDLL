unit CatenaireFranceBerechnung;

{$MODE Delphi}

interface

uses
  Direct3D9, D3DX9,

  sysutils, Controls, registry, windows, forms, Math, Dialogs, interfaces, LConvEncoding,
  
  ZusiD3DTypenDll, FahrleitungsTypen, OLADLLgemeinsameFkt, CatenaireFranceConfigForm;

type

  TEndstueck = (Ausfaedel, Festp, FestpIso, Abschluss, Normal);

function Init:Longword; stdcall;
function BauartTyp(i:Longint):PChar; stdcall;
function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
procedure Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT:TAnkerpunkt; Ersthaengerabstand,Abstand,Richtung:single;IsolatorEinbau:boolean);
function Bezeichnung:PChar; stdcall;
function Gruppe:PChar; stdcall;
procedure Config(AppHandle:HWND); stdcall;
function Fahrleitungstyp:TFahrleitungstyp; stdcall;

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
    StaerkeFD,StaerkeTS,StaerkeHaenger,StaerkeAnkerseil,Helligkeit,Parabelfaktor:single;
    Kettenwerkstyp,IsolatorBaumodus,Festpunktisolatorposition:integer;
    DrahtFarbe:TD3DColorValue;
    V350,V300,V200,V160,BaufunktionAufgerufen,DialogOffen:boolean;

procedure RegistryLesen;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\CatenaireFrance') then
            begin
              if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
              if reg.ValueExists('Festpunktisolatorposition') then Festpunktisolatorposition := reg.ReadInteger('Festpunktisolatorposition');
              if reg.ValueExists('IsolatorBaumodus') then IsolatorBaumodus := reg.ReadInteger('IsolatorBaumodus');
              if reg.ValueExists('Kettenwerkstyp') then Kettenwerkstyp := reg.ReadInteger('Kettenwerkstyp');
              if reg.ValueExists('Helligkeit') then Helligkeit := reg.ReadFloat('Helligkeit');
              if reg.ValueExists('Parabelfaktor') then Parabelfaktor := reg.ReadFloat('Parabelfaktor');
            end;
            case Kettenwerkstyp of
            0: V350 := true;
            1: V300 := true;
            2: V200 := true;
            3: V160 := true;
            end;
            if V350 then
            begin
              StaerkeFD := 0.007;
              StaerkeTS := 0.006;
            end;
            if V300 then
            begin
              StaerkeFD := 0.007;
              StaerkeTS := 0.0045;
            end;
            if V200 or V160 then
            begin
              StaerkeFD := 0.006;
              StaerkeTS := 0.0045;
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
            if reg.OpenKey('CatenaireFrance', true) then
            begin
              reg.WriteString('DateiIsolator', DateiIsolator);
              reg.WriteInteger('IsolatorBaumodus',IsolatorBaumodus);
              reg.WriteInteger('Kettenwerkstyp',Kettenwerkstyp);
              reg.WriteInteger('Festpunktisolatorposition',Festpunktisolatorposition);
              reg.WriteFloat('Helligkeit',Helligkeit);
              reg.WriteFloat('Parabelfaktor',Parabelfaktor);
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
  Result:=5;  //muss passen zu den möglichen Rückgabewerten der function BauartTyp
  Reset(true);
  Reset(false);
  DateiIsolator:='Catenary\Deutschland\Einzelteile_Re75-200\Isolator.lod.ls3';
  StaerkeFD := 0.007; //bei V350 und V300; 0.006 bei V200/V160
  StaerkeTS := 0.006; //bei V350; 0.0045 bei V300/V200/V160
  StaerkeHaenger := 0.002;
  StaerkeAnkerseil := 0.0045;
  Kettenwerkstyp := 0; //V350 als Default
  IsolatorBaumodus := 0;
  Festpunktisolatorposition:=10;
  Helligkeit := 0;
  Parabelfaktor := 0.00055;
  RegistryLesen;
end;

function BauartTyp(i:Longint):PChar; stdcall;
// Wird vom Editor so oft aufgerufen, wie wir als Result in der init-function übergeben haben. Enumeriert die Bauart-Typen, die diese DLL kennt 
begin
  case i of
  0: Result:='Normalkettenwerk';
  1: Result:='Festpunktabspannung';
  2: Result:='Festpunktabspannung mit Isolator';
  3: Result:='Ausfädelung';
  4: Result:='Abschluss mit Isolatoren';
  else Result := 'Normalkettenwerk'
  end;

  //Zusi 3.5 erwartet Codepage 1252 auf der DLL-Schnittstelle
  Result:=PChar(UTF8toCP1252(Result));
end;

function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
// Wir versuchen, aus der vom Editor übergebenen Ankerkonfiguration einen Bauarttypen vorzuschlagen
  function Vorschlagen(Punkte:array of TAnkerpunkt):Longint	;
  var iOben0, iUnten0, iOben1, iUnten1, iOben2, iUnten2:integer;
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

    //liegt ein Spannpunkt vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAbspannungMastpunktFahrdraht then inc(iUnten0);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAbspannungMastpunktTragseil then inc(iOben0);
    end;
    if (iUnten0=1) and (iOben0=1) then Result:=4;

    //liegt ein Ausfädelungs-Ausleger vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungFahrdraht then inc(iUnten1);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungTragseil then inc(iOben1);
    end;
    if (iUnten1=1) and (iOben1=1) then Result:=3;

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
    if (iUnten2=1) and (iOben2=1) then Result:= 0;
  end;

begin
    if A then Result:=Vorschlagen(PunkteA)
         else Result:=Vorschlagen(PunkteB);
end;

procedure Normalkettenwerk(EndstueckA,EndstueckB:TEndstueck);
var pktFA, pktFB, pktTA, pktTB, pktU, pktO:TAnkerpunkt;
    Abstand, Durchhang, {LaengeNormalhaengerbereich,} Ersthaengerabstand, Letzthaengerabstand, Rest:single;
    vFahrdraht, vTragseil, v, vNeu, vNorm, ErstNormalhaengerpunkt, LetztNormalhaengerpunkt:TD3DVector;
    i, j, a:integer;
    TeilungFreiBerechnet:boolean;

begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    BaufunktionAufgerufen := true;
    if EndstueckA in [Normal,Ausfaedel] then Ersthaengerabstand := 4.5;
    if EndstueckB in [Normal,Ausfaedel] then Letzthaengerabstand := 4.5;

    //Feststellen welcher Ankertyp am Fahrdraht zu erwarten ist
    if EndstueckA = Ausfaedel then pktFA:=PunktSuchen(true, 1, Ankertyp_FahrleitungAusfaedelungFahrdraht)
      else pktFA:=PunktSuchen(true, 1, Ankertyp_FahrleitungFahrdraht);
    if EndstueckB = Ausfaedel then pktFB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAusfaedelungFahrdraht)
      else pktFB:=PunktSuchen(false, 1, Ankertyp_FahrleitungFahrdraht);

    //Fahrdraht berechnen als Vektor von FA nach FB
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);

    if (Abstand < 22.7) then
    begin
         ShowMessage('Längsspannweite unter 22,7 m. Es kann kein gültiger Fahrdraht berechnet werden.');
         exit; //Abbruch, weil Fahrdraht entarten würde
    end;


    //Spannweite auf Plausibilität prüfen
    if (EndstueckA in [Normal]) and (EndstueckB in [Normal]) and not V160 then
      begin
        if (Abstand < 26.75) or (Abstand > 63.5) then ShowMessage(FormatFloat('0.00',Abstand) + ' m Längsspannweite liegt außerhalb der zulässigen Grenzen des Kettenwerks (27 bis 63 m).'); //Aufgrund möglicher Ungenauigkeiten der Maststandorte in Zusi geben wir einen halben Meter Toleranz
      end;
    if (EndstueckA in [Normal]) and (EndstueckB in [Normal]) and V160 then // Bauart V160 hat erhöhte zulässige Längspannweite
      begin
        if (Abstand < 26.75) or (Abstand > 70.5) then ShowMessage(FormatFloat('0.00',Abstand) + ' m Längsspannweite liegt außerhalb der zulässigen Grenzen des Kettenwerks (27 bis 70 m).'); //Aufgrund möglicher Ungenauigkeiten der Maststandorte in Zusi geben wir einen halben Meter Toleranz
      end;

    //Für bestimmte Spannweiten die Hängerteilung vorgeben
    TeilungFreiBerechnet := true;
    if (Abstand > 26.75) and (Abstand < 29.25) then begin i:=1; j:=0; TeilungFreiBerechnet:=false; end; //Kettenwerk N9
    if (Abstand > 31.25) and (Abstand < 36.00) then begin i:=1; j:=2; TeilungFreiBerechnet:=false; end; //Kettenwerk N8
    if (Abstand > 40.25) and (Abstand < 42.75) then begin i:=2; j:=0; TeilungFreiBerechnet:=false; end; //Kettenwerk N6
    if (Abstand > 44.75) and (Abstand < 49.50) then begin i:=2; j:=2; TeilungFreiBerechnet:=false; end; //Kettenwerk N5
    if (Abstand > 53.75) and (Abstand < 56.25) then begin i:=3; j:=0; TeilungFreiBerechnet:=false; end; //Kettenwerk N3
    if (Abstand > 58.25) and (Abstand < 63.24) then begin i:=3; j:=2; TeilungFreiBerechnet:=false; end; //Kettenwerk N2

    Rest := Abstand - Ersthaengerabstand - Letzthaengerabstand -(i*13.5);
    if TeilungFreiBerechnet then
    begin
      //showmessage('Hängerteilung ist nicht tabelliert und muss frei berechnet werden.');
      i:=Math.Floor((Abstand - Ersthaengerabstand - Letzthaengerabstand)/13.5);    //max. Hängerabstand bei französischen Fahrleitungen ist 6,75 m; im Zweifel abrunden.
      Rest := Abstand - Ersthaengerabstand - Letzthaengerabstand -(i*13.5);
      //showmessage('Spannweite: '+ floattostr(Abstand) + '; Rest in Feldmitte: '+floattostr(Rest)+'; Anzahl Hänger vor Längenausgleich: ' + inttostr(((i*2)+2)));
      if (Rest < 4.5) or (Rest > 6.75) then
      begin
        i := i-1;
        Rest := Abstand - Ersthaengerabstand - Letzthaengerabstand -(i*13.5);
        //showmessage('Hängeranzahl wurde angepasst. Rest in Feldmitte jetzt '+floattostr(Rest));
      end;
      if (Rest > 6.75) and (Rest < 9) then showmessage('Fehler: Das berechnete Kettenwerk ist unplausibel. Bitte beim DLL-Autor melden und die Spannweite nennen: '+ floattostr(Abstand));
    end;

    //Feststellen welcher Ankertyp am Tragseil zu erwarten ist
    if EndstueckA = Ausfaedel then pktTA:=PunktSuchen(true, 1, Ankertyp_FahrleitungAusfaedelungTragseil)
      else pktTA:=PunktSuchen(true, 1, Ankertyp_FahrleitungTragseil);

    if EndstueckB = Ausfaedel then pktTB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAusfaedelungTragseil)
      else pktTB:=PunktSuchen(false, 1, Ankertyp_FahrleitungTragseil);

    //Prüfung ob notwendige Ankerpunkte vorhanden sind
    if AnkerIstLeer(pktTA) or AnkerIstLeer(pktTB) or AnkerIstLeer(pktFA) or AnkerIstLeer(pktFB) then
    begin
         showmessage('Warnung: Ein notwendiger Fahrdraht-/Tragseil-Ankerpunkt wurde nicht erkannt. Der Fahrdraht kann nicht erzeugt werden.');
         exit; //Abbruch, weil Fahrdraht entarten würde
    end;

    //Tragseil Endpunkte
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);

    //Strategie: Von beiden Auslegern aus werden i Hänger mit Abstand 6,75 m vorwärts gebaut. Die Lücke in der Mitte wird ggfs. mit einem weiteren Hänger unterteilt, sofern sie länger als 9 m ist

    //Normalhänger ab Ausleger A
    for a:=1 to i do
    begin
      //unterer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (a * 6.75)));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Ersthaengerabstand + (a * 6.75));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      Durchhang := (Parabelfaktor * sqr(Ersthaengerabstand + (a * 6.75) - (Abstand/2)) + 1.0) / (Parabelfaktor * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeHaenger,DrahtFarbe,Helligkeit);

      if a = 1 then
      begin
      //oberen Punkt des ersten Hängers für spätere Verwendung speichern
      ErstNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
    end;

    //Hänger in Feldmitte
    if TeilungFreiBerechnet then
    begin
      if (Rest > 9) and (Rest < 13.5) then j:=2; //es wird 1 zusätzlicher Hänger (= 2 Felder) benötigt
      if (Rest > 13.5) and (Rest < 20.25) then j:=3; //es werden 2 zusätzliche Hänger (= 3 Felder) benötigt
      if (Rest > 20.25) then j:=4; //es werden 3 zusätzliche Hänger (= 4 Felder) benötigt
    end;
    for a := 1 to (j-1) do
    begin
      //unterer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (i * 6.75)+((Rest/j)*a)));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Ersthaengerabstand + (i * 6.75)+((Rest/j))*a);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      Durchhang := (Parabelfaktor * sqr(Ersthaengerabstand + (i * 6.75) + ((Rest/j)*a) - (Abstand/2)) + 1.0) / (Parabelfaktor * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeHaenger,DrahtFarbe,Helligkeit);

      //Falls es wegen sehr kurzer Spannweite keine Normalhänger gibt ist die Normalhängerschleife nicht durchgelaufen
      //In diesem Fall muss ein Erst- und Letztnormalhaengerpunkt synthetisiert werden
      if (i = 0) and (a = 1) then ErstNormalhaengerpunkt:=pktO.PunktTransformiert.Punkt;
      if (i = 0) and (a > 1) then LetztNormalhaengerpunkt:=pktO.PunktTransformiert.Punkt;
    end;

    //Normalhänger ab Ausleger B
    for a:=i downto 1 do
    begin
      //unterer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, -1 * (Letzthaengerabstand+(a*6.75)));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt, v);

      //oberer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, -1 * (Letzthaengerabstand+(a*6.75)));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTB.PunktTransformiert.Punkt, v);

      //Punkt absenken
      Durchhang := (Parabelfaktor * sqr((Letzthaengerabstand+(a*6.75)) - (Abstand/2)) + 1) / (Parabelfaktor * sqr(Abstand/2) + 1);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeHaenger,DrahtFarbe,Helligkeit);

      if a = 1 then LetztNormalhaengerpunkt := pktO.PunktTransformiert.Punkt; //oberen Punkt des ersten Hängers für spätere Verwendung speichern
    end;

    // Tragseil-Abschnitte zwischen den Hängern
    for a:=1 to length(ErgebnisArray)-1 do DrahtEintragen(ErgebnisArray[a-1].Punkt2,ErgebnisArray[a].Punkt2,StaerkeTS,DrahtFarbe,Helligkeit);

    //Endstücke
    if EndstueckA in [Normal] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,Ersthaengerabstand,Abstand,1,false);
    if EndstueckB in [Normal] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,Letzthaengerabstand,Abstand,-1,false);

    if IsolatorBaumodus = 0 then
    begin
      if EndstueckA in [Ausfaedel] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,Ersthaengerabstand,Abstand,1,false);
      if EndstueckB in [Ausfaedel] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,Letzthaengerabstand,Abstand,-1,false);
    end;
    if IsolatorBaumodus = 1 then   // Streckentrennung: Isolatoren 2,0 m vom Stützpunkt einbauen
    begin
      if EndstueckA in [Ausfaedel] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,Ersthaengerabstand,Abstand,1,true);
      if EndstueckB in [Ausfaedel] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,Letzthaengerabstand,Abstand,-1,true);
    end;
    if IsolatorBaumodus = 2 then   // Schutzstrecke: Isolatoren 2,3 m und 1,0 m vom Stützpunkt einbauen
    begin
      if EndstueckA in [Ausfaedel] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,Ersthaengerabstand,Abstand,1,true);
      if EndstueckB in [Ausfaedel] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,Letzthaengerabstand,Abstand,-1,true);
    end;

    //Fahrdraht eintragen
    DrahtEintragen(pktFA.PunktTransformiert.Punkt,pktFB.PunktTransformiert.Punkt,StaerkeFD,DrahtFarbe,Helligkeit);
  end;
end;

procedure Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT:TAnkerpunkt; Ersthaengerabstand,Abstand,Richtung:single;IsolatorEinbau:boolean);
var pktU, pktO:TAnkerpunkt;
    v, vNorm, vNeu,Endstueckendepunkt: TD3DVector;
    Durchhang:single;
begin
    //Erster Hänger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * Ersthaengerabstand);
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * Ersthaengerabstand);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (Parabelfaktor * sqr(Ersthaengerabstand - (Abstand/2)) + 1) / (Parabelfaktor * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    EndstueckEndepunkt := pktO.PunktTransformiert.Punkt;
    //Ersthänger
    DrahtEintragen(pktU.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeHaenger,DrahtFarbe,Helligkeit);

    //Tragseil zwischen Ersthänger und Ausleger
    DrahtEintragen(pktT.PunktTransformiert.Punkt,pktO.PunktTransformiert.Punkt,StaerkeTS,DrahtFarbe,Helligkeit);

    //Tragseil zwischen Ersthänger und erstem Normalhänger
    DrahtEintragen(ErstNormalhaengerpunkt,pktO.PunktTransformiert.Punkt,StaerkeTS,DrahtFarbe,Helligkeit);

    //ggfs. Isolatoren einbauen.
    if IsolatorEinbau and (IsolatorBaumodus = 1) then    // Streckentrennung: Isolatoren bei 2,0 m vom Stützpunkt einbauen
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktT.PunktTransformiert.Punkt, EndstueckEndepunkt, 2.0, pktT.PunktTransformiert.Punkt, pktT.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktT.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktT.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktF.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, 2.0, pktF.PunktTransformiert.Punkt, pktF.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktF.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktF.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
    end;
    if IsolatorEinbau and (IsolatorBaumodus = 2) then     // Schutzstrecke: Isolatoren bei 1,0 m und 2,3 m vom Stützpunkt einbauen
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktT.PunktTransformiert.Punkt, EndstueckEndepunkt, 2.3, pktT.PunktTransformiert.Punkt, pktT.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktT.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktT.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktF.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, 2.3, pktF.PunktTransformiert.Punkt, pktF.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktF.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktF.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktT.PunktTransformiert.Punkt, EndstueckEndepunkt, 1.0, pktT.PunktTransformiert.Punkt, pktT.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktT.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktT.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktF.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, 1.0, pktF.PunktTransformiert.Punkt, pktF.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktF.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktF.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

      showmessage('Bitte ggfs. überzählige Isolatoren von Hand löschen');
    end;

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
    AbstandFD, AbstandTS, Laengendifferenz, Durchhang, Haengerabstand:single;
    vFahrdraht, vTragseil, v, vNeu, vNorm, Startpunkt:TD3DVector;
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
    AbstandFD:=D3DXVec3Length(vFahrdraht);

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true, 1, AnkommenderAnkertypT);
    pktTB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAbspannungMastpunktTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);
    AbstandTS:=D3DXVec3Length(vTragseil);

    Laengendifferenz := AbstandTS - AbstandFD;

    //Prüfung ob notwendige Ankerpunkte vorhanden sind
    if AnkerIstLeer(pktTA) or AnkerIstLeer(pktTB) or AnkerIstLeer(pktFA) or AnkerIstLeer(pktFB) then
    begin
         showmessage('Warnung: Ein notwendiger Fahrdraht-/Tragseil-Ankerpunkt wurde nicht erkannt. Der Fahrdraht kann nicht erzeugt werden.');
         exit; //Abbruch, weil Fahrdraht entarten würde
    end;

    //Das Abschluss-Kettenwerk der französischen Fahrleitung zeichnet sich durch fehlende Hänger aus, so dass auch der Fahrdraht durchhängt.
    i := 10;
    Haengerabstand := AbstandTS/i;

    Startpunkt := pktTA.PunktTransformiert.Punkt;
    for a:=1 to i do
    begin
      //Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, a * Haengerabstand);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);
      pktU := pktO;
      pktU.PunktTransformiert.Punkt.z := pktU.PunktTransformiert.Punkt.z-1; //Synthetisierung eines virtuellen Punkts 1 Meter unter dem Seil

      //Punkt absenken
      Durchhang := (Parabelfaktor * sqr((a * Haengerabstand) - (AbstandTS/2)) + 1.0) / (Parabelfaktor * sqr(AbstandTS/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      DrahtEintragen(Startpunkt,pktO.PunktTransformiert.Punkt,StaerkeTS,DrahtFarbe,Helligkeit);
      Startpunkt := pktO.PunktTransformiert.Punkt;

      //Isolator im Tragseil am Spannwerk
      if a = i-1 then
      begin
        setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
        LageIsolator(pktTB.PunktTransformiert.Punkt, pktO.PunktTransformiert.Punkt, (2 + Laengendifferenz), pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel); //Tragseil-Isolator je nach Einstellung in 2,46 oder 2 Meter vom Spannwerk
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
      end;
    end;

    Haengerabstand := AbstandFD/i;
    Startpunkt := pktFA.PunktTransformiert.Punkt;
    for a:=1 to i do
    begin
      //Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, a * Haengerabstand);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);
      pktU := pktO;
      pktU.PunktTransformiert.Punkt.z := pktU.PunktTransformiert.Punkt.z-1; //Synthetisierung eines virtuellen Punkts 1 Meter unter dem Seil

      //Punkt absenken
      Durchhang := (Parabelfaktor * sqr((a * Haengerabstand) - (AbstandFD/2)) + 1.0) / (Parabelfaktor * sqr(AbstandFD/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      DrahtEintragen(Startpunkt,pktO.PunktTransformiert.Punkt,StaerkeFD,DrahtFarbe,Helligkeit);
      Startpunkt := pktO.PunktTransformiert.Punkt;

      //Isolator im Fahrdraht am Spannwerk
      if a = i-1 then
      begin
        setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
        LageIsolator(pktFB.PunktTransformiert.Punkt, pktO.PunktTransformiert.Punkt, 2, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel);
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
        ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
      end;
    end;
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
    0: BautypA := Normal;
    1: BautypA := Festp;
    2: BautypA := FestpIso;
    3: BautypA := Ausfaedel;
    4: BautypA := Abschluss;
  end;
    case Typ2 of
    0: BautypB := Normal;
    1: BautypB := Festp;
    2: BautypB := FestpIso;
    3: BautypB := Ausfaedel;
    4: BautypB := Abschluss;
  end;

  //hier wird entschieden was wir machen. Zuerst die Sonderfälle:
  if (BautypA=Festp) and (BautypB=FestpIso) then Festpunktabspannung;
  if (BautypA=FestpIso) and (BautypB=Festp) then
  begin //Arrays durchtauschen, da die Bau-Procedure nicht seitenneutral ist
    BaurichtungWechseln;
    Festpunktabspannung;
  end;
  if (BautypA=Ausfaedel) and (BautypB=Abschluss) then KettenwerkAbschluss(4.5,25.0,Ankertyp_FahrleitungAusfaedelungFahrdraht,Ankertyp_FahrleitungAusfaedelungTragseil);      //Ausfädelung an A, Isolatoren an B; Letzthängerabstand 25,0 m wegen hängerfreiem Seil, Isolatorlänge und Abstand Isolator zu Spannwerk
  if (BautypA=Abschluss) and (BautypB=Ausfaedel) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei Abschlüssen nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkAbschluss(4.5,25.0,Ankertyp_FahrleitungAusfaedelungFahrdraht,Ankertyp_FahrleitungAusfaedelungTragseil);
  end;
  if (BautypA in [Normal]) and (BautypB=Abschluss) then KettenwerkAbschluss(4.5,25.0,Ankertyp_FahrleitungFahrdraht,Ankertyp_FahrleitungTragseil);      //Ausfädelung an A, Isolatoren an B; Letzthängerabstand 25,0 m wegen hängerfreiem Seil, Isolatorlänge und Abstand Isolator zu Spannwerk
  if (BautypA=Abschluss) and (BautypB in [Normal]) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei Abschlüssen nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkAbschluss(4.5,25.0,Ankertyp_FahrleitungFahrdraht,Ankertyp_FahrleitungTragseil);
  end;

  //einige unsinnige Kombinationen abfangen
  if (BautypA in [Festp,FestpIso]) and (BautypB in [ausfaedel, Abschluss]) then BaufunktionAufgerufen := true;
  if (BautypA in [ausfaedel, Abschluss]) and (BautypB in [Festp,FestpIso]) then BaufunktionAufgerufen := true;
  if (BautypA in [Abschluss]) and (BautypB in [Abschluss]) then BaufunktionAufgerufen := true;
  if (BautypA in [Abschluss]) and (BautypB in [Abschluss]) then BaufunktionAufgerufen := true;

  //Der catch-all für alle sonstigen Kombinationen (hoffentlich nur sinnvolle);
  if not BaufunktionAufgerufen then Normalkettenwerk(BautypA,BautypB);

  if not BaufunktionAufgerufen then ShowMessage('Die gewählte Bauart-Kombination ist nicht implementiert. Bei tatsächlichem Bedarf bitte beim Autor der DLL melden.');

  Result.iDraht:=length(ErgebnisArray);
  Result.iDatei:=length(ErgebnisArrayDateien);
end;


function Bezeichnung:PChar; stdcall;
begin
  Result:='Catenaire France'
end;

function Gruppe:PChar; stdcall;
// Teilt dem Editor die Objektgruppe mit, die er bei den verknüpften Dateien vermerken soll
begin
  Result:='Catenaire France';
end;

procedure Config(AppHandle:HWND); stdcall;
var Formular:TFormFahrleitungConfig;
begin
  if not DialogOffen then
  begin
       DialogOffen:=true;
       Application.Initialize;
       //Application.Handle:=AppHandle;
       Formular:=TFormFahrleitungConfig.Create(Application);
       Formular.LabeledEditIsolator.Text:=DateiIsolator;
       Formular.RadioGroupKettenwerkstyp.ItemIndex := Kettenwerkstyp;
       Formular.RadioGroupZusatzisolatoren.ItemIndex := IsolatorBaumodus;
       Formular.TrackBarFestpunktisolator.Position := Festpunktisolatorposition;
       if Helligkeit = 0 then Formular.RadioGroupZwangshelligkeit.ItemIndex := 0;
       if SameValue(Helligkeit,0.07,0.01) then Formular.RadioGroupZwangshelligkeit.ItemIndex := 1;
       if SameValue(Parabelfaktor,0.00055,0.0001) then Formular.RadioGroupDurchhang.ItemIndex := 0;
       if SameValue(Parabelfaktor,0.0004,0.0001) then Formular.RadioGroupDurchhang.ItemIndex := 1;

       Formular.ShowModal;

       if Formular.ModalResult=mrOK then
       begin
       DateiIsolator:=(Formular.LabeledEditIsolator.Text);
       Kettenwerkstyp:=Formular.RadioGroupKettenwerkstyp.ItemIndex;
       IsolatorBaumodus:=Formular.RadioGroupZusatzisolatoren.ItemIndex;
       Festpunktisolatorposition := Formular.TrackBarFestpunktisolator.Position;
       if Formular.RadioGroupZwangshelligkeit.ItemIndex = 0 then Helligkeit := 0;
       if Formular.RadioGroupZwangshelligkeit.ItemIndex = 1 then Helligkeit := 0.07;
       if Formular.RadioGroupDurchhang.ItemIndex = 0 then Parabelfaktor := 0.00055;
       if Formular.RadioGroupDurchhang.ItemIndex = 1 then Parabelfaktor := 0.0004;
       RegistrySchreiben;
       RegistryLesen;
       end;

       //Application.Handle:=0;
       Formular.Free;
       DialogOffen:=false;
  end;
end;

function Fahrleitungstyp:TFahrleitungstyp; stdcall;
//Wird nur für Automatik-Modus gebraucht; gibt an welche Sorte Fahrleitung wir verlegen
begin
  Result:=Fahrl_25kV50Hz;
end;

end.
