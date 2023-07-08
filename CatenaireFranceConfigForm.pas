﻿unit CatenaireFranceConfigForm;

{$MODE Delphi}

interface

uses
  SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls, Registry, ComCtrls, OLADLLgemeinsameFkt;

type

  { TFormFahrleitungConfig }

  TFormFahrleitungConfig = class(TForm)
    OK: TBitBtn;
    BitBtnAbbrechen: TBitBtn;
    OpenDialogDatei: TOpenDialog;
    RadioGroupZwangshelligkeit: TRadioGroup;
    SpeedButtonIsolator: TSpeedButton;
    LabeledEditIsolator: TLabeledEdit;
    RadioGroupZusatzisolatoren: TRadioGroup;
    RadioGroupKettenwerkstyp: TRadioGroup;
    LabelIsolatorposition: TLabel;
    LabelAusleger: TLabel;
    LabelAnkermast: TLabel;
    TrackBarFestpunktisolator: TTrackBar;
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
   Dateiauswahl(LabeledEditIsolator);
end;

procedure TFormFahrleitungConfig.FormCreate(Sender: TObject);
begin
  if Screen.PixelsPerInch <> 192 then ScaleDPI(Self,192);
end;

end.
