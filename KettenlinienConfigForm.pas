unit KettenlinienConfigForm;

{$MODE Delphi}

interface

uses
  SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls, Registry, ComCtrls, OLADLLgemeinsameFkt;

type

  { TFormFahrleitungConfig }

  TFormFahrleitungConfig = class(TForm)
    ButtonStandard: TButton;
    ColorButtonStromleitung: TColorButton;
    ColorButtonSpeiseleitung: TColorButton;
    ColorButtonStelldraht: TColorButton;
    ColorButtonTelegrafenleitung: TColorButton;
    ColorDialog1: TColorDialog;
    EditZufallTelegrafenleitung: TEdit;
    EditZufallStelldraht: TEdit;
    EditZufallSpeiseleitung: TEdit;
    EditZufallStromleitung: TEdit;
    EditDurchhangStelldraht: TEdit;
    EditDurchhangTelegrafenleitung: TEdit;
    EditDurchhangSpeiseleitung: TEdit;
    EditDurchhangStromleitung: TEdit;
    EditAbschnitteStelldraht: TEdit;
    EditAbschnitteTelegrafenleitung: TEdit;
    EditAbschnitteSpeiseleitung: TEdit;
    EditAbschnitteStromleitung: TEdit;
    EditDurchmesserStelldraht: TEdit;
    EditDurchmesserTelegrafenleitung: TEdit;
    EditDurchmesserSpeiseleitung: TEdit;
    EditDurchmesserStromleitung: TEdit;
    LabelSchwankungAutomatik: TLabel;
    LabeledEditSchwankungAutomatikX: TLabeledEdit;
    LabeledEditObjektabstandAutomatik: TLabeledEdit;
    LabeledEditSchwankungAutomatikY: TLabeledEdit;
    LabelFarbe: TLabel;
    LabelZufall: TLabel;
    LabelDurchhang: TLabel;
    LabelAbschnitte: TLabel;
    LabelDurchmesser: TLabel;
    LabeledEditKonvexParameter: TLabeledEdit;
    OK: TBitBtn;
    BitBtnAbbrechen: TBitBtn;
    OpenDialogDatei: TOpenDialog;
    RadioButtonStelldraht: TRadioButton;
    RadioButtonTelegrafenleitung: TRadioButton;
    RadioButtonSpeiseleitung: TRadioButton;
    RadioButtonStromleitung: TRadioButton;
    SpeedButtonIsolator: TSpeedButton;
    LabeledEditAutomatikDatei: TLabeledEdit;
    procedure ButtonStandardClick(Sender: TObject);
    procedure ColorButtonSpeiseleitungClick(Sender: TObject);
    procedure ColorButtonStelldrahtClick(Sender: TObject);
    procedure ColorButtonStromleitungClick(Sender: TObject);
    procedure ColorButtonTelegrafenleitungClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SpeedButtonIsolatorClick(Sender: TObject);
  private
    { Private-Deklarationen }
    procedure Dateiauswahl(Edit:TLabeledEdit);
  public
    { Public-Deklarationen }
  end;

var
  FormFahrleitungConfig: TFormFahrleitungConfig;

implementation

{$R *.lfm}

procedure TFormFahrleitungConfig.Dateiauswahl(Edit:TLabeledEdit);
var Arbeitsverzeichnis,VerzeichnisStickPrivat,VerzeichnisStickOffiziell,VerzeichnisSteamPrivat,VerzeichnisSteamOffiziell:string;
    reg:TRegistry;
begin
  if OpenDialogDatei.Execute then
  begin
    reg:=TRegistry.Create;
    try
      reg.RootKey:=HKEY_LOCAL_MACHINE;
      if reg.OpenKeyReadOnly('\SOFTWARE\Zusi3') then
      begin
        if reg.ValueExists('DatenVerzeichnis') then VerzeichnisStickPrivat := reg.ReadString('DatenVerzeichnis');
        if reg.ValueExists('DatenVerzeichnisOffiziell') then VerzeichnisStickOffiziell := reg.ReadString('DatenVerzeichnisOffiziell');
        if reg.ValueExists('DatenVerzeichnisSteam') then VerzeichnisSteamPrivat := reg.ReadString('DatenVerzeichnisSteam');
        if reg.ValueExists('DatenVerzeichnisOffiziellSteam') then VerzeichnisSteamOffiziell := reg.ReadString('DatenVerzeichnisOffiziellSteam');
      end
    except
      reg.Free;
    end;
    //soweit möglich einen relativen Pfad herstellen
    Arbeitsverzeichnis := stringReplace(OpenDialogDatei.FileName,VerzeichnisStickPrivat,'',[rfIgnoreCase]);
    Arbeitsverzeichnis := stringReplace(Arbeitsverzeichnis,VerzeichnisStickOffiziell,'',[rfIgnoreCase]);
    Arbeitsverzeichnis := stringReplace(Arbeitsverzeichnis,VerzeichnisSteamPrivat,'',[rfIgnoreCase]);
    Arbeitsverzeichnis := stringReplace(Arbeitsverzeichnis,VerzeichnisSteamOffiziell,'',[rfIgnoreCase]);
    Edit.Text:=Arbeitsverzeichnis;
  end;
end;




procedure TFormFahrleitungConfig.SpeedButtonIsolatorClick(Sender: TObject);
begin
   Dateiauswahl(LabeledEditAutomatikDatei);
end;

procedure TFormFahrleitungConfig.FormCreate(Sender: TObject);
begin
  if Screen.PixelsPerInch <> 192 then ScaleDPI(Self,192);
end;

procedure TFormFahrleitungConfig.ColorButtonStromleitungClick(Sender: TObject);
begin
  if ColorDialog1.Execute then
  begin
    ColorButtonStromleitung.ButtonColor := ColorDialog1.Color;
  end;
end;

procedure TFormFahrleitungConfig.ColorButtonTelegrafenleitungClick(
  Sender: TObject);
begin
    if ColorDialog1.Execute then
  begin
    ColorButtonTelegrafenleitung.ButtonColor := ColorDialog1.Color;
  end;
end;

procedure TFormFahrleitungConfig.ColorButtonSpeiseleitungClick(Sender: TObject);
begin
    if ColorDialog1.Execute then
  begin
    ColorButtonSpeiseleitung.ButtonColor := ColorDialog1.Color;
  end;
end;

procedure TFormFahrleitungConfig.ButtonStandardClick(Sender: TObject);
var reg: TRegistry;
    begin
    reg:=TRegistry.Create;
    try
       reg.RootKey:=HKEY_CURRENT_USER;
       reg.DeleteKey('Software\Zusi3\lib\catenary\Kettenlinien')
    finally
       reg.Free;
    end;
end;

procedure TFormFahrleitungConfig.ColorButtonStelldrahtClick(Sender: TObject);
begin
    if ColorDialog1.Execute then
  begin
    ColorButtonStelldraht.ButtonColor := ColorDialog1.Color;
  end;
end;

end.
