unit KettenlinienBerechnung;

{$MODE Delphi}

interface

uses
  Direct3D9, D3DX9,

  sysutils, Controls, registry, windows, forms, Dialogs, interfaces, LConvEncoding, Math, Graphics,
  
  ZusiD3DTypenDll, FahrleitungsTypen, OLADLLgemeinsameFkt, KettenlinienConfigForm;

type

  TBautyp = (Normal,Konvex);

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

var
    DateiIsolator:string;
    StaerkeDraht,DurchmesserStromleitung,DurchmesserSpeiseleitung,DurchmesserTelegrafenleitung,DurchmesserStelldraht,DurchhangStromleitung,DurchhangSpeiseleitung,DurchhangTelegrafenleitung,DurchhangStelldraht,Konkavparameter,Konvexparameter:single;
    Kettenwerkstyp, Abschnitte,AbschnitteStromleitung,AbschnitteSpeiseleitung,AbschnitteTelegrafenleitung,AbschnitteStelldraht,Zufallsschwankung,ZufallStromleitung,ZufallSpeiseleitung,ZufallTelegrafenleitung,ZufallStelldraht:integer;
    DrahtFarbe:TD3DColorValue;
    Ankertyp:TAnkertyp;
    BaufunktionAufgerufen,DialogOffen:boolean;
    Farbe,FarbeStromleitung,FarbeSpeiseleitung,FarbeTelegrafenleitung,FarbeStelldraht:TColor;

procedure RegistryLesen;
var reg: TRegistry;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_CURRENT_USER;
            if reg.OpenKeyReadOnly('Software\Zusi3\lib\catenary\Kettenlinien') then
            begin
              //if reg.ValueExists('DateiIsolator') then DateiIsolator:=reg.ReadString('DateiIsolator');
              if reg.ValueExists('DurchmesserStromleitung') then DurchmesserStromleitung := reg.ReadFloat('DurchmesserStromleitung');
              if reg.ValueExists('DurchmesserSpeiseleitung') then DurchmesserSpeiseleitung := reg.ReadFloat('DurchmesserSpeiseleitung');
              if reg.ValueExists('DurchmesserTelegrafenleitung') then DurchmesserTelegrafenleitung := reg.ReadFloat('DurchmesserTelegrafenleitung');
              if reg.ValueExists('DurchmesserStelldraht') then DurchmesserStelldraht := reg.ReadFloat('DurchmesserStelldraht');
              if reg.ValueExists('AbschnitteStromleitung') then AbschnitteStromleitung := reg.ReadInteger('AbschnitteStromleitung');
              if reg.ValueExists('AbschnitteSpeiseleitung') then AbschnitteSpeiseleitung := reg.ReadInteger('AbschnitteSpeiseleitung');
              if reg.ValueExists('AbschnitteTelegrafenleitung') then AbschnitteTelegrafenleitung := reg.ReadInteger('AbschnitteTelegrafenleitung');
              if reg.ValueExists('AbschnitteStelldraht') then AbschnitteStelldraht := reg.ReadInteger('AbschnitteStelldraht');
              if reg.ValueExists('DurchhangStromleitung') then DurchhangStromleitung := reg.ReadFloat('DurchhangStromleitung');
              if reg.ValueExists('DurchhangSpeiseleitung') then DurchhangSpeiseleitung := reg.ReadFloat('DurchhangSpeiseleitung');
              if reg.ValueExists('DurchhangTelegrafenleitung') then DurchhangTelegrafenleitung := reg.ReadFloat('DurchhangTelegrafenleitung');
              if reg.ValueExists('DurchhangStelldraht') then DurchhangStelldraht := reg.ReadFloat('DurchhangStelldraht');
              if reg.ValueExists('ZufallStromleitung') then ZufallStromleitung := reg.ReadInteger('ZufallStromleitung');
              if reg.ValueExists('ZufallSpeiseleitung') then ZufallSpeiseleitung := reg.ReadInteger('ZufallSpeiseleitung');
              if reg.ValueExists('ZufallTelegrafenleitung') then ZufallTelegrafenleitung := reg.ReadInteger('ZufallTelegrafenleitung');
              if reg.ValueExists('ZufallStelldraht') then ZufallStelldraht := reg.ReadInteger('ZufallStelldraht');
              if reg.ValueExists('FarbeStromleitung') then FarbeStromleitung := reg.ReadInteger('FarbeStromleitung');
              if reg.ValueExists('FarbeSpeiseleitung') then FarbeSpeiseleitung := reg.ReadInteger('FarbeSpeiseleitung');
              if reg.ValueExists('FarbeTelegrafenleitung') then FarbeTelegrafenleitung := reg.ReadInteger('FarbeTelegrafenleitung');
              if reg.ValueExists('FarbeStelldraht') then FarbeStelldraht := reg.ReadInteger('FarbeStelldraht');
              if reg.ValueExists('Kettenwerkstyp') then Kettenwerkstyp := reg.ReadInteger('Kettenwerkstyp');
              if reg.ValueExists('StaerkeDraht') then StaerkeDraht := reg.ReadFloat('StaerkeDraht');
              if reg.ValueExists('Abschnitte') then Abschnitte := reg.ReadInteger('Abschnitte');
              if reg.ValueExists('Zufallsschwankung') then Zufallsschwankung := reg.ReadInteger('Zufallsschwankung');
              if reg.ValueExists('KonkavParameter') then Konkavparameter := reg.ReadFloat('Konkavparameter');
              if reg.ValueExists('KonvexParameter') then Konvexparameter := reg.ReadFloat('Konvexparameter');
              if reg.ValueExists('Farbe') then Farbe := reg.ReadInteger('Farbe');
            end;
            case Kettenwerkstyp of
            0: Ankertyp := Ankertyp_Stromleitung;
            1: Ankertyp := Ankertyp_Speiseleitung;
            2: Ankertyp := Ankertyp_Telegrafenleitung;
            3: Ankertyp := Ankertyp_Stelldraht;
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
            if reg.OpenKey('Kettenlinien', true) then
            begin
              //reg.WriteString('DateiIsolator', DateiIsolator);
              reg.WriteInteger('Kettenwerkstyp',Kettenwerkstyp);
              reg.WriteInteger('Abschnitte',Abschnitte);
              reg.WriteFloat('StaerkeDraht',StaerkeDraht);
              reg.WriteInteger('Zufallsschwankung',Zufallsschwankung);
              reg.WriteInteger('Farbe',Farbe);
              reg.WriteFloat('KonkavParameter',Konkavparameter);
              reg.WriteFloat('KonvexParameter',Konvexparameter);
              reg.WriteFloat('DurchmesserStromleitung',DurchmesserStromleitung);
              reg.WriteFloat('DurchmesserSpeiseleitung',DurchmesserSpeiseleitung);
              reg.WriteFloat('DurchmesserTelegrafenleitung',DurchmesserTelegrafenleitung);
              reg.WriteFloat('DurchmesserStelldraht',DurchmesserStelldraht);
              reg.WriteInteger('AbschnitteStromleitung',AbschnitteStromleitung);
              reg.WriteInteger('AbschnitteSpeiseleitung',AbschnitteSpeiseleitung);
              reg.WriteInteger('AbschnitteTelegrafenleitung',AbschnitteTelegrafenleitung);
              reg.WriteInteger('AbschnitteStelldraht',AbschnitteStelldraht);
              reg.WriteFloat('DurchhangStromleitung',DurchhangStromleitung);
              reg.WriteFloat('DurchhangSpeiseleitung',DurchhangSpeiseleitung);
              reg.WriteFloat('DurchhangTelegrafenleitung',DurchhangTelegrafenleitung);
              reg.WriteFloat('DurchhangStelldraht',DurchhangStelldraht);
              reg.WriteInteger('ZufallStromleitung',ZufallStromleitung);
              reg.WriteInteger('ZufallSpeiseleitung',ZufallSpeiseleitung);
              reg.WriteInteger('ZufallTelegrafenleitung',ZufallTelegrafenleitung);
              reg.WriteInteger('ZufallStelldraht',ZufallStelldraht);
              reg.WriteInteger('FarbeStromleitung',FarbeStromleitung);
              reg.WriteInteger('FarbeSpeiseleitung',FarbeSpeiseleitung);
              reg.WriteInteger('FarbeTelegrafenleitung',FarbeTelegrafenleitung);
              reg.WriteInteger('FarbeStelldraht',FarbeStelldraht);
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
  Kettenwerkstyp := 0;
  StaerkeDraht := 0.0112;
  Konkavparameter := 0.00055;
  Konvexparameter := -0.8;
  Abschnitte := 12;
  Zufallsschwankung := 10;
  Farbe:=$00FCFCFC;
  DurchmesserStromleitung := 0.0224;
  DurchmesserSpeiseleitung := 0.017;
  DurchmesserTelegrafenleitung := 0.025;
  DurchmesserStelldraht := 0.008;
  AbschnitteStromleitung := 12;
  AbschnitteSpeiseleitung := 12;
  AbschnitteTelegrafenleitung := 12;
  AbschnitteStelldraht := 1;
  DurchhangStromleitung := 0.0001;
  DurchhangSpeiseleitung := 0.02;
  DurchhangTelegrafenleitung := 0.001;
  DurchhangStelldraht := 0.00;
  ZufallStromleitung := 10;
  ZufallSpeiseleitung := 10;
  ZufallTelegrafenleitung := 10;
  ZufallStelldraht := 10;
  FarbeStromleitung:=$00FCFCFC;
  FarbeSpeiseleitung:=$00FCFCFC;
  FarbeTelegrafenleitung:=$00FCFCFC;
  FarbeStelldraht:=$00FCFCFC;
  RegistryLesen;
end;

function BauartTyp(i:Longint):PChar; stdcall;
// Wird vom Editor so oft aufgerufen, wie wir als Result in der init-function übergeben haben. Enumeriert die Bauart-Typen, die diese DLL kennt 
begin
  case i of
  0: Result:='Normal';
  1: Result:='Konvex';
  else Result := 'Normal'
  end;

  //Zusi 3.5 erwartet Codepage 1252 auf der DLL-Schnittstelle
  Result:=PChar(UTF8toCP1252(Result));
end;

function BauartVorschlagen(A:Boolean; BauartBVorgaenger:LongInt):Longint; stdcall;
begin
     Result:= 0;
end;

procedure Kettenlinie(BautypA,BautypB:TBautyp);
var pktFA, pktFB, pktU, pktO:TAnkerpunkt;
    Abstand, Abschnittslaenge, Durchhang, Parabelparameter, Zufall:single;
    vDraht, v, vNeu, vNorm, Startpunkt:TD3DVector;
    a, b :integer;


begin
  DrahtFarbe.r:=red(Farbe)/255;
  DrahtFarbe.g:=green(Farbe)/255;
  DrahtFarbe.b:=blue(Farbe)/255;
  DrahtFarbe.a:=0;
  if (length(PunkteA)>0) and (length(PunkteB)>0) then
  begin
    for b:=1 to (length(PunkteA)) do
    begin
    //Feststellen welcher Ankertyp konfiguriert ist
      pktFA:=PunktSuchen(true,  b, Ankertyp);
      pktFB:=PunktSuchen(false, b, Ankertyp);
      if AnkerIstLeer(pktFA) or AnkerIstLeer(pktFB) then exit; //Abbruch, weil entarteter Draht entstehen würde
      D3DXVec3Subtract(vDraht, pktFB.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt);
      Abstand:=D3DXVec3Length(vDraht);

      Abschnittslaenge := Abstand/Abschnitte;

      Zufall := (RandomRange((100-Zufallsschwankung),(100+Zufallsschwankung)))/100;

      if (BautypA = Konvex) or (BautypB = Konvex) then Parabelparameter := Konvexparameter
      else Parabelparameter := Konkavparameter;

      Startpunkt := pktFA.PunktTransformiert.Punkt;
      for a:=1 to Abschnitte do
      begin
        //Kettenwerkpunkt
        D3DXVec3Normalize(vNorm, vDraht);
        D3DXVec3Scale(v, vNorm, a * Abschnittslaenge);
        D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktFA.PunktTransformiert.Punkt, v);
        pktU := pktO;
        pktU.PunktTransformiert.Punkt.z := pktU.PunktTransformiert.Punkt.z-10; //Synthetisierung eines virtuellen Punkts 10 Meter unter dem Seil

        //Punkt absenken
        Durchhang := (Zufall * Parabelparameter * sqr((a * Abschnittslaenge) - (Abstand/2)) + 1.0) / (Zufall * Parabelparameter * sqr(Abstand/2) + 1.0);
        D3DXVec3Subtract(v, pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt);
        D3DXVec3Scale(vNeu, v, Durchhang);
        D3DXVec3Add(pktO.PunktTransformiert.Punkt, pktU.PunktTransformiert.Punkt, vNeu);

        DrahtEintragen(Startpunkt,pktO.PunktTransformiert.Punkt,StaerkeDraht,DrahtFarbe);
        Startpunkt := pktO.PunktTransformiert.Punkt;
      end;
    end;


  end;
end;

function Berechnen(Typ1, Typ2:Longint):TErgebnis; stdcall;
// Der Benutzer hat auf 'Ausführen' geklickt.
// Rückgabe: Anzahl der Linien
var BautypA, BautypB : TBautyp;

begin
  //zunächst nochmal Grundzustand herstellen
  setlength(ErgebnisArray, 0);
  setlength(ErgebnisArrayDateien, 0);
  BaufunktionAufgerufen := false;

  //Übersetzung zwischen den von Zusi übergebenen Longints und unseren Bautypen
  case Typ1 of
    0: BautypA := Normal;
    1: BautypA := Konvex;
  end;
    case Typ2 of
    0: BautypB := Normal;
    1: BautypB := Konvex;
  end;

  //Der catch-all für alle sonstigen Kombinationen (hoffentlich nur sinnvolle);
  if not BaufunktionAufgerufen then Kettenlinie(BautypA,BautypB);

  Result.iDraht:=length(ErgebnisArray);
  Result.iDatei:=length(ErgebnisArrayDateien);
end;


function Bezeichnung:PChar; stdcall;
begin
  Result:='Kettenlinien'
end;

function Gruppe:PChar; stdcall;
// Teilt dem Editor die Objektgruppe mit, die er bei den verknüpften Dateien vermerken soll
begin
  Result:='Kettenlinien';
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
       case Kettenwerkstyp of
            0: Formular.RadioButtonStromleitung.checked := true;
            1: Formular.RadioButtonSpeiseleitung.checked := true;
            2: Formular.RadioButtonTelegrafenleitung.checked := true;
            3: Formular.RadioButtonStelldraht.checked := true;
       end;
       Formular.EditDurchmesserStromleitung.Text:=FormatFloat('0.0000',DurchmesserStromleitung);
       Formular.EditDurchmesserSpeiseleitung.Text:=FormatFloat('0.0000',DurchmesserSpeiseleitung);
       Formular.EditDurchmesserTelegrafenleitung.Text:=FormatFloat('0.0000',DurchmesserTelegrafenleitung);
       Formular.EditDurchmesserStelldraht.Text:=FormatFloat('0.0000',DurchmesserStelldraht);
       Formular.EditAbschnitteStromleitung.Text:=inttostr(AbschnitteStromleitung);
       Formular.EditAbschnitteSpeiseleitung.Text:=inttostr(AbschnitteSpeiseleitung);
       Formular.EditAbschnitteTelegrafenleitung.Text:=inttostr(AbschnitteTelegrafenleitung);
       Formular.EditAbschnitteStelldraht.Text:=inttostr(AbschnitteStelldraht);
       Formular.EditDurchhangStromleitung.Text:=FormatFloat('0.00000',DurchhangStromleitung);
       Formular.EditDurchhangSpeiseleitung.Text:=FormatFloat('0.00000',DurchhangSpeiseleitung);
       Formular.EditDurchhangTelegrafenleitung.Text:=FormatFloat('0.00000',DurchhangTelegrafenleitung);
       Formular.EditDurchhangStelldraht.Text:=FormatFloat('0.00000',DurchhangStelldraht);
       Formular.EditZufallStromleitung.Text:=inttostr(ZufallStromleitung);
       Formular.EditZufallSpeiseleitung.Text:=inttostr(ZufallSpeiseleitung);
       Formular.EditZufallTelegrafenleitung.Text:=inttostr(ZufallTelegrafenleitung);
       Formular.EditZufallStelldraht.Text:=inttostr(ZufallStelldraht);
       Formular.LabeledEditKonvexParameter.Text:=FormatFloat('0.000',Konvexparameter);
       Formular.ColorButtonStromleitung.ButtonColor:=FarbeStromleitung;
       Formular.ColorButtonSpeiseleitung.ButtonColor:=FarbeSpeiseleitung;
       Formular.ColorButtonTelegrafenleitung.ButtonColor:=FarbeTelegrafenleitung;
       Formular.ColorButtonStelldraht.ButtonColor:=FarbeStelldraht;
       Formular.ShowModal;

       if Formular.ModalResult=mrOK then
       begin
            DateiIsolator:=(Formular.LabeledEditIsolator.Text);
            DurchmesserStromleitung := strtofloat(Formular.EditDurchmesserStromleitung.Text);
            DurchmesserSpeiseleitung := strtofloat(Formular.EditDurchmesserSpeiseleitung.Text);
            DurchmesserTelegrafenleitung := strtofloat(Formular.EditDurchmesserTelegrafenleitung.Text);
            DurchmesserStelldraht := strtofloat(Formular.EditDurchmesserStelldraht.Text);
            AbschnitteStromleitung := strtoint(Formular.EditAbschnitteStromleitung.Text);
            AbschnitteSpeiseleitung := strtoint(Formular.EditAbschnitteSpeiseleitung.Text);
            AbschnitteTelegrafenleitung := strtoint(Formular.EditAbschnitteTelegrafenleitung.Text);
            AbschnitteStelldraht := strtoint(Formular.EditAbschnitteStelldraht.Text);
            DurchhangStromleitung := strtofloat(Formular.EditDurchhangStromleitung.Text);
            DurchhangSpeiseleitung := strtofloat(Formular.EditDurchhangSpeiseleitung.Text);
            DurchhangTelegrafenleitung := strtofloat(Formular.EditDurchhangTelegrafenleitung.Text);
            DurchhangStelldraht := strtofloat(Formular.EditDurchhangStelldraht.Text);
            ZufallStromleitung := strtoint(Formular.EditZufallStromleitung.Text);
            ZufallSpeiseleitung := strtoint(Formular.EditZufallSpeiseleitung.Text);
            ZufallTelegrafenleitung := strtoint(Formular.EditZufallTelegrafenleitung.Text);
            ZufallStelldraht := strtoint(Formular.EditZufallStelldraht.Text);
            FarbeStromleitung := Formular.ColorButtonStromleitung.ButtonColor;
            FarbeSpeiseleitung := Formular.ColorButtonSpeiseleitung.ButtonColor;
            FarbeTelegrafenleitung := Formular.ColorButtonTelegrafenleitung.ButtonColor;
            FarbeStelldraht := Formular.ColorButtonStelldraht.ButtonColor;
            Konvexparameter := strtofloat(Formular.LabeledEditKonvexParameter.Text);
            if Formular.RadioButtonStromleitung.checked then
            begin
                 Kettenwerkstyp := 0;
                 StaerkeDraht := DurchmesserStromleitung/2;
                 Abschnitte := AbschnitteStromleitung;
                 Konkavparameter := DurchhangStromleitung;
                 Zufallsschwankung := ZufallStromleitung;
                 Farbe := FarbeStromleitung;
            end;
            if Formular.RadioButtonSpeiseleitung.checked then
            begin
                 Kettenwerkstyp := 1;
                 StaerkeDraht := DurchmesserSpeiseleitung/2;
                 Abschnitte := AbschnitteSpeiseleitung;
                 Konkavparameter := DurchhangSpeiseleitung;
                 Zufallsschwankung := ZufallSpeiseleitung;
                 Farbe := FarbeSpeiseleitung;
            end;
            if Formular.RadioButtonTelegrafenleitung.checked then
            begin
                 Kettenwerkstyp := 2;
                 StaerkeDraht := DurchmesserTelegrafenleitung/2;
                 Abschnitte := AbschnitteTelegrafenleitung;
                 Konkavparameter := DurchhangTelegrafenleitung;
                 Zufallsschwankung := ZufallTelegrafenleitung;
                 Farbe := FarbeTelegrafenleitung;
            end;
            if Formular.RadioButtonStelldraht.checked then
            begin
                 Kettenwerkstyp := 3;
                 StaerkeDraht := DurchmesserStelldraht/2;
                 Abschnitte := AbschnitteStelldraht;
                 Konkavparameter := DurchhangStelldraht;
                 Zufallsschwankung := ZufallStelldraht;
                 Farbe := FarbeStelldraht;
            end;
            RegistrySchreiben;
            RegistryLesen;
       end;

       if Formular.ModalResult=mrClose then Init;

       //Application.Handle:=0;
       Formular.Free;
       DialogOffen:=false;
  end;
end;

end.
