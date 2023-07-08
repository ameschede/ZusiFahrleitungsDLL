unit Ezs1007Berechnung;

{$MODE Delphi}

interface

uses
  Direct3D9, d3dx9, 
  
  sysutils, Controls, registry, windows, interfaces, forms, Classes, LConvEncoding, Dialogs, Math,
  
  ZusiD3DTypenDll, FahrleitungsTypen, OLADLLgemeinsameFkt, Ezs1007ConfigForm;


function Init:Longword; stdcall;
function BauartTyp(i:Longint):PChar; stdcall;
function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
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


var DateiIsolator:string;
    Drahtstaerke,Helligkeit:single;
    DialogOffen:boolean;


procedure RegistryLesen;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\Ezs1007') then
            begin
              if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
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
            if reg.OpenKey('Ezs1007', true) then
            begin
              reg.WriteString('DateiIsolator', DateiIsolator);
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
  Result:=3;  //muss passen zu den möglichen Rückgabewerten der function BauartTyp
  Reset(true);
  Reset(false);
  DateiIsolator:='Catenary\Deutschland\Einzelteile_Re75-200\Isolator.lod.ls3';
  Drahtstaerke:=0.006; //Draht Ri 100. TODO: Differenzierte Drahtstärke für das Tragseil
  Helligkeit := 0;
  RegistryLesen;
end;

function BauartTyp(i:Longint):PAnsiChar; stdcall;
// Wird vom Editor so oft aufgerufen, wie wir als Result in der init-function übergeben haben. Enumeriert die Bauart-Typen, die diese DLL kennt 
begin
  case i of
  0: Result:='Ezs 1007 am Ausleger';
  1: Result:='Abschluß mit Isolator';
  2: Result:='Ezs 1007 am QTW';
  else Result := 'Ezs 1007 am Ausleger'
  end;
end;

function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
// Wir versuchen, aus der vom Editor übergebenen Ankerkonfiguration einen Bauarttypen vorzuschlagen
  function Vorschlagen(Punkte:array of TAnkerpunkt):Longint	;
  var iOben2, iUnten2:integer;
      b:integer;
  begin
    Result:=-1;
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

procedure Ezs1007Fahrdraht(pTragseillaengeA,pTragseillaengeB: single; pAbschluss: bool);
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
    pktFA:=PunktSuchen(true, 1, Ankertyp_FahrleitungFahrdraht);
    if pAbschluss = false then
      pktFB:=PunktSuchen(false, 1, Ankertyp_FahrleitungFahrdraht)
    else pktFB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAbspannungMastpunktFahrdraht);
    D3DXVec3Subtract(vFahrdraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);

    //Tragseil Endpunkte
    pktTA:=PunktSuchen(true, 1, Ankertyp_FahrleitungTragseil);
    if pAbschluss = false then
      pktTB:=PunktSuchen(false, 1, Ankertyp_FahrleitungTragseil)
    else pktTB:=PunktSuchen(false, 1, Ankertyp_FahrleitungAbspannungMastpunktTragseil);

    //Prüfung ob notwendige Ankerpunkte vorhanden sind
    if AnkerIstLeer(pktTA) or AnkerIstLeer(pktTB) or AnkerIstLeer(pktFA) or AnkerIstLeer(pktFB) then
    begin
         showmessage('Warnung: Ein notwendiger Fahrdraht-/Tragseil-Ankerpunkt wurde nicht erkannt. Der Fahrdraht kann nicht erzeugt werden.');
         exit; //Abbruch, weil Fahrdraht entarten würde
    end;

    //Tragseil am Ausleger A
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, pTragseillaengeA);    //Tragseil von x Meter Länge am Ausleger A
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);
    DrahtEintragen(pktU.PunktTransformiert.Punkt,pktTA.PunktTransformiert.Punkt,DrahtStaerke,DrahtFarbe,Helligkeit);
{
    //Stützrohrhänger Ausleger A
    DrahtEintragen(pktFA.PunktTransformiert.Punkt,pktTA.PunktTransformiert.Punkt,DrahtStaerke,DrahtFarbe,Helligkeit);

    //Stützrohrhänger Ausleger B
    DrahtEintragen(pktFB.PunktTransformiert.Punkt,pktTB.PunktTransformiert.Punkt,DrahtStaerke,DrahtFarbe,Helligkeit);
}

  if pAbschluss = false then
  begin
    //Tragseil am Ausleger B
    //unterer Kettenwerkpunkt
    D3DXVec3Normalize(vNorm, vFahrdraht);
    D3DXVec3Scale(v, vNorm, -(pTragseillaengeB));    //Tragseil von x Meter Länge am Ausleger B
    D3DXVec3Add(pktU.PunktTransformiert.Punkt, pktFB.PunktTransformiert.Punkt, v);
    DrahtEintragen(pktU.PunktTransformiert.Punkt,pktTB.PunktTransformiert.Punkt,DrahtStaerke,DrahtFarbe,Helligkeit);
  end;


    //Fahrdraht eintragen
    DrahtEintragen(pktFA.PunktTransformiert.Punkt,pktFB.PunktTransformiert.Punkt,DrahtStaerke,DrahtFarbe,Helligkeit);

  if pAbschluss = true then
  begin
    //Isolator an der Ausfädelung
    setlength(ErgebnisArrayDateien, length(ErgebnisArrayDateien)+1);
    LageIsolator(pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, 2, pktU.PunktTransformiert.Punkt, pktU.PunktTransformiert.Winkel);
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktxyz:=pktU.PunktTransformiert.Punkt;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Punktphixyz:=pktU.PunktTransformiert.Winkel;
    ErgebnisArrayDateien[length(ErgebnisArrayDateien)-1].Datei:=PAnsichar(DateiIsolator);
   end;

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
  if (Typ1=0) and (Typ2=1) then Ezs1007Fahrdraht(5,5,true);
  if (Typ1=1) and (Typ2=0) then
  begin //Arrays durchtauschen, da die Bau-Procedure nicht seitenneutral ist
    PunkteTemp:=PunkteA;
    PunkteA:=PunkteB;
    PunkteB:=PunkteTemp;
    Ezs1007Fahrdraht(5,5,true);
  end;

  //Kombinationen aus QTW und Abschluss
  if (Typ1=2) and (Typ2=1) then Ezs1007Fahrdraht(1,5,true);
  if (Typ1=1) and (Typ2=2) then
  begin //Arrays durchtauschen, da die Bau-Procedure nicht seitenneutral ist
    PunkteTemp:=PunkteA;
    PunkteA:=PunkteB;
    PunkteB:=PunkteTemp;
    Ezs1007Fahrdraht(1,5,true);
  end;

  if (Typ1=0) and (Typ2=0) then Ezs1007Fahrdraht(5,5,false);     //beide am Ausleger
  if (Typ1=2) and (Typ2=2) then Ezs1007Fahrdraht(1,1,false);     //beide am QTW
  if (Typ1=2) and (Typ2=0) then Ezs1007Fahrdraht(1,5,false);     //A am QTW, B am Ausleger
  if (Typ1=0) and (Typ2=2) then Ezs1007Fahrdraht(5,1,false);     //A am Ausleger, B am QTW

  Result.iDraht:=length(ErgebnisArray);
  Result.iDatei:=length(ErgebnisArrayDateien);
end;

function Bezeichnung:PChar; stdcall;
begin
  Result:='Ezs 1007'
end;

function Gruppe:PChar; stdcall;
// Teilt dem Editor die Objektgruppe mit, die er bei den verknüpften Dateien vermerken soll
begin
  Result:='Kettenwerk Ezs 1007';
end;

procedure Config(AppHandle:HWND); stdcall;
var Formular:TFormEzs1007Config;
begin
  if not DialogOffen then
  begin
  DialogOffen:=true;
  Application.Initialize;
  //Application.Handle:=AppHandle;
  Formular:=TFormEzs1007Config.Create(Application);
  Formular.LabeledEditIsolator.Text:=DateiIsolator;
  if Helligkeit = 0 then Formular.RadioGroupZwangshelligkeit.ItemIndex := 0;
  if SameValue(Helligkeit,0.07,0.01) then Formular.RadioGroupZwangshelligkeit.ItemIndex := 1;

  Formular.ShowModal;

  if Formular.ModalResult=mrOK then
  begin
    DateiIsolator:=(Formular.LabeledEditIsolator.Text);
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
