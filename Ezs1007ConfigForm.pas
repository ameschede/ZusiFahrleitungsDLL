unit Ezs1007ConfigForm;

{$MODE Delphi}

interface

uses
  SysUtils, Variants, Interfaces, Classes, Graphics, Controls, Forms,
  Dialogs, Buttons, ExtCtrls, Registry;

type
  TFormEzs1007Config = class(TForm)
    OK: TBitBtn;
    BitBtnAbbrechen: TBitBtn;
    OpenDialogDatei: TOpenDialog;
    SpeedButtonIsolator: TSpeedButton;
    LabeledEditIsolator: TLabeledEdit;
    RadioGroupDrahtstaerke: TRadioGroup;
    procedure SpeedButtonIsolatorClick(Sender: TObject);
  private
    { Private-Deklarationen }
    procedure Dateiauswahl(Edit:TLabeledEdit);
  public
    { Public-Deklarationen }
  end;

var
  FormFahrleitungConfig: TFormEzs1007Config;

implementation

{$R *.lfm}

procedure TFormEzs1007Config.Dateiauswahl(Edit:TLabeledEdit);
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


procedure TFormEzs1007Config.SpeedButtonIsolatorClick(Sender: TObject);
begin
   Dateiauswahl(LabeledEditIsolator);
end;

end.
