unit Lizard;

{$I Lizard_Ver.inc}

interface

uses
{$IFDEF FPC}
  LCLIntf, LCLType, LMessages, Types, //messages,
  LizardMessages,
{$ELSE}
  Windows, Messages,
{$ENDIF}
  Classes, Controls, Forms, Graphics, ExtCtrls {shape of floating offscreen},
  ImgList,
{$IFDEF TBX2_GR32}
  GR32, GR32_Image,
{$ENDIF}

//SURFACE BACKEND
{$IFDEF FPC}
  LizardBase_LCL,
{$ELSE}
  LizardBase_VCL,
{$ENDIF}
  LizardConst;


type
  { TDockX2 }

  //TDockBoundLinesValues = (blTop, blBottom, blLeft, blRight);
  //TDockBoundLines = set of TDockBoundLinesValues;
  TDockPosition = (dpTop, dpBottom, dpLeft, dpRight);
  TDockType = (dtNotDocked, dtTopBottom, dtLeftRight);
  TDockableTo = set of TDockPosition;

  TCustomToolWindowX2 = class;

  //TInsertRemoveEvent = procedure(Sender: TObject; Inserting: Boolean;
    //Bar: TCustomToolWindowX2) of object;
  TRequestDockEvent = procedure(Sender: TObject; Bar: TCustomToolWindowX2;
    var Accept: Boolean) of object;


  //TDockX2 = class({$IFDEF TBX2_GR32}TCustomPaintBox32{$ELSE}TCustomPanel{$ENDIF})
  TDockX2 = class(TLzbPanel)
  private
    FPosition: TDockPosition;
    procedure SetPosition(AValue: TDockPosition);
  protected
    procedure PaintSurface; override;
    //procedure DockOver(Source: TDragDockObject; X, Y: Integer;
      //                 State: TDragState; var Accept: Boolean); override;
    procedure PositionDockRect(DragDockObject: TDragDockObject); override;
    procedure DoAddDockClient(Client: TControl; const ARect: TRect); override;


  public
    constructor Create(AOwner: TComponent); override;
  published
    property Color default clBtnFace;
    //property FixAlign: Boolean read FFixAlign write SetFixAlign default False;
    //property LimitToOneRow: Boolean read FLimitToOneRow write FLimitToOneRow default False;
    property Position: TDockPosition read FPosition write SetPosition default dpTop;

    //property OnRequestDock: TRequestDockEvent read FOnRequestDock write FOnRequestDock;
  end;


  { TCustomToolWindowX2 }

  TCustomToolWindowX2 = class(TLzbPanel)
  private
    FCloseButton: Boolean;
    FCloseButtonWhenDocked: Boolean;
    FDockableTo: TDockableTo;
    procedure DrawDockedNCArea;
    procedure SetCloseButton(AValue: Boolean);
    procedure SetCloseButtonWhenDocked(AValue: Boolean);

  protected
    procedure PaintSurface; override;
    procedure ArrangeControls; virtual;
    procedure DoDock(NewDockSite: TWinControl; var ARect: TRect); override;


    property DockableTo: TDockableTo read FDockableTo write FDockableTo default [dpTop, dpBottom, dpLeft, dpRight];
    property CloseButton: Boolean read FCloseButton write SetCloseButton default True;
    property CloseButtonWhenDocked: Boolean read FCloseButtonWhenDocked write SetCloseButtonWhenDocked default False;

  public
    constructor Create(AOwner: TComponent); override;

    {property DockedTo: TDockX2 read FDockedTo write SetDockedTo stored False;
    property DockPos: Integer read FDockPos write SetDockPos default -1;
    property DockRow: Integer read FDockRow write SetDockRow default 0;}

  end;



implementation

{ TCustomToolWindowX2 }

procedure TCustomToolWindowX2.PaintSurface;
begin
  inherited PaintSurface;
  DrawDockedNCArea;
end;

procedure TCustomToolWindowX2.ArrangeControls;
begin

end;

procedure TCustomToolWindowX2.DoDock(NewDockSite: TWinControl; var ARect: TRect );
begin
  //inherited DoDock(NewDockSite, ARect);
  if (NewDockSite = nil) then Parent := nil;
    if NewDockSite<>nil then begin
      //DebugLn('TControl.DoDock BEFORE Adjusting ',DbgSName(Self),' ',dbgs(ARect));
      // adjust new bounds, so that they at least fit into the client area of
      // its parent
      if NewDockSite.AutoSize then begin
        case align of
          alLeft,
          alRight : ARect:=Rect(0,0,Width,NewDockSite.ClientHeight);
          alTop,
          alBottom : ARect:=Rect(0,0,NewDockSite.ClientWidth,Height);
        else
          ARect:=Rect(0,0,Width,Height);
        end;
      end else begin
        //LCLProc.MoveRectToFit(ARect, NewDockSite.GetLogicalClientRect);
        ARect.TopLeft := NewDockSite.ScreenToClient(Arect.TopLeft);
        ARect.BottomRight := NewDockSite.ScreenToClient(Arect.BottomRight);
        // consider Align to increase chance the width/height is kept
        case Align of
          alLeft: OffsetRect(ARect,-ARect.Left,0);
          alTop: OffsetRect(ARect,0,-ARect.Top);
          alRight: OffsetRect(ARect,NewDockSite.ClientWidth-ARect.Right,0);
          alBottom: OffsetRect(ARect,0,NewDockSite.ClientHeight-ARect.Bottom);
        end;
      end;
      //DebugLn('TControl.DoDock AFTER Adjusting ',DbgSName(Self),' ',dbgs(ARect),' Align=',DbgS(Align),' NewDockSite.ClientRect=',dbgs(NewDockSite.ClientRect));
    end;
    //debugln('TControl.DoDock BEFORE MOVE ',Name,' BoundsRect=',dbgs(BoundsRect),' NewRect=',dbgs(ARect));
    if Parent<>NewDockSite then
      BoundsRectForNewParent := ARect
    else
      BoundsRect := ARect;
    //debugln('TControl.DoDock AFTER MOVE ',DbgSName(Self),' BoundsRect=',dbgs(BoundsRect),' TriedRect=',dbgs(ARect));
end;

constructor TCustomToolWindowX2.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle +
    [csAcceptsControls, csClickEvents, csDoubleClicks, csSetCaption] -
    [csCaptureMouse{capturing is done manually}, csOpaque];

  BorderStyle := bsSingle;
  FDockableTo := [dpTop, dpBottom, dpLeft, dpRight];

  DragKind := dkDock;
  DragMode:= dmAutomatic;

  Color := clBtnFace;
end;

procedure TCustomToolWindowX2.DrawDockedNCArea;
{ Redraws all the non-client area of the toolbar when it is docked. }
var
  DC: HDC;
  R: TRect;
  DockType: TDockType;
  X, Y, Y2, Y3, S, SaveIndex: Integer;
  R2, R3, R4: TRect;
  P1, P2: TPoint;
  Brush: HBRUSH;
  Clr: TColorRef;
  UsingBackground, B: Boolean;

  procedure DrawRaisedEdge (R: TRect; const FillInterior: Boolean);
  const
    FillMiddle: array[Boolean] of UINT = (0, BF_MIDDLE);
  begin
    DrawEdge (DC, R, BDR_RAISEDINNER, BF_RECT or FillMiddle[FillInterior]);
  end;

const
  CloseButtonState: array[Boolean] of UINT = (0, DFCS_PUSHED);
begin
  //if not DrawToDC then ValidateDockedNCArea;
  if {not Docked or} not HandleAllocated then Exit;
  Canvas.Brush.Color:= clRed;
  Canvas.FillRect(Rect(0,0,10,10));
(*
{$IFNDEF FPC}
  {if not DrawToDC then
    DC := GetWindowDC(Handle)
  else}
{$ENDIF}
    //DC := ADC;
    {$IFDEF TBX2_GR32}
    DC := Buffer.Canvas.Handle;
    {$ELSE}
    DC := Canvas.Handle;
    {$ENDIF}

  try
    { Use update region }
    //if not DrawToDC then  SelectNCUpdateRgn (Handle, DC, Clip);

    //x2nie avoid windows only. so we use both lazarus & delphi
    R := Rect(0, 0, Width, Height);

    { This works around WM_NCPAINT problem described at top of source code }
    {no!  R := Rect(0, 0, Width, Height);}
    //GetWindowRect (Handle, R); OffsetRect (R, -R.Left, -R.Top);


    if not(DockedTo.Position in PositionLeftOrRight) then
      DockType := dtTopBottom
    else
      DockType := dtLeftRight;

    Brush := CreateSolidBrush(ColorToRGB(Color));

    //UsingBackground := DockedTo.UsingBackground and DockedTo.FBkgOnToolbars;

    { Border }
    if BorderStyle = bsSingle then
      DrawRaisedEdge (R, False);
    //else
      //FrameRect (DC, R, Brush);
    R2 := R;
    InflateRect (R2, -1, -1);
    if not UsingBackground then
      FrameRect (DC, R2, Brush);

    { Draw the Background }
    {if UsingBackground then begin
      R2 := R;
      P1 := DockedTo.ClientToScreen(Point(0, 0));
      P2 := DockedTo.Parent.ClientToScreen(DockedTo.BoundsRect.TopLeft);
      Dec (R2.Left, Left + DockedTo.Left + (P1.X-P2.X));
      Dec (R2.Top, Top + DockedTo.Top + (P1.Y-P2.Y));
      InflateRect (R, -1, -1);
      GetWindowRect (Handle, R4);
      R3 := ClientRect;
      with ClientToScreen(Point(0, 0)) do
        OffsetRect (R3, X-R4.Left, Y-R4.Top);
      DockedTo.DrawBackground (DC, R, @R3, R2);
    end;}

    { The drag handle at the left, or top }
    if DockedTo.FAllowDrag then begin
      SaveIndex := SaveDC(DC);
      if DockType <> dtLeftRight then
        Y2 := ClientHeight
      else
        Y2 := ClientWidth;
      //Inc (Y2, DockedBorderSize);
      Y3 := Y2;
      S := DragHandleSizes[FCloseButtonWhenDocked, FDragHandleStyle];
      if FDragHandleStyle <> dhNone then begin
        X := DockedBorderSize + DragHandleOffsets[FCloseButtonWhenDocked, FDragHandleStyle];
        Y := DockedBorderSize;
        //if FDragHandleStyle = dhSingle then
        begin
          inc(Y);
          Dec(Y2);
        end;

        if FCloseButtonWhenDocked then begin
          if DockType <> dtLeftRight then
            Inc (Y, S - 2)
          else
            Dec (Y3, S - 2);
        end;
        Clr := GetSysColor(COLOR_BTNHIGHLIGHT);
        for B := False to (FDragHandleStyle = dhDouble) do begin
          if DockType <> dtLeftRight then
            R := Rect(X, Y, X+3, Y2)
          else
            R := Rect(Y, X, Y3, X+3);
          DrawRaisedEdge (R, True);
          {$IFNDEF FPC}
          if DockType <> dtLeftRight then
            SetPixelV (DC, X, Y2-1, Clr)
          else
            SetPixelV (DC, Y2-1, X, Clr);
          {$ENDIF}
          ExcludeClipRect (DC, R.Left, R.Top, R.Right, R.Bottom);
          Inc (X, 3);
        end;
      end;
      { Close button }
      if FCloseButtonWhenDocked then begin
        R := GetDockedCloseButtonRect(Self, DockType = dtLeftRight);
        DrawFrameControl (DC, R, DFC_CAPTION,
          DFCS_CAPTIONCLOSE or CloseButtonState[FCloseButtonDown]);
        ExcludeClipRect (DC, R.Left, R.Top, R.Right, R.Bottom);
      end;
      if not UsingBackground then begin
        if DockType <> dtLeftRight then
          R := Rect(DockedBorderSize, DockedBorderSize,
            DockedBorderSize+S, Y2)
        else
          R := Rect(DockedBorderSize, DockedBorderSize,
            Y2, DockedBorderSize+S);
        FillRect (DC, R, Brush);
      end;
      RestoreDC (DC, SaveIndex);
    end;

    DeleteObject (Brush);
  finally
    //if not DrawToDC then   ReleaseDC (Handle, DC);
  end;
*)
end;

procedure TCustomToolWindowX2.SetCloseButton(AValue: Boolean);
begin
  if FCloseButton=AValue then Exit;
  FCloseButton:=AValue;
  Invalidate;
end;

procedure TCustomToolWindowX2.SetCloseButtonWhenDocked(AValue: Boolean);
begin
  if FCloseButtonWhenDocked=AValue then Exit;
  FCloseButtonWhenDocked:=AValue;
  if {Docked} not Floating then
      //RecalcNCArea (Self);
    ArrangeControls;
  Invalidate;
end;


{ TDockX2 }

procedure TDockX2.SetPosition(AValue: TDockPosition);
begin
  if (FPosition <> AValue) and (ControlCount <> 0) then
    raise EInvalidOperation.Create(STBx2DockCannotChangePosition);
  FPosition := AValue;
  case Position of
    dpTop: Align := alTop;
    dpBottom: Align := alBottom;
    dpLeft: Align := alLeft;
    dpRight: Align := alRight;
  end;
end;

procedure TDockX2.PaintSurface;
var
  R, R2: TRect;
  P1, P2: TPoint;
begin
  inherited PaintSurface;
  //Buffer.Clear(Color32(self.Color));
  with Canvas do begin
    R := ClientRect;

    { Draw dotted border in design mode }
    if csDesigning in ComponentState then begin
      Pen.Style := psDot;
      Pen.Color := clBtnShadow;
      Brush.Style := bsClear;
      Rectangle (R.Left, R.Top, R.Right, R.Bottom);
      Pen.Style := psSolid;
      InflateRect (R, -1, -1);
    end;

    { Draw the Background }
    {if UsingBackground then begin
      R2 := ClientRect;
      // Make up for nonclient area
      P1 := ClientToScreen(Point(0, 0));
      P2 := Parent.ClientToScreen(BoundsRect.TopLeft);
      Dec (R2.Left, Left + (P1.X-P2.X));
      Dec (R2.Top, Top + (P1.Y-P2.Y));
      DrawBackground (Canvas.Handle, R, nil, R2);
    end;}
  end;
end;

procedure TDockX2.PositionDockRect(DragDockObject: TDragDockObject);
  //inherited PositionDockRect(DragDockObject);
var
  NewWidth, NewHeight: Integer;
  TempX, TempY: Double;
  Size: TPoint;

var
  //MouseOverDock : TDockX2;
  MoveRect : TRect;
  DPoint: TPoint;
  Tb : TCustomToolWindowX2;
begin
  if (DragDockObject.Control is TCustomToolWindowX2) then
  with DragDockObject do begin
    Tb := TCustomToolWindowX2(Control);
    //MouseOverDock := TDockX2(DragTarget);
    DPoint := Point(Tb.Width, Tb.Height);
    {if Position in Tb.DockableTo then
      Size := Tb.OrderControls(False, GetDockTypeOf(Tb.DockedTo), Self)
    else}
      Size := Tb.ClientRect.BottomRight;

    // Drag position for dock rect is scaled relative to control's click point.
    {$IFNDEF FPC}
    TempX := DragPos.X - ((Size.X) * MouseDeltaX);
    TempY := DragPos.Y - ((Size.Y) * MouseDeltaY);
    {$ELSE}
    TempX := DragPos.X - ((Size.X) );
    TempY := DragPos.Y - ((Size.Y) );
    {$ENDIF}

    {MoveRect := Bounds(DragPos.X-MulDiv(Size.X-1, DragPos.X, DPoint.X),
        DragPos.Y-MulDiv(Size.Y-1, DragPos.Y, DPoint.Y),
        Size.X, Size.Y);}

    MoveRect := Bounds(Round(TempX), Round(TempY),
        Size.X, Size.Y);

    with MoveRect do begin
      Left := DragPos.x;
      Top := DragPos.y;
      Right := Left + Size.X;
      Bottom:= Top + Size.Y;
    end;
    // let user adjust dock rect
    OffsetRect( MoveRect, -DockOffset.x, -DockOffset.y);
    DragDockObject.DockRect := MoveRect;


      //AddDockedNCAreaToSize (Size, Dock.Position in PositionLeftOrRight);
  end
  else
    inherited;
end;

procedure TDockX2.DoAddDockClient(Client: TControl; const ARect: TRect);
begin
  if Client.Parent <> self Then
    inherited DoAddDockClient(Client, ARect);
  //Client.Align := alTop;
  //Client.Align := AlNone;
  Client.Align := alCustom;
  with Arect do
  Client.SetBounds(Left, Top, Right-Left, Bottom-TOp);
end;

(*procedure TDockX2.DockOver(Source: TDragDockObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
var R,r2 :TRect;
  P : TPoint;
begin
  //inherited DockOver(Source, X, Y, State, Accept);

  Accept := Source.Control is TCustomToolWindowX2;
  if Accept then begin
    Source.DropAlign:=alTop;
    R2 := source.Control.BoundsRect;

    //R.TopLeft
    P := ClientToScreen(Point(X,Y));
    OffsetRect(R2,P.X,P.Y);

    P := Source.DockOffset;
    OffsetRect(R2,-P.X,-P.Y);

    R.Right := R.Left+36;
    R.Bottom:= R.Top+26;

    Source.DockRect :=  R2;

  end;
  //if State = dsDragMove then    PositionDockRect(Source);
  DoDockOver(Source, X, Y, State, Accept);
end;*)

constructor TDockX2.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csAcceptsControls] -
    [csClickEvents, csCaptureMouse, csOpaque];
  Color := clBtnFace;
  Position := dpTop;
  DockSite:=True;
end;

end.

