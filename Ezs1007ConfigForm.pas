unit Ezs1007ConfigForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Grids, StdCtrls, Buttons, ExtCtrls, Registry;

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

{$R *.dfm}

procedure TFormEzs1007Config.Dateiauswahl(Edit:TLabeledEdit);
var Arbeitsverzeichnis:string;
    reg:TRegistry;
begin
  if OpenDialogDatei.Execute then
  begin
    reg:=TRegistry.Create;
    try
      reg.RootKey:=HKEY_LOCAL_MACHINE;
      if reg.OpenKeyReadOnly('\SOFTWARE\Zusi3') then
      begin
        Arbeitsverzeichnis:=reg.ReadString('DatenVerzeichnis');
      end
    except
      reg.Free;
    end;
    Edit.Text:=ExtractRelativePath(Arbeitsverzeichnis, OpenDialogDatei.FileName);
  end;
end;




procedure TFormEzs1007Config.SpeedButtonIsolatorClick(Sender: TObject);
begin
   Dateiauswahl(LabeledEditIsolator);
end;

end.
