unit CatenaireFranceBerechnung;

interface

uses
  Direct3D9, d3dx9,

  sysutils, Controls, registry, windows, forms, Math, Dialogs,
  
  ZusiD3DTypenDll, FahrleitungsTypen, OLADLLgemeinsameFkt, CatenaireFranceConfigForm;

type

  TEndstueck = (Ausfaedel, Festp, FestpIso, Abschluss, Normal);

function Init:Longword; stdcall;
function BauartTyp(i:Longint):PChar; stdcall;
function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
procedure Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT:TAnkerpunkt; Ersthaengerabstand,Abstand,Richtung: single);
function Bezeichnung:PChar; stdcall;
function Gruppe:PChar; stdcall;
procedure Config(AppHandle:HWND); stdcall;

exports Init,
        BauartTyp,
        BauartVorschlagen,
        Berechnen,
        Bezeichnung,
        Gruppe,
        Config;


implementation

var
    DateiIsolator:string;
    StaerkeFD,StaerkeTS,StaerkeHaenger,StaerkeAnkerseil:single;
    Kettenwerkstyp,IsolatorBaumodus:integer;
    DrahtFarbe:TD3DColorValue;
    V350,V300,V200,V160,BaufunktionAufgerufen:boolean;

procedure RegistryLesen;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\CatenaireFrance') then
            begin
              if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
              if reg.ValueExists('IsolatorBaumodus') then IsolatorBaumodus := reg.ReadInteger('IsolatorBaumodus');
              if reg.ValueExists('Kettenwerkstyp') then Kettenwerkstyp := reg.ReadInteger('Kettenwerkstyp');
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
    i, a:integer;

begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    BaufunktionAufgerufen := true;
    if EndstueckA in [Normal] then Ersthaengerabstand := 4.5;
    if EndstueckB in [Normal] then Letzthaengerabstand := 4.5;
    if EndstueckA in [Ausfaedel] then Ersthaengerabstand := 0;
    if EndstueckB in [Ausfaedel] then Letzthaengerabstand := 0;
    if EndstueckA in [Abschluss] then Ersthaengerabstand := 25.0;
    if EndstueckB in [Abschluss] then Letzthaengerabstand := 25.0;



    //Feststellen welcher Ankertyp am Fahrdraht zu erwarten ist
    if EndstueckA = Ausfaedel then pktFA:=PunktSuchen(true, 0, Ankertyp_FahrleitungAusfaedelungFahrdraht)
      else
      begin
      if EndstueckA = Abschluss then pktFA:=PunktSuchen(true, 0, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht)
        else pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungFahrdraht);
      end;
    if EndstueckB = Ausfaedel then pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAusfaedelungFahrdraht)
      else
      begin
      if EndstueckB = Abschluss then pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht)
        else pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungFahrdraht);
      end;
    //Fahrdraht berechnen als Vektor von FA nach FB
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);

    //Spannweite auf Plausibilität prüfen
    if (EndstueckA in [Normal]) and (EndstueckB in [Normal]) then
      begin
        if (Abstand < 26.75) or (Abstand > 63.5) then ShowMessage(floattostr(Math.RoundTo(Abstand,-2)) + ' m Längsspannweite liegt außerhalb der zulässigen Grenzen des Kettenwerks (27 bis 63 m).'); //Aufgrund möglicher Ungenauigkeiten der Maststandorte in Zusi geben wir einen halben Meter Toleranz
      end;

    i:=Math.Floor((Abstand - Ersthaengerabstand - Letzthaengerabstand)/13.5);    //max. Hängerabstand bei französischen Fahrleitungen ist 6,75 m; im Zweifel abrunden.
    Rest := Abstand - Ersthaengerabstand - Letzthaengerabstand -(i*13.5);
    //showmessage('Spannweite: '+ floattostr(Abstand) + '; Rest in Feldmitte: '+floattostr(Rest)+'; Anzahl Hänger vor Längenausgleich:' + inttostr(((i*2)+2)));
    if (Rest > 6.75) and (Rest < 9) then showmessage('Fehler: Das berechnete Kettenwerk ist unplausibel. Bitte beim DLL-Autor melden und die Spannweite nennen: '+ floattostr(Abstand));

    //Feststellen welcher Ankertyp am Tragseil zu erwarten ist
    if EndstueckA = Ausfaedel then pktTA:=PunktSuchen(true, 0, Ankertyp_FahrleitungAusfaedelungTragseil)
      else
      begin
      if EndstueckA = Abschluss then pktTA:=PunktSuchen(true, 0, Ankertyp_FahrleitungAbspannungMastpunktTragseil)
        else pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungTragseil);
      end;
    if EndstueckB = Ausfaedel then pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAusfaedelungTragseil)
      else
      begin
      if EndstueckB = Abschluss then pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAbspannungMastpunktTragseil)
        else pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungTragseil);
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
      Durchhang := (0.00055 * sqr(Ersthaengerabstand + (a * 6.75) - (Abstand/2)) + 1.0) / (0.00055 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      if a = 1 then
      begin
      //oberen Punkt des ersten Hängers für spätere Verwendung speichern
      ErstNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
    end;

    //Hänger in Feldmitte
    if Rest > 9 then
    begin
      //unterer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (i * 6.75)+(Rest/2)));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer Kettenwerkpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Ersthaengerabstand + (i * 6.75)+(Rest/2));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      Durchhang := (0.00055 * sqr(Ersthaengerabstand + (i * 6.75) + (Rest/2) - (Abstand/2)) + 1.0) / (0.00055 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
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
    Durchhang := (0.00055 * sqr((Letzthaengerabstand+(a*6.75)) - (Abstand/2)) + 1) / (0.00055 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      if a = 1 then
      begin
      //oberen Punkt des ersten Hängers für spätere Verwendung speichern
      LetztNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
    end;

    // Tragseil-Abschnitte zwischen den Hängern
    for a:=1 to length(ErgebnisArray)-1 do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErgebnisArray[a-1].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[a].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

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
      Durchhang := (0.00055 * sqr(Ersthaengerabstand - (Abstand/2)) + 1.0) / (0.00055 * sqr(Abstand/2) + 1.0);
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
      Durchhang := (0.00055 * sqr((Abstand-Letzthaengerabstand) - (Abstand/2)) + 1.0) / (0.00055 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
      LetztNormalhaengerpunkt:=pktO.PunktTransformiert.Punkt;

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErstNormalhaengerpunkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=LetztNormalhaengerpunkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Endstücke
    if EndstueckA in [Normal] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,Ersthaengerabstand,Abstand,1);
    if EndstueckB in [Normal] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,Letzthaengerabstand,Abstand,-1);
    //Sonderbehandlung für Ausfädelungs-Endstücke (weil es dort offenbar keinen festen Ersthängerabstand gibt):
    if EndstueckA in [Ausfaedel,Abschluss] then
    begin
      //Verbindung zwischen erstem Normalhänger und Ausleger A
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErstNormalhaengerpunkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTA.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

      //ggfs. Isolatoren für Streckentrennung oder Spannwerk einbauen
      if (EndstueckA in [Abschluss]) or ((IsolatorBaumodus = 1) and (EndstueckA = Ausfaedel)) then
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
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=LetztNormalhaengerpunkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTB.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

      //ggfs. Isolatoren für Streckentrennung oder Spannwerk einbauen
      if (EndstueckB in [Abschluss]) or ((IsolatorBaumodus = 1) and (EndstueckB = Ausfaedel)) then
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

    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeFD;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

  end;
end;

procedure Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT:TAnkerpunkt; Ersthaengerabstand,Abstand,Richtung:single);
var pktU, pktO:TAnkerpunkt;
    v, vNorm, vNeu,Endstueckendepunkt: TD3DVector;
    Durchhang:single;
begin
    //Erster Hänger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * Ersthaengerabstand);    //erster Hänger in 4,5 m Abstand vom Ausleger
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * Ersthaengerabstand);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00055 * sqr(4.5 - (Abstand/2)) + 1) / (0.00055 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    EndstueckEndepunkt := pktO.PunktTransformiert.Punkt;
    //Ersthänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ersthänger und Ausleger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktT.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ersthänger und erstem Normalhänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //ggfs. Isolatoren für Streckentrennung einbauen. Streckentrennungen an Nicht-Ausfädelungsendstücken sind eigentlich nicht systemgemäß, aber zusitechnisch notwendig wenn die Trennung im Quertragwerk liegt.
    if IsolatorBaumodus = 1 then
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktT.PunktTransformiert.Punkt, EndstueckEndepunkt, 2, pktT.PunktTransformiert.Punkt, pktT.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktT.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktT.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktF.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, 2, pktF.PunktTransformiert.Punkt, pktF.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktF.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktF.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
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
    LageIsolator(pktDB.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Punkt, (2 * D3DXVec3Length(vDraht))/100, pktDA.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktDA.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktDA.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

  end
end;


procedure KettenwerkAbschluss(Ersthaengerabstand,Letzthaengerabstand:single;AnkommenderAnkertypF,AnkommenderAnkertypT:TAnkerTyp);
var pktFA, pktFB, pktTA, pktTB, pktU, pktO:TAnkerpunkt;
    Abstand, Durchhang, {LaengeNormalhaengerbereich,} Haengerabstand:single;
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
    pktFA:=PunktSuchen(true,  0, AnkommenderAnkertypF);
    pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);

    i:=Math.Ceil((Abstand - Ersthaengerabstand - Letzthaengerabstand)/6.75); //Anders als bei Normalkettenwerk soll hier der letzte Hänger von der Normalhänger-Schleife gebaut werden
    //if odd(i) then i :=i+1; //ungerade Anzahl Normalhänger ist in Re 200 nicht zulässig. Deshalb im Zweifel einen Hänger mehr einbauen.
    //LaengeNormalhaengerbereich := (Abstand - Ersthaengerabstand - Letzthaengerabstand);
    Haengerabstand := (Abstand - Ersthaengerabstand - Letzthaengerabstand)/i; //Anders als bei Normalkettenwerk soll hier der letzte Hänger von der Normalhänger-Schleife gebaut werden
    //ShowMessage( 'Anzahl Hänger '+inttostr(i) + '   Hängerabstand ' + floattostr(Haengerabstand) + '   Längsspannweite ' + floattostr(Abstand) + '   Normalhängerbereich ' + floattostr(LaengeNormalhaengerbereich));

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, AnkommenderAnkertypT);
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
      Durchhang := (0.00055 * sqr(Ersthaengerabstand + (a * Haengerabstand) - (Abstand/2)) + 1.0) / (0.00055 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
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
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      //v:=ErgebnisArray[a].Punkt2;
    end;

    //Verbindung zwischen letztem Normalhänger und Spannwerk an B
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
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
    Durchhang := (0.00055 * sqr(Ersthaengerabstand - (Abstand/2)) + 1.0) / (0.00055 * sqr(Abstand/2) + 1.0);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung zwischen erstem Hänger und erstem Normalhänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung zwischen erstem Hänger und Ausleger A
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;


    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeFD;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

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
  {if (BautypA=Ausfaedel) and (BautypB=Abschluss) then KettenwerkAbschluss(4.5,25.0,Ankertyp_FahrleitungAusfaedelungFahrdraht,Ankertyp_FahrleitungAusfaedelungTragseil);      //Ausfädelung an A, Isolatoren an B; Letzthängerabstand 25,0 m wegen hängerfreiem Seil, Isolatorlänge und Abstand Isolator zu Spannwerk
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
  end; }

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
  Application.Handle:=AppHandle;
  Formular:=TFormFahrleitungConfig.Create(Application);
  Formular.LabeledEditIsolator.Text:=DateiIsolator;
  Formular.RadioGroupKettenwerkstyp.ItemIndex := Kettenwerkstyp;
  Formular.RadioGroupZusatzisolatoren.ItemIndex := IsolatorBaumodus;
  Formular.ShowModal;

  if Formular.ModalResult=mrOK then
  begin
    DateiIsolator:=(Formular.LabeledEditIsolator.Text);
    Kettenwerkstyp:=Formular.RadioGroupKettenwerkstyp.ItemIndex;
    IsolatorBaumodus:=Formular.RadioGroupZusatzisolatoren.ItemIndex;
    RegistrySchreiben;
    RegistryLesen;
  end;

  Application.Handle:=0;
  Formular.Free;
end;

end.
