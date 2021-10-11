unit Re160Berechnung;

interface

uses
  Direct3D9, d3dx9,

  sysutils, Controls, registry, windows, forms, Math, Dialogs,
  
  ZusiD3DTypenDll, FahrleitungsTypen, OLADLLgemeinsameFkt, Re160ConfigForm;

type

  TEndstueck = (y12m, y12mZ, ausfaedel, Festp, FestpIso, Abschluss, SH13_5m, SH13_10m, SH03, SH03Z, Ny10m, Ny10mZ, y12mZqtw, Ny10mZqtw);

function Init:Longword; stdcall;
function BauartTyp(i:Longint):PChar; stdcall;
function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
procedure Berechne_YSeil_12m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY:TAnkerpunkt; Abstand,Richtung: single);
procedure Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY,pktSR:TAnkerpunkt; Ersthaengerabstand,Abstand,Richtung: single; SH13:boolean);
procedure Berechne_Endstueck_SH03(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT:TAnkerpunkt; Abstand,Richtung: single);
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
    StaerkeFD,StaerkeTS,StaerkeHaenger,StaerkeStuetzrohrhaenger,StaerkeYseil,StaerkeBeiseil,StaerkeAnkerseil,StaerkeZseil,YKompFaktor:single;
    Festpunktisolatorposition,IsolatorBaumodus:integer;
    DrahtFarbe:TD3DColorValue;
    BaufunktionAufgerufen:boolean;

procedure RegistryLesen;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\Re160') then
            begin
              if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
              if reg.ValueExists('Festpunktisolatorposition') then Festpunktisolatorposition := reg.ReadInteger('Festpunktisolatorposition');
              if reg.ValueExists('YKompFaktor') then YKompFaktor := reg.ReadFloat('YKompFaktor');
              if reg.ValueExists('IsolatorBaumodus') then IsolatorBaumodus := reg.ReadInteger('IsolatorBaumodus');
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
            if reg.OpenKey('Re160', true) then
            begin
              reg.WriteString('DateiIsolator', DateiIsolator);
              reg.WriteFloat('YKompFaktor',YKompFaktor);
              reg.WriteInteger('Festpunktisolatorposition',Festpunktisolatorposition);
              reg.WriteInteger('IsolatorBaumodus',IsolatorBaumodus);
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
// R�ckgabe: Anzahl der Bauarttypen
begin
  Result:=14;  //muss passen zu den m�glichen R�ckgabewerten der function BauartTyp
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
  YKompFaktor := 1;
  IsolatorBaumodus := 0;
  RegistryLesen;
end;

function BauartTyp(i:Longint):PChar; stdcall;
// Wird vom Editor so oft aufgerufen, wie wir als Result in der init-function �bergeben haben. Enumeriert die Bauart-Typen, die diese DLL kennt 
begin
  case i of
  0: Result:='12m Y-Seil';
  1: Result:='Festpunktabspannung';
  2: Result:='Festpunktabspannung mit Isolator';
  3: Result:='Festpunkt mit 12m Y-Seil';
  4: Result:='Ausf�delung';
  5: Result:='Abschluss mit Isolatoren';
  6: Result:='(SH < 13) Radius �ber 700 m';
  7: Result:='(SH < 13) Radius unter 700 m';
  8: Result:='(SH 03) St�tzpunkt unter Bauwerk';
  9: Result:='(SH 03) Festpunkt mit St�tzpunkt unter Bauwerk';
  10: Result:='ohne Y-Seil (Radius unter 700 m)';
  11: Result:='Festpunkt ohne Y-Seil (Radius unter 700 m)';
  12: Result:='Festpunkt im QTW mit Y-Seil';
  13: Result:='Festpunkt im QTW ohne Y-Seil'
  else Result := '12m Y-Seil'
  end;
end;

function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
// Wir versuchen, aus der vom Editor �bergebenen Ankerkonfiguration einen Bauarttypen vorzuschlagen
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

    //liegt ein Ausf�delungs-Ausleger vor?
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
    if (iUnten2=1) and (iOben2=1) then Result:= 0;

    //liegt ein St�tzpunkt mit niedriger Systemh�he vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungFahrdraht then inc(iUnten3);
      if Punkte[b].Ankertyp=Ankertyp_Tragseildrehklemme then inc(iOben3);
    end;
    if (iUnten3=1) and (iOben3=1) then Result:=6;

  end;

begin
    if A then Result:=Vorschlagen(PunkteA)
         else Result:=Vorschlagen(PunkteB);
end;

procedure Kettenwerk(EndstueckA,EndstueckB:TEndstueck);
var pktFA, pktFB, pktTA, pktTB, pktYA, pktYB, pktSRA, pktSRB, pktU, pktO:TAnkerpunkt;
    Abstand, Durchhang, {LaengeNormalhaengerbereich,} Ersthaengerabstand, Letzthaengerabstand, Haengerabstand, AbstandFT, DurchhangAHaenger, DurchhangBHaenger:single;
    vFahrdraht, vTragseil, v, vNeu, vNorm, ErstNormalhaengerpunkt, LetztNormalhaengerpunkt:TD3DVector;
    i, a:integer;
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
    if EndstueckA in [y12m,y12mZ,y12mZqtw] then Ersthaengerabstand := 2.5;
    if EndstueckB in [y12m,y12mZ,y12mZqtw] then Letzthaengerabstand := 2.5;
    if EndstueckA = Ausfaedel then Ersthaengerabstand := 0;
    if EndstueckB = Ausfaedel then Letzthaengerabstand := 0;
    if EndstueckA in [SH03,SH13_5m] then Ersthaengerabstand := 5; //Bei Kettenwerk zwischen zwei SH03-Auslegern gilt eigentlich Sonderregel f�r die H�ngerabst�nde (1/4 der L�ngsspannweite). Dann landet man allerdings in der Funktion Kettenwerk_SH03. Die Festlegungen hier sind somit nur f�r �bergangskettenwerke relevant.
    if EndstueckB in [SH03,SH13_5m] then Letzthaengerabstand := 5;
    if EndstueckA in [SH13_10m, Ny10m, Ny10mZ, Ny10mZqtw] then Ersthaengerabstand := 10;
    if EndstueckB in [SH13_10m, Ny10m, Ny10mZ, Ny10mZqtw] then Letzthaengerabstand := 10;

    if EndstueckA in [y12mZ,SH03Z,Ny10mZ,y12mZqtw, Ny10mZqtw] then zSeilA := true;
    if EndstueckB in [y12mZ,SH03Z,Ny10mZ,y12mZqtw, Ny10mZqtw] then zSeilB := true;

    pktYA:=PunktSuchen(true, 0, Ankertyp_FahrleitungHaengerseil);
    pktYB:=PunktSuchen(false, 0, Ankertyp_FahrleitungHaengerseil);

    //Bei St�tzpunkten mit niedriger Systemh�he den Anbaupunkt am Spitzenrohr feststellen
    if (EndstueckA in [SH13_5m,SH13_10m]) or (EndstueckB in [SH13_5m,SH13_10m]) then
    begin
      pktSRA:=PunktSuchen(true, 0, Ankertyp_Tragseildrehklemme);
      pktSRB:=PunktSuchen(false, 0, Ankertyp_Tragseildrehklemme);
      if (AnkerIstLeer(pktSRA) and (EndstueckA in [SH13_5m,SH13_10m])) or (AnkerIstLeer(pktSRB) and (EndstueckB in [SH13_5m,SH13_10m])) then
      begin
        ShowMessage('Ein notwendiger Ankerpunkt des Typs Tragseildrehklemme ist nicht vorhanden.');
        exit; //Abbruch, weil ansonsten entartete Fahrdr�hte entstehen
      end;
    end;

    //Bei Festpunkten am QTW den Anbaupunkt f�r die Zusatzh�nger am Seitenhalter feststellen
    if (EndstueckA in [y12mZqtw, Ny10mZqtw]) or (EndstueckB in [y12mZqtw, Ny10mZqtw]) then
    begin
      pktSRA:=PunktSuchen(true, 0, Ankertyp_Stuetzrohrhaenger);
      pktSRB:=PunktSuchen(false, 0, Ankertyp_Stuetzrohrhaenger);
      if (AnkerIstLeer(pktSRA) and (EndstueckA in [y12mZqtw, Ny10mZqtw])) or (AnkerIstLeer(pktSRB) and (EndstueckB in [y12mZqtw, Ny10mZqtw])) then
      begin
        ShowMessage('Ein notwendiger Ankerpunkt des Typs St�tzrohrh�nger ist nicht vorhanden.');
        exit; //Abbruch, weil ansonsten entartete Fahrdr�hte entstehen
      end;
    end;

    //Fahrdraht berechnen als Vektor von FA nach FB
    if EndstueckA = Ausfaedel then pktFA:=PunktSuchen(true, 0, Ankertyp_FahrleitungAusfaedelungFahrdraht)
    else pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungFahrdraht);
    if EndstueckB = Ausfaedel then pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAusfaedelungFahrdraht)
    else pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);

    //Spannweite auf Plausibilit�t pr�fen
    if (EndstueckA in [y12m,y12mZ,y12mZqtw]) and (EndstueckB in [y12m,y12mZ,y12mZqtw]) then
      begin
        //if (Abstand < 34) or (Abstand > 50.5) then ShowMessage(floattostr(Math.RoundTo(Abstand,-2)) + ' m L�ngsspannweite liegt au�erhalb der zul�ssigen Grenzen bei St�tzpunkten im Tunnel (max. 50 m).'); //Aufgrund m�glicher Ungenauigkeiten der Maststandorte in Zusi geben wir einen halben Meter Toleranz
      end;
    if not ((EndstueckA in [SH03,SH03Z,y12m,y12mZ,y12mZqtw,Ny10mZqtw]) or (EndstueckB in [SH03,SH03Z,y12m,y12mZ,y12mZqtw,Ny10mZqtw])) then
      begin
        if (Abstand < 34) or (Abstand > 80.5) then ShowMessage(floattostr(Math.RoundTo(Abstand,-2)) + ' m L�ngsspannweite liegt au�erhalb der zul�ssigen Grenzen der Bauart Re 160 (34 bis 80 m).'); //Aufgrund m�glicher Ungenauigkeiten der Maststandorte in Zusi geben wir einen halben Meter Toleranz
      end;

    i:=Math.Ceil((Abstand - Ersthaengerabstand - Letzthaengerabstand)/12.5) - 1;    //max. H�ngerabstand in der Bauart Re 160 ist 12,5 m
    //if odd(i) then i :=i+1; //f�r Bauarten bei denen ungerade H�ngerzahl unzul�ssig ist, im Zweifel einen H�nger mehr einbauen.

    //LaengeNormalhaengerbereich := (Abstand - Ersthaengerabstand - Letzthaengerabstand);
    Haengerabstand := (Abstand - Ersthaengerabstand - Letzthaengerabstand)/(i+1);
    //ShowMessage( 'Anzahl H�nger '+inttostr(i) + '   H�ngerabstand ' + floattostr(Haengerabstand) + '   L�ngsspannweite ' + floattostr(Abstand) + '   Normalh�ngerbereich ' + floattostr(LaengeNormalhaengerbereich));

    //Tragseil Endpunkte
    if EndstueckA = Ausfaedel then pktTA:=PunktSuchen(true, 0, Ankertyp_FahrleitungAusfaedelungTragseil)
    else pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungTragseil);
    if EndstueckB = Ausfaedel then pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAusfaedelungTragseil)
    else pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);

    //Systemh�hen-Pr�fung
    if not (EndstueckA in [SH13_5m,SH13_10m,y12m,y12mZ,SH03,SH03Z,y12mZqtw,Ny10mZqtw]) then
    begin
      D3DXVec3Subtract(v, pktTA.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
      if (D3DXVec3Length(v) < 1.3) then ShowMessage('Systemh�he am Ausleger A liegt au�erhalb der zul�ssigen Grenzen (minimal 1,30 m).');
    end;
    if not (EndstueckB in [SH13_5m,SH13_10m,y12m,y12mZ,SH03,SH03Z,y12mZqtw,Ny10mZqtw]) then
    begin
      D3DXVec3Subtract(v, pktTB.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt);
      if (D3DXVec3Length(v) < 1.3) then ShowMessage('Systemh�he am Ausleger B liegt au�erhalb der zul�ssigen Grenzen (minimal 1,30 m).');
    end;

    //Normalh�nger
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
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      if a = 1 then
      begin
      //oberen Punkt des ersten H�ngers f�r sp�tere Verwendung speichern
      ErstNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
      if a = (i) then
      begin
      //oberen Punkt des letzten H�ngers f�r sp�tere Verwendung speichern
      LetztNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
      if (a = (i/2)) and (zSeilA or zSeilB) then
      begin
        //Abstand zwischen Fahrdraht und Tragseil sowie Durchhang f�r  sp�tere Verwendung speichern
        if zSeilA then
        begin
        D3DXVec3Subtract(v, pktU.PunktTransformiert.Punkt, pktO.PunktTransformiert.Punkt);
        AbstandFT:=D3DXVec3Length(v);
        end;
        DurchhangAHaenger := Durchhang;
      end;
      if (a = (i/2) + 1) and (zSeilA or zSeilB) then
      begin
        //Abstand zwischen Fahrdraht und Tragseil sowie Durchhang f�r  sp�tere Verwendung speichern
        if zSeilB then
        begin
        D3DXVec3Subtract(v, pktU.PunktTransformiert.Punkt, pktO.PunktTransformiert.Punkt);
        AbstandFT:=D3DXVec3Length(v);
        end;
        DurchhangBHaenger := Durchhang;
      end;
    end;


    // Tragseil-Abschnitte zwischen den H�ngern
    for a:=1 to length(ErgebnisArray)-1 do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErgebnisArray[a-1].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[a].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;


    //Y-Seile und Endst�cke
    if EndstueckA in [y12m,y12mZ,y12mZqtw] then Berechne_YSeil_12m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,pktYA,Abstand,1);
    if EndstueckB in [y12m,y12mZ,y12mZqtw] then Berechne_YSeil_12m(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,pktYB,Abstand,-1);
    if EndstueckA in [SH13_5m] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,pktYA,pktSRA,5,Abstand,1,true);
    if EndstueckB in [SH13_5m] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,pktYB,pktSRB,5,Abstand,-1,true);
    if EndstueckA in [SH13_10m] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,pktYA,pktSRA,10,Abstand,1,true);
    if EndstueckB in [SH13_10m] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,pktYB,pktSRB,10,Abstand,-1,true);
    if EndstueckA in [Ny10m,Ny10mZ,Ny10mZqtw] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,pktYA,pktSRA,10,Abstand,1,false);
    if EndstueckB in [Ny10m,Ny10mZ,Ny10mZqtw] then Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,pktYB,pktSRB,10,Abstand,-1,false);
    if EndstueckA in [SH03,SH03Z] then Berechne_Endstueck_SH03(vFahrdraht,vTragseil,ErstNormalhaengerpunkt,pktFA,pktTA,Abstand,1);
    if EndstueckB in [SH03,SH03Z] then Berechne_Endstueck_SH03(vFahrdraht,vTragseil,LetztNormalhaengerpunkt,pktFB,pktTB,Abstand,-1);
    if EndstueckA = Ausfaedel then
    begin
      //Verbindung zwischen erstem Normalh�nger und Ausleger A
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErstNormalhaengerpunkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTA.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

      //ggfs. Isolatoren f�r Streckentrennung einbauen
      if IsolatorBaumodus = 2 then
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
    if EndstueckB = Ausfaedel then
    begin
      //Verbindung zwischen letztem Normalh�nger und Ausleger B
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=LetztNormalhaengerpunkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktTB.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

      //ggfs. Isolatoren f�r Streckentrennung einbauen
      if IsolatorBaumodus = 2 then
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

    //Z-Seil
    if zSeilA then
    begin
      //unterer vorl�ufiger z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + ((i/2) * Haengerabstand) + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, Ersthaengerabstand + ((i/2) * Haengerabstand + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      //Durchhang := (0.00076 * sqr(Ersthaengerabstand + ((i/2) * Haengerabstand + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2) - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0); //Bei dieser Rechenmethode ergibt sich eine leichte Unexaktheit, da wir hier einen etwas anderen Durchhangwert ermitteln als beim Bau der n�chstliegenden Normalh�nger
      Durchhang := (0.67 * DurchhangAHaenger + 0.33 * DurchhangBHaenger); //gewichteter Durchschnitt des Durchhangs der beiden benachbarten H�nger
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      //endg�ltiger unterer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + ((i/2) * Haengerabstand) + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2) + (sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))); //L�nge des z-Seils muss das F�nffache des Abstands zwischen Fahrdraht und Tragseil sein
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeZseil;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;
    if zSeilB then
    begin
      //unterer vorl�ufiger z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (((i/2)+1) * Haengerabstand) - (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + (((i/2)+1) * Haengerabstand) - (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      //Durchhang := (0.00076 * sqr(Ersthaengerabstand + ((i/2) * Haengerabstand + (Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2) - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0); //Bei dieser Rechenmethode ergibt sich eine leichte Unexaktheit, da wir hier einen etwas anderen Durchhangwert ermitteln als beim Bau der n�chstliegenden Normalh�nger
      Durchhang := (0.33 * DurchhangAHaenger + 0.67 * DurchhangBHaenger); //gewichteter Durchschnitt des Durchhangs der beiden benachbarten H�nger
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      //endg�ltiger unterer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, (Ersthaengerabstand + ((i/2)+1) * Haengerabstand) - ((Haengerabstand - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2 + sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))); //L�nge des z-Seils muss das F�nffache des Abstands zwischen Fahrdraht und Tragseil sein
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeZseil;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    if EndstueckA in [y12mZqtw, Ny10mZqtw] then //Zusatzarbeiten bei Festpunkt im Querfeld
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktTA.PunktTransformiert.Punkt, ErstNormalhaengerpunkt, 0, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

      //Zusatzh�nger zwischen Isolator und Seitenhalter
      D3DXVec3Subtract(v, ErstNormalhaengerpunkt,pktTA.PunktTransformiert.Punkt);
      D3DXVec3Normalize(vNorm, v);
      D3DXVec3Scale(v, vNorm, 1 * 0.6); //H�nger 0,6 m vom St�tzpunkt entfernt
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      Durchhang := (0.00076 * sqr(0.6 - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktSRA.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    if EndstueckB in [y12mZqtw, Ny10mZqtw] then //Zusatzarbeiten bei Festpunkt im Querfeld
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktTB.PunktTransformiert.Punkt, LetztNormalhaengerpunkt, 0, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel);
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

      //Zusatzh�nger zwischen Isolator und Seitenhalter
      D3DXVec3Subtract(v, pktTB.PunktTransformiert.Punkt,LetztNormalhaengerpunkt);
      D3DXVec3Normalize(vNorm, v);
      D3DXVec3Scale(v, vNorm, -1 * 0.6); //H�nger 0,6 m vom St�tzpunkt entfernt
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTB.PunktTransformiert.Punkt, v);

      Durchhang := (0.00076 * sqr(0.6 - (Abstand/2)) + 1.0) / (0.00076 * sqr(Abstand/2) + 1.0);
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktSRB.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;


    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeFD;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

  end;
end;

procedure Berechne_YSeil_12m(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY:TAnkerpunkt; Abstand,Richtung:single);
var pktU, pktO:TAnkerpunkt;
    v, vNorm, vNeu, YSeilErsthaengerpunkt,YSeilEndepunkt: TD3DVector;
    Durchhang:single;
begin
    //Erster H�nger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 2.5);    //erster H�nger in 2,5 m Abstand vom Ausleger
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 2.5);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    if Richtung = -1 then D3DXVec3Scale(vNeu, v, 0.50 * YKompFaktor) else  D3DXVec3Scale(vNeu, v, 0.50); //H�nger auf 50% H�he zwischen Fahrdraht und Tragseil (lt. Ezs 476)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilErsthaengerpunkt := pktO.PunktTransformiert.Punkt;
    //Array[0]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung im Y-Seil zwischen Ersth�nger und Nullpunkt am Ausleger
    //oberer Kettenwerkpunkt
    //Punkt absenken
    D3DXVec3Subtract(v, pktT.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt);
    if Richtung = -1 then D3DXVec3Scale(vNeu, v, 0.47 * YKompFaktor) else D3DXVec3Scale(vNeu, v, 0.47); //47% H�he zwischen Fahrdraht und Tragseil (lt. Ezs 476)
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, vNeu);
    //Array[3]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilErsthaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeYseil;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Anbindung Y-Seil an den Ausleger, unter Nutzung des f�r Array[3] berechneten Punkts
    //Array[4]
    if not AnkerIstLeer(pktY) then
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktY.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Tragseil zwischen Ende Y-Seil und Ausleger
    //unterer Kettenwerkpunkt (nur virtuell, f�r Berechnungszwecke)
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 6);
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 6);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr(6 - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    YSeilEndepunkt := pktO.PunktTransformiert.Punkt;
    //Array[5]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktT.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Isolator ins Tragseil einbauen (dieses Y-Seil wird nicht in Quertragwerken verwendet)
    if IsolatorBaumodus = 1 then
    begin
      setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
      LageIsolator(pktT.PunktTransformiert.Punkt, YSeilEndepunkt, 0.6, pktT.PunktTransformiert.Punkt, pktT.PunktTransformiert.Winkel); //geerdeter Ausleger - Isolator 0,6 m vom St�tzpunkt entfernt
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktT.PunktTransformiert.Punkt;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktT.PunktTransformiert.Winkel;
      ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
    end;

    //Verbindung zwischen Ende Y-Seil und Ersth�nger
    //Array[6]
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilErsthaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeYseil;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ende Y-Seil und erstem Normalh�nger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=YSeilEndepunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
end;

procedure Berechne_Endstueck_SH03(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT:TAnkerpunkt; Abstand,Richtung:single); //nur f�r �bergangskettenwerk
var pktU, pktO:TAnkerpunkt;
    v, vNorm, vNeu: TD3DVector;
    Durchhang:single;
begin
    //Erster H�nger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 5);    //erster H�nger in 5,0 m Abstand zum St�tzpunkt
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 5);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr(5 - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    //Ersth�nger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ersth�nger und Ausleger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktT.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ersth�nger und erstem Normalh�nger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
end;

procedure Berechne_Endstueck_OhneY(vFahrdraht,vTragseil,ErstNormalhaengerpunkt:TD3DVector; pktF,pktT,pktY,pktSR:TAnkerpunkt; Ersthaengerabstand,Abstand,Richtung:single; SH13:boolean);
var pktU, pktO:TAnkerpunkt;
    v, vNorm, vNeu,Endstueckendepunkt: TD3DVector;
    Durchhang,h:single;
begin
    D3DXVec3Subtract(v, pktSR.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt);
    h := D3DXVec3Length(v);

    //Erster H�nger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * Ersthaengerabstand);    //erster H�nger in 5 bzw. 10 m Abstand vom Ausleger
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * Ersthaengerabstand);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr(5 - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    EndstueckEndepunkt := pktO.PunktTransformiert.Punkt;
    //Ersth�nger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ersth�nger und Ausleger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktT.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ersth�nger und erstem Normalh�nger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    if SH13 then  //Zusatzarbeiten bei St�tzpunkten mit niedriger Systemh�he
    begin
    //Seil am Ausleger zwischen Spitzenrohr und Y-Seil-Anbaupunkt (wird nur bei Auslegern in Altbauweise ben�tigt und soll dort den im 3D-Modell fehlenden St�tzrohrh�nger andeuten)
    if not AnkerIstLeer(pktY) then
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktY.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktSR.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeStuetzrohrhaenger;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Beiseil am St�tzpunkt
    //unterer Kettenwerkpunkt (nur als Rechengr��e)
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Richtung * 2 * h); //Beiseil wird in Entfernung 2 * h vom St�tzpunkt angebracht
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktF.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Richtung * 2 * h);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktT.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr(2 * h - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

    //Seil eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktSR.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeBeiseil;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
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
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=0.0045; //Bronzeseil 50/7, abweichend von der Standard-Drahtst�rke der DLL
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Isolator auf dem Festpunktseil
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktDB.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Punkt, (Festpunktisolatorposition * D3DXVec3Length(vDraht))/100, pktDA.PunktTransformiert.Punkt, pktDA.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktDA.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktDA.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

  end
end;

procedure Kettenwerk_SH03(zSeil:boolean); //Behandlung als Sonderfall, weil es hierbei keine Normalh�nger gibt
var pktFA, pktFB, pktTA, pktTB, pktU, pktO:TAnkerpunkt;
    v,vNorm,vNeu,vFahrdraht,vTragseil,HaengerAPunkt: TD3DVector;
    Abstand, AbstandFT, Durchhang:single;
begin
  DrahtFarbe.r:=0.99;
  DrahtFarbe.g:=0.99;
  DrahtFarbe.b:=0.99;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>1) and (length(PunkteB)>1) then
  begin
    BaufunktionAufgerufen := true;
    //Fahrdraht berechnen als Vektor von FA nach FB
    pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungFahrdraht);
    pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);

    //Spannweite auf Plausibilit�t pr�fen
    if (Abstand > 25.5) then ShowMessage(floattostr(Math.RoundTo(Abstand,-2)) + ' m L�ngsspannweite liegt au�erhalb der zul�ssigen Grenzen bei St�tzpunkten unter Bauwerken (max. 25 m).'); //Aufgrund m�glicher Ungenauigkeiten der Maststandorte in Zusi geben wir einen halben Meter Toleranz

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungTragseil);
    pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);

    //Systemh�hen-Pr�fung
    D3DXVec3Subtract(v, pktTA.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    if (D3DXVec3Length(v) > 0.3) then ShowMessage('Systemh�he am Ausleger A liegt au�erhalb der zul�ssigen Grenzen (minimal 0,30 m).');
    D3DXVec3Subtract(v, pktTB.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt);
    if (D3DXVec3Length(v) > 0.3) then ShowMessage('Systemh�he am Ausleger B liegt au�erhalb der zul�ssigen Grenzen (minimal 0,30 m).');

    //Erster H�nger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, Abstand / 4);    //H�nger in Abstand 1/4 L�ngsspannweite vom Ausleger
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, Abstand / 4);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr((Abstand/4) - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
    HaengerAPunkt := pktO.PunktTransformiert.Punkt;
    //Abstand Fahrdraht zu Tragseil f�r Verwendung im Z-Seil speichern
    AbstandFT:=D3DXVec3Length(vNeu);

    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ersth�nger und Ausleger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Zweiter H�nger
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, -1 * Abstand / 4);    //H�nger in Abstand 1/4 L�ngsspannweite vom Ausleger
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vTragseil);
    D3DXVec3Scale(v, vNorm, -1 * Abstand / 4);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTB.PunktTransformiert.Punkt, v);

    //Punkt absenken
    Durchhang := (0.00076 * sqr((Abstand/4) - (Abstand/2)) + 1) / (0.00076 * sqr(Abstand/2) + 1);
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, Durchhang);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Zweithaenger und Ausleger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Tragseil zwischen Ersth�nger und Zweith�nger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=HaengerAPunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Z-Seil
    if zSeil then
    begin
      //unterer vorl�ufiger z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, ((Abstand / 4) + ((Abstand / 2) - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vTragseil);
      D3DXVec3Scale(v, vNorm, ((Abstand / 4) + ((Abstand / 2)  - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, Durchhang);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      //endg�ltiger unterer z-Seilpunkt
      D3DXVec3Normalize(vNorm, vFahrdraht);
      D3DXVec3Scale(v, vNorm, ((Abstand / 4) + ((Abstand / 2) - sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))/2) + (sqrt(sqr(5*AbstandFT)-sqr(AbstandFT)))); //L�nge des z-Seils muss das F�nffache des Abstands zwischen Fahrdraht und Tragseil sein
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeZseil;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeFD;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

  end;

end;

procedure KettenwerkAbschluss(Ersthaengerabstand,Letzthaengerabstand:single);
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
    pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungAusfaedelungFahrdraht);
    pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);

    i:=Math.Ceil((Abstand - Ersthaengerabstand - Letzthaengerabstand)/12.5); //Anders als bei Normalkettenwerk soll hier der letzte H�nger von der Normalh�nger-Schleife gebaut werden
    //if odd(i) then i :=i+1; //ungerade Anzahl Normalh�nger ist in Re 200 nicht zul�ssig. Deshalb im Zweifel einen H�nger mehr einbauen.
    //LaengeNormalhaengerbereich := (Abstand - Ersthaengerabstand - Letzthaengerabstand);
    Haengerabstand := (Abstand - Ersthaengerabstand - Letzthaengerabstand)/i; //Anders als bei Normalkettenwerk soll hier der letzte H�nger von der Normalh�nger-Schleife gebaut werden
    //ShowMessage( 'Anzahl H�nger '+inttostr(i) + '   H�ngerabstand ' + floattostr(Haengerabstand) + '   L�ngsspannweite ' + floattostr(Abstand) + '   Normalh�ngerbereich ' + floattostr(LaengeNormalhaengerbereich));

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungAusfaedelungTragseil);
    pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAbspannungMastpunktTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);


    //Normalh�nger
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
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      if a = 1 then
      begin
      //oberen Punkt des ersten H�ngers f�r sp�tere Verwendung speichern
      ErstNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
      if a = (i) then
      begin
      //oberen Punkt des letzten H�ngers f�r sp�tere Verwendung speichern
      LetztNormalhaengerpunkt := pktO.PunktTransformiert.Punkt;
      end;
    end;


    // Tragseil-Abschnitte zwischen den H�ngern
    for a:=1 to length(ErgebnisArray)-1 do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErgebnisArray[a-1].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[a].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      //v:=ErgebnisArray[a].Punkt2;
    end;

    //Verbindung zwischen letztem Normalh�nger und Spannwerk an B
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


    //erster  H�nger
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
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeHaenger;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung zwischen erstem H�nger und erstem Normalh�nger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErstNormalhaengerpunkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=StaerkeTS;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Verbindung zwischen erstem H�nger und Ausleger A
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
// Der Benutzer hat auf 'Ausf�hren' geklickt.
// R�ckgabe: Anzahl der Linien
var BautypA, BautypB : TEndstueck;

begin
  //zun�chst nochmal Grundzustand herstellen
  setlength(ErgebnisArray, 0);
  setlength(ErgebnisArrayDateien, 0);
  BaufunktionAufgerufen := false;

  //�bersetzung zwischen den von Zusi �bergebenen Longints und unseren Bautypen
  case Typ1 of
    0: BautypA := y12m;
    1: BautypA := Festp;
    2: BautypA := FestpIso;
    3: BautypA := y12mZ;
    4: BautypA := Ausfaedel;
    5: BautypA := Abschluss;
    6: BautypA := SH13_5m;
    7: BautypA := SH13_10m;
    8: BautypA := SH03;
    9: BautypA := SH03Z;
    10: BautypA := Ny10m;
    11: BautypA := Ny10mZ;
    12: BautypA := y12mZqtw;
    13: BautypA := Ny10mZqtw
  end;
    case Typ2 of
    0: BautypB := y12m;
    1: BautypB := Festp;
    2: BautypB := FestpIso;
    3: BautypB := y12mZ;
    4: BautypB := Ausfaedel;
    5: BautypB := Abschluss;
    6: BautypB := SH13_5m;
    7: BautypB := SH13_10m;
    8: BautypB := SH03;
    9: BautypB := SH03Z;
    10: BautypB := Ny10m;
    11: BautypB := Ny10mZ;
    12: BautypB := y12mZqtw;
    13: BautypB := Ny10mZqtw
  end;

  //hier wird entschieden was wir machen. Zuerst die Sonderf�lle:
  if (BautypA=SH03) and (BautypB=SH03) then Kettenwerk_SH03(false); //beide Ausleger St�tzpunkt unter Bauwerk, Behandlung als Sonderfall da abweichende H�ngerteilung
  if (BautypA=SH03Z) and (BautypB=SH03) then Kettenwerk_SH03(true); //beide Endst�cke SH03, z-Seil an A
  if (BautypA=SH03) and (BautypB=SH03Z) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei z-Seil nicht seitenneutral ist
    BaurichtungWechseln;
    Kettenwerk_SH03(true);
  end;
  if (BautypA=Festp) and (BautypB=FestpIso) then Festpunktabspannung;
  if (BautypA=FestpIso) and (BautypB=Festp) then
  begin //Arrays durchtauschen, da die Bau-Procedure nicht seitenneutral ist
    BaurichtungWechseln;
    Festpunktabspannung;
  end;
  if (BautypA=Ausfaedel) and (BautypB=Abschluss) then KettenwerkAbschluss(0.5,25.0);      //Ausf�delung an A, Isolatoren an B; Letzth�ngerabstand 25,0 m wegen h�ngerfreiem Seil, Isolatorl�nge und Abstand Isolator zu Spannwerk
  if (BautypA=Abschluss) and (BautypB=Ausfaedel) then
  begin //Arrays durchtauschen, da die Bau-Procedure bei Abschl�ssen nicht seitenneutral ist
    BaurichtungWechseln;
    KettenwerkAbschluss(0.5,22.8);
  end;

  //einige unsinnige Kombinationen abfangen
  if (BautypA in [Festp,FestpIso]) and (BautypB in [y12m, y12mZ, ausfaedel, Abschluss, SH13_5m, SH13_10m, SH03, SH03Z, y12mZqtw, Ny10mZqtw]) then BaufunktionAufgerufen := true;
  if (BautypA in [y12m, y12mZ, ausfaedel, Abschluss, SH13_5m, SH13_10m, SH03, SH03Z, y12mZqtw, Ny10mZqtw]) and (BautypB in [Festp,FestpIso]) then BaufunktionAufgerufen := true;
  if (BautypA in [Abschluss]) and (BautypB in [y12m, y12mZ, Abschluss, SH13_5m, SH13_10m, SH03, SH03Z, y12mZqtw, Ny10mZqtw]) then BaufunktionAufgerufen := true;
  if (BautypA in [y12m, y12mZ, Abschluss, SH13_5m, SH13_10m, SH03, SH03Z, y12mZqtw, Ny10mZqtw]) and (BautypB in [Abschluss]) then BaufunktionAufgerufen := true;

  //Der catch-all f�r alle sonstigen Kombinationen (hoffentlich nur sinnvolle);
  if not BaufunktionAufgerufen then Kettenwerk(BautypA,BautypB);

  if not BaufunktionAufgerufen then ShowMessage('Die gew�hlte Bauart-Kombination ist nicht implementiert. Bei tats�chlichem Bedarf bitte beim Autor der DLL melden.');

  Result.iDraht:=length(ErgebnisArray);
  Result.iDatei:=length(ErgebnisArrayDateien);
end;


function Bezeichnung:PChar; stdcall;
begin
  Result:='Re 160'
end;

function Gruppe:PChar; stdcall;
// Teilt dem Editor die Objektgruppe mit, die er bei den verkn�pften Dateien vermerken soll
begin
  Result:='Kettenwerk Re 160';
end;

procedure Config(AppHandle:HWND); stdcall;
var Formular:TFormFahrleitungConfig;
begin
  Application.Handle:=AppHandle;
  Formular:=TFormFahrleitungConfig.Create(Application);
  Formular.LabeledEditIsolator.Text:=DateiIsolator;
  Formular.TrackBarFestpunktisolator.Position := Festpunktisolatorposition;
  if YKompFaktor <> 1 then Formular.CheckBoxYKompatibilitaet.Checked := true;
  Formular.RadioGroupZusatzisolatoren.ItemIndex := IsolatorBaumodus;
  
  Formular.ShowModal;

  if Formular.ModalResult=mrOK then
  begin
    DateiIsolator:=(Formular.LabeledEditIsolator.Text);
    IsolatorBaumodus:=Formular.RadioGroupZusatzisolatoren.ItemIndex;
    Festpunktisolatorposition := Formular.TrackBarFestpunktisolator.Position;
    if Formular.CheckBoxYKompatibilitaet.Checked = true then YKompFaktor := 1.325 else YKompFaktor := 1;
    RegistrySchreiben;
    RegistryLesen;
  end;

  Application.Handle:=0;
  Formular.Free;
end;

end.
