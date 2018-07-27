{*******************************************************}
{                                                       }
{               HCView V1.0  作者：荆通                 }
{                                                       }
{      本代码遵循BSD协议，你可以加入QQ群 649023932      }
{            来获取更多的技术交流 2018-5-4              }
{                                                       }
{                文档对象基类实现单元                   }
{                                                       }
{*******************************************************}

unit HCItem;

interface

uses
  Windows, Classes, Controls, Graphics, Generics.Collections, HCStyle, HCUndo;

type
  TZoomInfo = record
    MapMode: Integer;
    WindowOrg: TSize;
    WindowExt: TSize;
    ViewportOrg: TSize;
    ViewportExt: TSize;
  end;

  TItemOptions = set of (ioParaFirst, ioSelectPart, ioSelectComplate);

  THCCustomItemClass = class of THCCustomItem;

  THCCustomItem = class;

  TPaintInfo = class(TObject)  // 绘制时的信息，用于给外部事件增加更多的信息
  private
    FPrint: Boolean;
    FTopItems: TObjectList<THCCustomItem>;
    FWindowWidth, FWindowHeight: Integer;
    FScaleX, FScaleY: Single;
  public
    constructor Create;
    destructor Destroy; override;
    function ZoomCanvas(const ACanvas: TCanvas): TZoomInfo;
    procedure RestoreCanvasZoom(const ACanvas : TCanvas; const AOldInfo: TZoomInfo);
    function GetScaleX(const AValue: Integer): Integer;
    function GetScaleY(const AValue: Integer): Integer;
    procedure DrawNoScaleLine(const ACanvas: TCanvas; const APoints: array of TPoint);

    property Print: Boolean read FPrint write FPrint;

    /// <summary> 只管理不负责释放 </summary>
    property TopItems: TObjectList<THCCustomItem> read FTopItems;

    /// <summary> 用于绘制的区域高度 </summary>
    property WindowWidth: Integer read FWindowWidth write FWindowWidth;

    /// <summary> 用于绘制的区域宽度 </summary>
    property WindowHeight: Integer read FWindowHeight write FWindowHeight;

    /// <summary> 横向缩放 </summary>
    property ScaleX: Single read FScaleX write FScaleX;

    /// <summary> 纵向缩放 </summary>
    property ScaleY: Single read FScaleY write FScaleY;
  end;

  THCCustomItem = class(TObject)
  strict private
    FParaNo,
    FStyleNo,
    FFirstDItemNo: Integer;
    FActive, FVisible: Boolean;
    FOptions: TItemOptions;
  protected
    function GetParaFirst: Boolean;
    procedure SetParaFirst(const Value: Boolean);
    function GetSelectComplate: Boolean; virtual;
    function GetSelectPart: Boolean;
    function GetText: string; virtual;
    procedure SetText(const Value: string); virtual;
    procedure SetActive(const Value: Boolean); virtual;
    function GetLength: Integer; virtual;
    procedure DoPaint(const AStyle: THCStyle; const ADrawRect: TRect;
      const ADataDrawTop, ADataDrawBottom, ADataScreenTop, ADataScreenBottom: Integer;
      const ACanvas: TCanvas; const APaintInfo: TPaintInfo); virtual;
  public
    constructor Create; virtual;

    procedure Assign(Source: THCCustomItem); virtual;
    /// <summary>
    /// 绘制Item的事件
    /// </summary>
    /// <param name="ACanvas"></param>
    /// <param name="ADrawRect">当前DrawItem的区域</param>
    /// <param name="ADataDrawBottom">Item所在的Data本次绘制底部位置</param>
    /// <param name="ADataScreenTop"></param>
    /// <param name="ADataScreenBottom"></param>
    procedure PaintTo(const AStyle: THCStyle; const ADrawRect: TRect;
      const APageDataDrawTop, APageDataDrawBottom, APageDataScreenTop, APageDataScreenBottom: Integer;
      const ACanvas: TCanvas; const APaintInfo: TPaintInfo); virtual; final;  // 不可继承

    procedure PaintTop(const ACanvas: TCanvas); virtual;

    /// <summary>
    /// 将2个Item合并为同一个
    /// </summary>
    /// <param name="AItemA">ItemA</param>
    /// <param name="AItemB">ItemB</param>
    /// <returns>True合并成功，否则返回False</returns>
    function CanConcatItems(const AItem: THCCustomItem): Boolean; virtual;

    procedure DisSelect; virtual;
    function CanDrag: Boolean; virtual;
    procedure KillFocus; virtual;
    procedure DblClick(const X, Y: Integer); virtual;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); virtual;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); virtual;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); virtual;
    procedure MouseEnter; virtual;
    procedure MouseLeave; virtual;
    function GetHint: string; virtual;
    procedure SelectComplate; virtual;
    procedure SelectPart;
    /// <summary> 从指定位置将当前item分成前后两部分 </summary>
    /// <param name="AOffset">分裂位置</param>
    /// <returns>后半部分对应的Item</returns>
    function BreakByOffset(const AOffset: Integer): THCCustomItem; virtual;
    procedure SaveToStream(const AStream: TStream); overload;
    procedure SaveToStream(const AStream: TStream; const AStart, AEnd: Integer); overload; virtual;
    procedure LoadFromStream(const AStream: TStream; const AStyle: THCStyle;
      const AFileVersion: Word); virtual;

    // 撤销重做相关方法
    procedure Undo(const AObject: TObject);
    procedure Redo(const AObject: TObject);
    //
    property Options: TItemOptions read FOptions;
    property Text: string read GetText write SetText;
    property Length: Integer read GetLength;
    property ParaFirst: Boolean read GetParaFirst write SetParaFirst;

    property IsSelectComplate: Boolean read GetSelectComplate;
    property IsSelectPart: Boolean read GetSelectPart;

    property StyleNo: Integer read FStyleNo write FStyleNo;
    property ParaNo: Integer read FParaNo write FParaNo;
    property FirstDItemNo: Integer read FFirstDItemNo write FFirstDItemNo;
    property Active: Boolean read FActive write SetActive;
    property Visible: Boolean read FVisible write FVisible;
  end;

  TItemNotifyEvent = procedure(const AItem: THCCustomItem) of object;

  THCItems = class(TObjectList<THCCustomItem>)
  private
    FOnItemInsert: TItemNotifyEvent;
  protected
    procedure Notify(const Value: THCCustomItem; Action: TCollectionNotification); override;
  public
    property OnItemInsert: TItemNotifyEvent read FOnItemInsert write FOnItemInsert;
  end;

implementation

{ THCCustomItem }

function THCCustomItem.CanDrag: Boolean;
begin
  Result := True;
end;

procedure THCCustomItem.Assign(Source: THCCustomItem);
begin
  Self.FStyleNo := Source.StyleNo;
  Self.FParaNo := Source.ParaNo;
  Self.FOptions := Source.Options;
end;

function THCCustomItem.BreakByOffset(const AOffset: Integer): THCCustomItem;
begin
  // 继承者自己判断能否Break
  Result := THCCustomItemClass(Self.ClassType).Create;
  Result.Assign(Self);
  Result.ParaFirst := False;  // 打断后，后面的肯定不是断首
end;

function THCCustomItem.CanConcatItems(const AItem: THCCustomItem): Boolean;
begin
  // 本方法只支持判断源AItem不是段首，不判断自己是否为段首
  Result := (Self.ClassType = AItem.ClassType)
    and (Self.FStyleNo = AItem.StyleNo)
    //and (not AItem.ParaFirst);  // 源Item不是段首，遇到需要跨段合并的可见201804111209
end;

constructor THCCustomItem.Create;
begin
  FStyleNo := THCStyle.RsNull;
  FParaNo := THCStyle.RsNull;
  FFirstDItemNo := -1;
  FVisible := True;
  FActive := False;
end;

procedure THCCustomItem.DblClick(const X, Y: Integer);
begin
end;

procedure THCCustomItem.DisSelect;
begin
  FOptions := Self.Options - [ioSelectPart, ioSelectComplate];  // 处理自己的全选、部分选状态
end;

procedure THCCustomItem.DoPaint(const AStyle: THCStyle; const ADrawRect: TRect;
  const ADataDrawTop, ADataDrawBottom, ADataScreenTop, ADataScreenBottom: Integer;
  const ACanvas: TCanvas; const APaintInfo: TPaintInfo);
begin
end;

function THCCustomItem.GetHint: string;
begin
  Result := '';
end;

function THCCustomItem.GetLength: Integer;
begin
  Result := 0;
end;

function THCCustomItem.GetParaFirst: Boolean;
begin
  Result := ioParaFirst in FOptions;
end;

function THCCustomItem.GetSelectComplate: Boolean;
begin
  Result := ioSelectComplate in FOptions;
end;

function THCCustomItem.GetSelectPart: Boolean;
begin
  Result := ioSelectPart in FOptions;
end;

function THCCustomItem.GetText: string;
begin
  Result := '';
end;

procedure THCCustomItem.KillFocus;
begin
end;

procedure THCCustomItem.LoadFromStream(const AStream: TStream;
  const AStyle: THCStyle; const AFileVersion: Word);
var
  vParFirst: Boolean;
begin
  //AStream.ReadBuffer(FStyleNo, SizeOf(FStyleNo));  // 由TCustomData.InsertStream处加载了
  AStream.ReadBuffer(FParaNo, SizeOf(FParaNo));
  AStream.ReadBuffer(vParFirst, SizeOf(vParFirst));
  ParaFirst := vParFirst;
end;

procedure THCCustomItem.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  Active := True;
end;

procedure THCCustomItem.MouseEnter;
begin
end;

procedure THCCustomItem.MouseLeave;
begin
end;

procedure THCCustomItem.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
end;

procedure THCCustomItem.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
end;

procedure THCCustomItem.PaintTo(const AStyle: THCStyle; const ADrawRect: TRect;
  const APageDataDrawTop, APageDataDrawBottom, APageDataScreenTop, APageDataScreenBottom: Integer;
  const ACanvas: TCanvas; const APaintInfo: TPaintInfo);
var
  vDCState: Integer;
begin
  vDCState := Windows.SaveDC(ACanvas.Handle);
  try
    DoPaint(AStyle, ADrawRect, APageDataDrawTop, APageDataDrawBottom,
      APageDataScreenTop, APageDataScreenBottom, ACanvas, APaintInfo);
  finally
    Windows.RestoreDC(ACanvas.Handle, vDCState);
    ACanvas.Refresh;  // 恢复Pen的修改
  end;
end;

procedure THCCustomItem.PaintTop(const ACanvas: TCanvas);
begin
end;

procedure THCCustomItem.Redo(const AObject: TObject);
begin
  if AObject is THCUndoList then
    THCUndoList(AObject).Redo;
end;

procedure THCCustomItem.SelectComplate;
begin
  Exclude(FOptions, ioSelectPart);
  Include(FOptions, ioSelectComplate);
end;

procedure THCCustomItem.SelectPart;
begin
  Exclude(FOptions, ioSelectComplate);
  Include(FOptions, ioSelectPart);
end;

procedure THCCustomItem.SetText(const Value: string);
begin
end;

procedure THCCustomItem.Undo(const AObject: TObject);
begin
  if AObject is THCUndoList then
    THCUndoList(AObject).Undo;
end;

procedure THCCustomItem.SaveToStream(const AStream: TStream);
begin
  SaveToStream(AStream, 0, Self.Length);
end;

procedure THCCustomItem.SaveToStream(const AStream: TStream; const AStart,
  AEnd: Integer);
var
  vParFirst: Boolean;
begin
  AStream.WriteBuffer(FStyleNo, SizeOf(FStyleNo));
  AStream.WriteBuffer(FParaNo, SizeOf(FParaNo));

  vParFirst := ParaFirst;
  AStream.WriteBuffer(vParFirst, SizeOf(vParFirst));
end;

procedure THCCustomItem.SetActive(const Value: Boolean);
begin
  FActive := Value;
end;

procedure THCCustomItem.SetParaFirst(const Value: Boolean);
begin
  if Value then
    Include(FOptions, ioParaFirst)
  else
    Exclude(FOptions, ioParaFirst);
end;

{ THCItems }

procedure THCItems.Notify(const Value: THCCustomItem;
  Action: TCollectionNotification);
begin
  inherited;
  case Action of
    cnAdded:
      begin
        if Assigned(FOnItemInsert) then
          FOnItemInsert(Value);
      end;

    cnRemoved: ;
    cnExtracted: ;
  end;
end;

{ TPaintInfo }

constructor TPaintInfo.Create;
begin
  FTopItems := TObjectList<THCCustomItem>.Create(False);  // 只管理不负责释放
end;

destructor TPaintInfo.Destroy;
begin
  FTopItems.Free;
  inherited Destroy;
end;

procedure TPaintInfo.DrawNoScaleLine(const ACanvas: TCanvas;
  const APoints: array of TPoint);
var
  vPt: TPoint;
  i: Integer;
begin
  SetViewportExtEx(ACanvas.Handle, FWindowWidth, FWindowHeight, @vPt);
  try
    ACanvas.MoveTo(GetScaleX(APoints[0].X), GetScaleY(APoints[0].Y));
    for i := 1 to Length(APoints) - 1 do
      ACanvas.LineTo(GetScaleX(APoints[i].X), GetScaleY(APoints[i].Y));
  finally
    SetViewportExtEx(ACanvas.Handle, Round(FWindowWidth * FScaleX),
      Round(FWindowHeight * FScaleY), @vPt);
  end;
end;

function TPaintInfo.GetScaleX(const AValue: Integer): Integer;
begin
  Result := Round(AValue * FScaleX);
end;

function TPaintInfo.GetScaleY(const AValue: Integer): Integer;
begin
  Result := Round(AValue * FScaleY);
end;

procedure TPaintInfo.RestoreCanvasZoom(const ACanvas: TCanvas;
  const AOldInfo: TZoomInfo);
begin
  SetViewportOrgEx(ACanvas.Handle, AOldInfo.ViewportOrg.cx, AOldInfo.ViewportOrg.cy, nil);
  SetViewportExtEx(ACanvas.Handle, AOldInfo.ViewportExt.cx, AOldInfo.ViewportExt.cy, nil);
  SetWindowOrgEx(ACanvas.Handle, AOldInfo.WindowOrg.cx, AOldInfo.WindowOrg.cy, nil);
  SetWindowExtEx(ACanvas.Handle, AOldInfo.WindowExt.cx, AOldInfo.WindowExt.cy, nil);
  SetMapMode(ACanvas.Handle, AOldInfo.MapMode);
end;

function TPaintInfo.ZoomCanvas(const ACanvas: TCanvas): TZoomInfo;
begin
  Result.MapMode := GetMapMode(ACanvas.Handle);  // 返回映射方式，零则失败
  SetMapMode(ACanvas.Handle, MM_ANISOTROPIC);  // 逻辑单位转换成具有任意比例轴的任意单位，用SetWindowsEx和SetViewportExtEx函数指定单位、方向和需要的比例
  SetWindowOrgEx(ACanvas.Handle, 0, 0, @Result.WindowOrg);  // 用指定的坐标设置设备环境的窗口原点
  SetWindowExtEx(ACanvas.Handle, FWindowWidth,  // 为设备环境设置窗口的水平的和垂直的范围
    FWindowHeight, @Result.WindowExt);

  SetViewportOrgEx(ACanvas.Handle, 0, 0, @Result.ViewportOrg);  // 哪个设备点映射到窗口原点(0,0)
  // 用指定的值来设置指定设备环境坐标的X轴、Y轴范围
  SetViewportExtEx(ACanvas.Handle, Round(FWindowWidth * FScaleX),
    Round(FWindowHeight * FScaleY), @Result.ViewportExt);
end;

end.
