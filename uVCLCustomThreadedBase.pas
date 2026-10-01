{*******************************************************************************
  VCLCustomThreadedBase
********************************************************************************
  The "Mother of all ThreadedBases" - utilizing pure GDI for off-screen rendering.
  Exact same thread architecture as Flowmotion.
*******************************************************************************}
{ VCL-Threaded-Renderer v1.0                                                 }
{ by Lara Miriam Tamy Reschke                                                  }
{                                                                              }
{------------------------------------------------------------------------------}
{
  Latest Changes:
   v 1.0:
   - Stripped everything down to EXACTLY the Flowmotion thread core.
   - Implemented QPC (TStopwatch) precision timing for exact TargetFPS matching.
   - Re-enabled VCL DoubleBuffered to kill GDI flicker (just like Flowmotion).
}

unit uVCLCustomThreadedBase;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Math, Diagnostics;

type
  { High Precision Timer based on TStopwatch (QPC wrapper) }
  THighResTimer = record
    Frequency: Int64;
    procedure Init;
    function GetTicks: Int64;
    procedure HybridWaitUntil(const ATargetTicks, ASpinNanoseconds: Int64);
  end;

  { TAnimationThread - EXACTLY like in Flowmotion }
  TAnimationThread = class(TThread)
  private
    FOwner: TCustomControl;
    FStopRequested: Boolean;
    FEvent: THandle;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TCustomControl);
    destructor Destroy; override;
    procedure Stop;
  end;

  { TVCLCustomThreadedBase }
  TVCLCustomThreadedBase = class(TCustomControl)
  private
    FAnimationThread: TAnimationThread;
    FTargetFPS: Integer;
    FThreadActive: Boolean;
    FPaused: Boolean;
    FActive: Boolean;

    { RealFPS Tracking }
    FFPSStartTime: Cardinal;
    FFrameCount: Integer;
    FRealFPS: Integer;

    { Demo Mode State }
    FCubeX, FCubeY, FCubeZ: Single;
    FCubeRotX, FCubeRotY, FCubeRotZ: Single;
    FCubeVX, FCubeVY, FCubeVZ: Single;
    FCubeRotVX, FCubeRotVY, FCubeRotVZ: Single;
    FAngle: Single;

    { Calculated Screen Points }
    FScreenPts: array[0..7] of TPoint;
    FCurrentColor: TColor;

    procedure SetActive(const Value: Boolean);
    procedure SetTargetFPS(const Value: Integer);

    procedure StartAnimationThread;
    procedure StopAnimationThread;
    procedure ThreadSafeInvalidate;
    procedure PerformAnimationUpdate(DeltaMS: Cardinal);

    procedure WMUser1(var Message: TMessage); message WM_USER + 1;
  protected
    procedure Paint; override;
    procedure UpdateLogic(const DeltaTime: Double); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property RealFPS: Integer read FRealFPS;
  published
    property Align;
    property Anchors;
    property Color;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;

    property Active: Boolean read FActive write SetActive default False;
    property TargetFPS: Integer read FTargetFPS write SetTargetFPS default 60;
  end;

procedure Register;

implementation

uses
  MMSystem;

const
  SPIN_THRESHOLD_NS = 2000000; // 2 ms

  CubeVertices: array[0..7, 0..2] of Single = (
    (-1, -1, -1), ( 1, -1, -1), ( 1,  1, -1), (-1,  1, -1),
    (-1, -1,  1), ( 1, -1,  1), ( 1,  1,  1), (-1,  1,  1)
  );
  CubeEdges: array[0..11, 0..1] of Byte = (
    (0,1), (1,2), (2,3), (3,0),
    (4,5), (5,6), (6,7), (7,4),
    (0,4), (1,5), (2,6), (3,7)
  );

procedure Register;
begin
  RegisterComponents('LaMita Components', [TVCLCustomThreadedBase]);
end;

{==============================================================================
  THighResTimer Implementation
==============================================================================}

procedure THighResTimer.Init;
begin
  Frequency := TStopwatch.Frequency;
end;

function THighResTimer.GetTicks: Int64;
begin
  Result := TStopwatch.GetTimestamp;
end;

procedure THighResTimer.HybridWaitUntil(const ATargetTicks, ASpinNanoseconds: Int64);
var
  SpinTicks, Remaining: Int64;
begin
  if Frequency = 0 then Exit;
  SpinTicks := (ASpinNanoseconds * Frequency) div 1000000000;

  Remaining := ATargetTicks - GetTicks;
  while Remaining > SpinTicks do
  begin
    Sleep(1);
    Remaining := ATargetTicks - GetTicks;
  end;
  while GetTicks < ATargetTicks do ;
end;

{==============================================================================
  TAnimationThread Implementation (Flowmotion Core with QPC Timing)
==============================================================================}

constructor TAnimationThread.Create(AOwner: TCustomControl);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FStopRequested := False;
  FEvent := CreateEvent(nil, True, False, nil);
end;

destructor TAnimationThread.Destroy;
begin
  CloseHandle(FEvent);
  inherited Destroy;
end;

procedure TAnimationThread.Stop;
begin
  FStopRequested := True;
  SetEvent(FEvent);
end;

procedure TAnimationThread.Execute;
var
  Timer: THighResTimer;
  Freq, FrameTicks: Int64;
  NextFrame, NowTicks, LastFrameTicks: Int64;
  Base: TVCLCustomThreadedBase;
begin
  Base := TVCLCustomThreadedBase(FOwner);
  Timer.Init;
  Freq := Timer.Frequency;

  NowTicks := Timer.GetTicks;
  LastFrameTicks := NowTicks;
  NextFrame := NowTicks;

  timeBeginPeriod(1);
  try
    while not Terminated and not FStopRequested do
    begin
      // 1. Execute the main animation logic (Pass DeltaTime in MS)
      NowTicks := Timer.GetTicks;
      Base.PerformAnimationUpdate(Round((NowTicks - LastFrameTicks) * 1000 / Freq));
      LastFrameTicks := NowTicks;

      // 2. Calculate timing for the next frame using QPC absolute deadlines
      if Base.FTargetFPS > 0 then
        FrameTicks := Round(Freq / Base.FTargetFPS)
      else
        FrameTicks := Freq div 60;

      NextFrame := NextFrame + FrameTicks;

      NowTicks := Timer.GetTicks;
      if NextFrame <= NowTicks then
        NextFrame := NowTicks + FrameTicks;

      // 3. Wait until the next frame is due (Hybrid Sleep/SpinWait)
      if WaitForSingleObject(FEvent, 0) = WAIT_OBJECT_0 then
        Break;

      Timer.HybridWaitUntil(NextFrame, SPIN_THRESHOLD_NS);
    end;
  finally
    timeEndPeriod(1);
  end;
end;


{==============================================================================
  TVCLCustomThreadedBase
==============================================================================}

constructor TVCLCustomThreadedBase.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];

  // CRITICAL FIX: VCL DoubleBuffered is required to prevent GDI flicker.
  // Flowmotion also uses DoubleBuffered := True.
  // It buffers the Canvas commands off-screen and pushes them instantly.
  DoubleBuffered := True;

  FThreadActive := False;
  FPaused := True;
  FActive := False;
  FTargetFPS := 60;

  FFPSStartTime := GetTickCount();
  FFrameCount := 0;
  FRealFPS := 0;

  Width := 300;
  Height := 200;

  // Demo Mode Init
  FCubeX := 0; FCubeY := 0; FCubeZ := 400;
  FCubeRotX := 0; FCubeRotY := 0; FCubeRotZ := 0;
  FCubeVX := 150; FCubeVY := 100; FCubeVZ := 50;
  FCubeRotVX := 1.2; FCubeRotVY := 0.8; FCubeRotVZ := 0.5;
  FAngle := 0.0;

  Invalidate;
end;

destructor TVCLCustomThreadedBase.Destroy;
begin
  StopAnimationThread;
  inherited;
end;

procedure TVCLCustomThreadedBase.StartAnimationThread;
begin
  if FThreadActive then Exit;
  FThreadActive := True;
  FAnimationThread := TAnimationThread.Create(Self);
end;

procedure TVCLCustomThreadedBase.StopAnimationThread;
begin
  if not FThreadActive then Exit;
  if Assigned(FAnimationThread) then
  begin
    FAnimationThread.Stop;
    FAnimationThread.WaitFor;
    FreeAndNil(FAnimationThread);
  end;
  FThreadActive := False;
end;

procedure TVCLCustomThreadedBase.ThreadSafeInvalidate;
begin
  if csDestroying in ComponentState then Exit;
  // EXACTLY LIKE FLOWMOTION
  if GetCurrentThreadId = MainThreadId then
    Invalidate
  else
    PostMessage(Handle, WM_USER + 1, 0, 0);
end;

procedure TVCLCustomThreadedBase.WMUser1(var Message: TMessage);
begin
  if not (csDestroying in ComponentState) then
    Invalidate;
end;

procedure TVCLCustomThreadedBase.PerformAnimationUpdate(DeltaMS: Cardinal);
var
  DeltaTime: Double;
begin
  if not FActive then Exit;

  DeltaTime := DeltaMS / 1000.0;
  if DeltaTime <= 0 then
    DeltaTime := 0.016;

  UpdateLogic(DeltaTime);
  ThreadSafeInvalidate;
end;

procedure TVCLCustomThreadedBase.UpdateLogic(const DeltaTime: Double);
var
  i: Integer;
  Rotated, Translated: array[0..7, 0..2] of Single;
  v: array[0..2] of Single;
  s, c: Single;
  HalfW, HalfH: Integer;
  FocalLen, ProjectedX, ProjectedY: Single;
  PulseFactor, GVal: Single;
begin
  // 1. Move Cube
  FCubeX := FCubeX + FCubeVX * DeltaTime;
  FCubeY := FCubeY + FCubeVY * DeltaTime;
  FCubeZ := FCubeZ + FCubeVZ * DeltaTime;

  if (FCubeZ < 200) or (FCubeZ > 800) then FCubeVZ := -FCubeVZ;
  if FCubeX < -150 then
  begin
    FCubeX := -150;
    FCubeVX := Abs(FCubeVX);
  end
  else if FCubeX > 150 then
  begin
    FCubeX := 150;
    FCubeVX := -Abs(FCubeVX);
  end;
  if FCubeY < -100 then
  begin
    FCubeY := -100;
    FCubeVY := Abs(FCubeVY);
  end
  else if FCubeY > 100 then
  begin
    FCubeY := 100;
    FCubeVY := -Abs(FCubeVY);
  end;

  // 2. Rotate Cube
  FCubeRotX := FCubeRotX + FCubeRotVX * DeltaTime;
  FCubeRotY := FCubeRotY + FCubeRotVY * DeltaTime;
  FCubeRotZ := FCubeRotZ + FCubeRotVZ * DeltaTime;
  FAngle := FAngle + (3.0 * DeltaTime);

  // 3. Calculate Math & Projection (Store in FScreenPts so Paint can use it directly)
  HalfW := Self.Width div 2;
  HalfH := Self.Height div 2;
  FocalLen := 300.0 / (FCubeZ / 1000.0);

  for i := 0 to 7 do
  begin
    v[0] := CubeVertices[i,0];
    v[1] := CubeVertices[i,1];
    v[2] := CubeVertices[i,2];

    s := Sin(FCubeRotX); c := Cos(FCubeRotX);
    Rotated[i,0] := v[0];
    Rotated[i,1] := v[1] * c - v[2] * s;
    Rotated[i,2] := v[1] * s + v[2] * c;

    s := Sin(FCubeRotY); c := Cos(FCubeRotY);
    v[0] := Rotated[i,0] * c + Rotated[i,2] * s;
    v[2] := -Rotated[i,0] * s + Rotated[i,2] * c;
    Rotated[i,0] := v[0];
    Rotated[i,2] := v[2];

    s := Sin(FCubeRotZ); c := Cos(FCubeRotZ);
    v[0] := Rotated[i,0] * c - Rotated[i,1] * s;
    v[1] := Rotated[i,0] * s + Rotated[i,1] * c;
    Rotated[i,0] := v[0];
    Rotated[i,1] := v[1];

    Translated[i,0] := Rotated[i,0] * 50 + FCubeX;
    Translated[i,1] := Rotated[i,1] * 50 + FCubeY;
    Translated[i,2] := Rotated[i,2] * 50 + FCubeZ;

    ProjectedX := (Translated[i,0] * FocalLen) / Translated[i,2];
    ProjectedY := (Translated[i,1] * FocalLen) / Translated[i,2];

    FScreenPts[i].X := HalfW + Round(ProjectedX);
    FScreenPts[i].Y := HalfH + Round(ProjectedY);
  end;

  // Calculate Color
  PulseFactor := (Sin(FAngle) + 1) / 2;
  GVal := PulseFactor * 255;
  FCurrentColor := RGB(255, Round(GVal), Round(255 - GVal));
end;

procedure TVCLCustomThreadedBase.Paint;
var
  i: Integer;
  CurrentTickCount: Cardinal;
begin
  // Paint DIRECTLY on the Control's Canvas, EXACTLY like Flowmotion.
  Canvas.Brush.Color := clBlack;
  Canvas.FillRect(ClientRect);

  if FActive then
  begin
    Canvas.Pen.Color := FCurrentColor;
    Canvas.Pen.Width := 2;
    Canvas.Brush.Style := bsClear;

    for i := 0 to 11 do
    begin
      Canvas.MoveTo(FScreenPts[CubeEdges[i,0]].X, FScreenPts[CubeEdges[i,0]].Y);
      Canvas.LineTo(FScreenPts[CubeEdges[i,1]].X, FScreenPts[CubeEdges[i,1]].Y);
    end;
  end
  else
  begin
    Canvas.Brush.Color := $1E1E1E;
    Canvas.FillRect(ClientRect);

    Canvas.Font.Color := clWhite;
    Canvas.Font.Size := 12;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(20, ClientHeight div 2, 'Thread Active: Paused');
    Canvas.TextOut(20, (ClientHeight div 2) + 25, 'Set Active = True to Demo');
  end;

  // Real FPS Measurement
  Inc(FFrameCount);
  CurrentTickCount := GetTickCount();
  if (CurrentTickCount - FFPSStartTime) >= 1000 then
  begin
    FRealFPS := Round((FFrameCount * 1000) / (CurrentTickCount - FFPSStartTime));
    FFrameCount := 0;
    FFPSStartTime := CurrentTickCount;
  end;
end;

procedure TVCLCustomThreadedBase.SetActive(const Value: Boolean);
begin
  if FActive <> Value then
  begin
    FActive := Value;
    if FActive then
    begin
      if not FThreadActive then
        StartAnimationThread;
      FPaused := False;
    end
    else
    begin
      FPaused := True;
    end;
    ThreadSafeInvalidate;
  end;
end;

procedure TVCLCustomThreadedBase.SetTargetFPS(const Value: Integer);
begin
  if FTargetFPS <> Value then
    FTargetFPS := Value;
end;

end.
