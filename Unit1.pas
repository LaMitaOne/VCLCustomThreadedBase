unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ExtCtrls, ComCtrls,
  uVCLCustomThreadedBase;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    FVCLView: TVCLCustomThreadedBase;

    // UI Layout analog zum FMX Layout
    UILayout: TPanel;
    btnStart: TButton;
    btnStop: TButton;
    lblFPS: TLabel;
    tbFPS: TTrackBar;
    FPSTimer: TTimer;

    procedure OnStartClick(Sender: TObject);
    procedure OnStopClick(Sender: TObject);
    procedure OnFPSTracking(Sender: TObject);
    procedure OnFPSTimer(Sender: TObject);
  public
    { Public-Deklarationen }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  Caption := 'VCL Threaded Base Sample';
  ClientWidth := 800;
  ClientHeight := 600;

  // 1. UI Layout (Panel am oberen Rand hält die Controls stabil)
  UILayout := TPanel.Create(Self);
  UILayout.Parent := Self;
  UILayout.Align := alTop;
  UILayout.Height := 70;
  UILayout.BevelOuter := bvNone;
  UILayout.Caption := '';

  // 2. Create the Custom VCL Component
  FVCLView := TVCLCustomThreadedBase.Create(Self);
  FVCLView.Parent := Self;
  FVCLView.Align := alClient;
  FVCLView.Active := False;
  // Margins via SetBounds und Parent-VCL tut das über Anchors/Align
  // In VCL ist das Margin-Verhalten anders, wir lassen es einfach Client-füllen

  // 3. Create Start Button
  btnStart := TButton.Create(Self);
  btnStart.Parent := UILayout;
  btnStart.Caption := 'Start Animation';
  btnStart.Width := 120;
  btnStart.Height := 35;
  btnStart.Left := 20;
  btnStart.Top := 15;
  btnStart.OnClick := OnStartClick;

  // 4. Create Stop Button
  btnStop := TButton.Create(Self);
  btnStop.Parent := UILayout;
  btnStop.Caption := 'Stop Animation';
  btnStop.Width := 120;
  btnStop.Height := 35;
  btnStop.Left := 150;
  btnStop.Top := 15;
  btnStop.OnClick := OnStopClick;

  // 5. Create FPS Label
  lblFPS := TLabel.Create(Self);
  lblFPS.Parent := UILayout;
  lblFPS.Caption := 'Target: 60 | Real: 0 FPS';
  lblFPS.Left := 290;
  lblFPS.Top := 15;
  lblFPS.Width := 200;
  lblFPS.Font.Size := 12;

  // 6. Create FPS TrackBar
  tbFPS := TTrackBar.Create(Self);
  tbFPS.Parent := UILayout;
  tbFPS.Min := 1;
  tbFPS.Max := 5000;
  tbFPS.Frequency := 1;
  tbFPS.Position := 60;
  tbFPS.Width := 250;
  tbFPS.Left := 290;
  tbFPS.Top := 35;
  tbFPS.Height := 30;
  tbFPS.OnChange := OnFPSTracking;

  // 7. Create FPS Update Timer
  FPSTimer := TTimer.Create(Self);
  FPSTimer.Interval := 500;
  FPSTimer.OnTimer := OnFPSTimer;
  FPSTimer.Enabled := True;
end;

procedure TForm1.OnStartClick(Sender: TObject);
begin
  if Assigned(FVCLView) then
    FVCLView.Active := True;
end;

procedure TForm1.OnStopClick(Sender: TObject);
begin
  if Assigned(FVCLView) then
    FVCLView.Active := False;
end;

procedure TForm1.OnFPSTracking(Sender: TObject);
begin
  if Assigned(FVCLView) and Assigned(tbFPS) then
  begin
    // VCL nutzt .Position statt .Value
    FVCLView.TargetFPS := Round(tbFPS.Position);
  end;
end;

procedure TForm1.OnFPSTimer(Sender: TObject);
begin
  if Assigned(FVCLView) and Assigned(lblFPS) then
  begin
    lblFPS.Caption := Format('Target: %d | Real: %d FPS', [FVCLView.TargetFPS, FVCLView.RealFPS]);
  end;
end;

end.
