unit Fahrleitungsberechnung;

interface

uses
  Direct3D9, d3dx9, 
  
  sysutils, Controls, registry, windows, forms, Math,
  
  ZusiD3DTypenDll, OLADLLgemeinsameFkt, FahrleitungsTypen, FahrleitungConfigForm;

function Init:Longword; stdcall;
function BauartTyp(i:Longint):PChar; stdcall;
function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
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

uses Classes;

var DateiIsolator:string;
    Drahtstaerke,Ersthaengerabstand,MaxHaengerabstand:single;
    Drahtkennzahl, Haengerkennzahl:integer;


procedure RegistryLesen;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\Re160ErweiterteFunktionen') then
            begin
              if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
              if reg.ValueExists('DrahtStaerke') then
              begin
                Drahtkennzahl:=reg.ReadInteger('DrahtStaerke');
                case Drahtkennzahl of
                0: Drahtstaerke := 0.015;  // Zusis Standard-Drahtstärke
                1: Drahtstaerke := 0.0074;   // Draht Ri 150
                2: Drahtstaerke := 0.006;  // Draht Ri 100
                end;
              end;
              if reg.ValueExists('Haengerteilung') then
              begin
                Haengerkennzahl:=reg.ReadInteger('Haengerteilung');
                case Haengerkennzahl of
                0:  begin Ersthaengerabstand:= 2.5; MaxHaengerabstand := 12.50 end;
                1:  begin Ersthaengerabstand:= 5.0; MaxHaengerabstand := 11.67 end;
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
            if reg.OpenKey('Re160ErweiterteFunktionen', true) then
            begin
              reg.WriteString('DateiIsolator', DateiIsolator);
              reg.WriteInteger('Drahtstaerke',Drahtkennzahl);
              reg.WriteInteger('Haengerteilung',Haengerkennzahl);
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
  Result:=3;  //muss passen zu den möglichen Rückgabewerten der function BauartTyp
  Reset(true);
  Reset(false);
  DateiIsolator:='Catenary\Deutschland\Einzelteile_Re75-200\Isolator.lod.ls3';
  Drahtkennzahl:=0;
  Haengerkennzahl:=0;
  Drahtstaerke:=0.015;
  Ersthaengerabstand:=2.5;
  MaxHaengerabstand:=12.5;
  RegistryLesen;
end;

function BauartTyp(i:Longint):PChar; stdcall;
// Wird vom Editor so oft aufgerufen, wie wir als Result in der init-function übergeben haben. Enumeriert die Bauart-Typen, die diese DLL kennt 
begin
  case i of
  0: Result:='Abschluß mit Isolatoren';
  1: Result:='Ausfädelung mit Isolatoren';
  2: Result:='Ohne Y-Beiseil'
  else Result := 'Ohne Y-Beiseil'
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
    if (iUnten0=1) and (iOben0=1) then Result:=0;

    //liegt ein Ausfädelungs-Ausleger vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungFahrdraht then inc(iUnten1);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungAusfaedelungTragseil then inc(iOben1);
    end;
    if (iUnten1=1) and (iOben1=1) then Result:=1;

    //liegt ein Standard-Ausleger vor?
    for b:=0 to length(Punkte)-1 do
    begin
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungFahrdraht then inc(iUnten2);
      if Punkte[b].Ankertyp=Ankertyp_FahrleitungTragseil then inc(iOben2);
    end;
    if (iUnten2=1) and (iOben2=1) then Result:=2;


  end;

begin
  if A then Result:=Vorschlagen(PunkteA)
       else Result:=Vorschlagen(PunkteB);
end;


procedure KettenwerkAusfaedelungMitIsolator;
var pktFA, pktFB, pktTA, pktTB, pktU, pktO, pktOErsterHaenger, pktOLetzterHaenger:TAnkerpunkt;
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
    {
     TODO: Vorbildgerechte Hängerteilungen.
     Re 330: 1. Hänger 5,0 m vom Stützpunkt; sonst  9,17 m
     Re 250: wie Re 330
     Re 200: 1. Hänger 2,5 m vom Stützpunkt; 2. Hänger 6,0 m vom Stützpunkt; sonst 11,50 m
     Re 160: 1. Hänger 2,5 m vom Stützpunkt; sonst 12,50 m
     Re 100: 1. Hänger 5,0 m vom Stützpunkt; sonst 11,67 m
     Re 75 : wie Re 100
    }
    i:=round(Abstand/12.5+0.5);

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

      //Punkt absenken
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, 0.75/Durchhang+Durchhang*Sqr((a-0.5)/(i)-0.5));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
      if a = 1 then pktOErsterHaenger.PunktTransformiert.Punkt := pktO.PunktTransformiert.Punkt;
      if a = i then pktOLetzterHaenger.PunktTransformiert.Punkt := pktO.PunktTransformiert.Punkt;

      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;


    // Tragseil-Abschnitte zwischen den Hängern
    for a:=1 to length(ErgebnisArray)-1 do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErgebnisArray[a-1].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[a].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      v:=ErgebnisArray[a].Punkt2;
    end;
    // Tragseil-Abschnitte vom Ausleger zum ersten bzw. letzten Hänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[0].Punkt2;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=v;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Isolator an der Ausfädelung unten
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, 2.5, pktU.PunktTransformiert.Punkt, pktU.PunktTransformiert.Winkel); //Streckentrennungs-Isolator 2,5 m vom Stützpunkt entfernt
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //Isolator an der Ausfädelung oben
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktTB.PunktTransformiert.Punkt, pktOLetzterHaenger.PunktTransformiert.Punkt, 2.5, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel); //Streckentrennungs-Isolator 2,5 m vom Stützpunkt entfernt
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //Isolator am Radspannwerk oben
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktTA.PunktTransformiert.Punkt, pktOErsterHaenger.PunktTransformiert.Punkt, 2, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //Isolator am Radspannwerk unten
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktFA.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt, 2, pktU.PunktTransformiert.Punkt, pktU.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

  end
end;

procedure KettenwerkStandardAufAusfaedelungMitIsolator;
var pktFA, pktFB, pktTA, pktTB, pktU, pktO, pktOErsterHaenger, pktOLetzterHaenger:TAnkerpunkt;
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
    pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungFahrdraht);
    pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungAusfaedelungFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);
    {
     TODO: Vorbildgerechte Hängerteilungen.
     Re 330: 1. Hänger 5,0 m vom Stützpunkt; sonst  9,17 m
     Re 250: wie Re 330
     Re 200: 1. Hänger 2,5 m vom Stützpunkt; 2. Hänger 6,0 m vom Stützpunkt; sonst 11,50 m
     Re 160: 1. Hänger 2,5 m vom Stützpunkt; sonst 12,50 m
     Re 100: 1. Hänger 5,0 m vom Stützpunkt; sonst 11,67 m
     Re 75 : wie Re 100
    }
    i:=round(Abstand/12.5+0.5);

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungTragseil);
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

      //Punkt absenken
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, 0.75/Durchhang+Durchhang*Sqr((a-0.5)/(i)-0.5));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);
      if a = 1 then pktOErsterHaenger.PunktTransformiert.Punkt := pktO.PunktTransformiert.Punkt;
      if a = i then pktOLetzterHaenger.PunktTransformiert.Punkt := pktO.PunktTransformiert.Punkt;

      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;


    // Tragseil-Abschnitte zwischen den Hängern
    for a:=1 to length(ErgebnisArray)-1 do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErgebnisArray[a-1].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[a].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      v:=ErgebnisArray[a].Punkt2;
    end;
    // Tragseil-Abschnitte vom Ausleger zum ersten bzw. letzten Hänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[0].Punkt2;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=v;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Fahrdraht eintragen
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktFA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktFB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    //Isolator an der Ausfädelung unten
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, 2.5, pktU.PunktTransformiert.Punkt, pktU.PunktTransformiert.Winkel);  //Streckentrennungs-Isolator 2,5 m vom Stützpunkt entfernt
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

    //Isolator an der Ausfädelung oben
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktTB.PunktTransformiert.Punkt, pktOLetzterHaenger.PunktTransformiert.Punkt, 2.5, pktO.PunktTransformiert.Punkt, pktO.PunktTransformiert.Winkel); //Streckentrennungs-Isolator 2,5 m vom Stützpunkt entfernt
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktO.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktO.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);

  end
end;

procedure KettenwerkOhneYSeil;
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
    pktFA:=PunktSuchen(true,  0, Ankertyp_FahrleitungFahrdraht);
    pktFB:=PunktSuchen(false, 0, Ankertyp_FahrleitungFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
    Abstand:=D3DXVec3Length(vFahrdraht);
    {
     TODO: Vorbildgerechte Hängerteilungen.
     Re 330: 1. Hänger 5,0 m vom Stützpunkt; sonst  9,17 m
     Re 250: wie Re 330
     Re 200: 1. Hänger 2,5 m vom Stützpunkt; 2. Hänger 6,0 m vom Stützpunkt; sonst 11,50 m
     Re 160: 1. Hänger 2,5 m vom Stützpunkt; sonst 12,50 m
     Re 100: 1. Hänger 5,0 m vom Stützpunkt; sonst 11,67 m
     Re 75 : wie Re 100
    }
    i:=(round((Abstand-2*Ersthaengerabstand)/MaxHaengerabstand+0.5)+2); //die +0,5 stellt sicher, dass im Zweifel ein Hänger mehr eingebaut wird, um den Maximalabstand nicht zu überschreiten. Außerdem +2 für den ersten und letzten Hänger

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true,  0, Ankertyp_FahrleitungTragseil);
    pktTB:=PunktSuchen(false, 0, Ankertyp_FahrleitungTragseil);
    D3DXVec3Subtract(vTragseil, pktTB.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt);
    Durchhang:=Abstand/35;   // größere Zahl = weniger Durchhang

    //Erster Hänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    //unterer Kettenwerkpunkt
    D3DXVec3Scale(v, vFahrdraht, (Ersthaengerabstand/Abstand));
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Scale(v, vTragseil, (Ersthaengerabstand/Abstand));
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

    //Punkt absenken
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 1/Durchhang+Durchhang*Sqr((1-0.5)/(i)-0.5));
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;

    for a:=2 to (i-1) do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      //unterer Kettenwerkpunkt
      D3DXVec3Scale(v, vFahrdraht, (a-0.5)/i);
      D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

      //oberer Kettenwerkpunkt
      D3DXVec3Scale(v, vTragseil, (a-0.5)/i);
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

      //Punkt absenken
      D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
      D3DXVec3Scale(vNeu, v, 0.75/Durchhang+Durchhang*Sqr((a-0.5)/(i)-0.5));
      D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    end;

    //Letzter Hänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    //unterer Kettenwerkpunkt
    D3DXVec3Scale(v, vFahrdraht, (Abstand - Ersthaengerabstand)/Abstand);
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);

    //oberer Kettenwerkpunkt
    D3DXVec3Scale(v, vTragseil, (Abstand - Ersthaengerabstand)/Abstand);
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktTA.PunktTransformiert.Punkt, v);

    //Punkt absenken
    D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
    D3DXVec3Scale(vNeu, v, 1/Durchhang+Durchhang*Sqr((i-0.5)/(i)-0.5));
    D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktU.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=pktO.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;


    // Tragseil-Abschnitte zwischen den Hängern
    for a:=1 to length(ErgebnisArray)-1 do
    begin
      setlength(ErgebnisArray, length(ErgebnisArray)+1);
      ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=ErgebnisArray[a-1].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[a].Punkt2;
      ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
      ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
      v:=ErgebnisArray[a].Punkt2;
    end;
    // Tragseil-Abschnitte vom Ausleger zum ersten bzw. letzten Hänger
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTA.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=ErgebnisArray[0].Punkt2;
    ErgebnisArray[length(ErgebnisArray)-1].Staerke:=DrahtStaerke;
    ErgebnisArray[length(ErgebnisArray)-1].Farbe:=DrahtFarbe;
    setlength(ErgebnisArray, length(ErgebnisArray)+1);
    ErgebnisArray[length(ErgebnisArray)-1].Punkt1:=pktTB.PunktTransformiert.Punkt;
    ErgebnisArray[length(ErgebnisArray)-1].Punkt2:=v;
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
  //TODO: Derzeit muss noch das Radspannwerk immer an A liegen.
  if (Typ1=0) and (Typ2=1) then KettenwerkAusfaedelungMitIsolator;
  if (Typ1=1) and (Typ2=0) then
  begin //Arrays durchtauschen, da die Bau-Procedure nicht seitenneutral ist
    PunkteTemp:=PunkteA;
    PunkteA:=PunkteB;
    PunkteB:=PunkteTemp;
    KettenwerkAusfaedelungMitIsolator;
  end;

  if (Typ1=2) and (Typ2=1) then KettenwerkStandardAufAusfaedelungMitIsolator;
  if (Typ1=1) and (Typ2=2) then
  begin //Arrays durchtauschen, da die Bau-Procedure nicht seitenneutral ist
    PunkteTemp:=PunkteA;
    PunkteA:=PunkteB;
    PunkteB:=PunkteTemp;
    KettenwerkStandardAufAusfaedelungMitIsolator;
  end;

  if (Typ1=2) and (Typ2=2) then KettenwerkOhneYSeil;

  Result.iDraht:=length(ErgebnisArray);
  Result.iDatei:=length(ErgebnisArrayDateien);
end;

function Bezeichnung:PChar; stdcall;
begin
  Result:='Re 160 Erweiterte Funktionen'
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
  Formular.RadioGroupHaengerteilung.ItemIndex := Haengerkennzahl;

  Formular.ShowModal;

  if Formular.ModalResult=mrOK then
  begin
    DateiIsolator:=(Formular.LabeledEditIsolator.Text);
    Drahtkennzahl:=Formular.RadioGroupDrahtstaerke.ItemIndex;
    Haengerkennzahl:=Formular.RadioGroupHaengerteilung.ItemIndex;
    RegistrySchreiben;
    RegistryLesen;
  end;

  Application.Handle:=0;
  Formular.Free;
end;

end.
