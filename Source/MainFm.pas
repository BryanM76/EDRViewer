unit MainFm;
{************************************************************************
 *
 *  Module:       MainFm.pas
 *  Description:  EDR Viewer Main Form
 *
 *  Runtime Env.: Win32, Linux, macOS
 *  Author(s):    Bryan Mitchell
 *  Company:      Private
 *
 *   This program is free software; you can redistribute it and/or
 *   modify it under the terms of the GNU General Public License
 *   as published by the Free Software Foundation; either version 2
 *   of the License, or (at your option) any later version.
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 ************************************************************************}
{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}
{$IFDEF VER130}   //Delphi 5
  {$DEFINE WINDOWS}
{$ENDIF}

interface

uses
{$IFNDEF FPC}
  Windows, TeeProcs, TeEngine, Series, Chart,
{$ELSE}
  FPImage, IntfGraphics, TAGraph, TASeries, LCLType, LResources,
{$ENDIF}
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Menus, ExtCtrls,
  ComCtrls, StdCtrls, Math, PDSInfo, FileParser, SDDPTInfo, VICARInfo;

{$I VersionLabel.inc}
const
  PAGE_HISTOGRAM = 1;
  PAGE_CONTROLS  = 2;

  DEF_WINDOW_WIDTH = 512;
  DEF_WINDOW_HEIGHT = 512;
  {$IFDEF WINDOWS}
  NL = #13#10;
  {$ELSE}
  NL = #13;
  {$ENDIF}

{$IFDEF FPC}
type
  {$IFDEF LINUX}
  TCustomRGBQuad = tagRGBQUAD;
  {$ENDIF}
  {$IFDEF DARWIN}
  TCustomRGBQUAD = record
    rgbReserved : BYTE;
    rgbRed : BYTE;
    rgbGreen : BYTE;
    rgbBlue : BYTE;
  end;
  {$ENDIF}
  {$IFDEF WINDOWS}
  TCustomRGBQuad = tagRGBQUAD;
  {$ENDIF}
  TRGBQuadArray = array[0..32767] of TCustomRGBQUAD;
  PRGBQuadArray = ^TRGBQuadArray;
{$ENDIF}

type THistoData = record
  DataType: string;
  DataSize:integer;
  Count: integer;
  Channel0Data: TPDSData;
  Channel1Data: TPDSData;
  Channel2Data: TPDSData;
end;

type

  { TMainForm }

  TMainForm = class(TForm)
    BtnDebug: TButton;
    CheckBoxRed: TCheckBox;
    CheckBoxGreen: TCheckBox;
    CheckBoxBlue: TCheckBox;
    MainMenu: TMainMenu;
    File1: TMenuItem;
    Open1: TMenuItem;
    SaveAs1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    Help1: TMenuItem;
    About1: TMenuItem;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    StatusBar: TStatusBar;
    OpenColourImage1: TMenuItem;
    PageControl: TPageControl;
    TabImage: TTabSheet;
    TabHistoRed: TTabSheet;
    MemoInfo: TMemo;
    ChartHistogram: TChart;
    SeriesRed: TBarSeries;
    SeriesBlue: TBarSeries;
    SeriesGreen: TBarSeries;
    TabControls: TTabSheet;
    procedure BtnDebugClick(Sender: TObject);
    procedure CheckBoxBlueClick(Sender: TObject);
    procedure CheckBoxGreenClick(Sender: TObject);
    procedure CheckBoxRedClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Open1Click(Sender: TObject);
    procedure PageControlChange(Sender: TObject);
    procedure SaveAs1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure OpenColourImage1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    ImgBMP : array of TBitmap;
    ViewForm: array of TForm;
    windowcount,previdx: integer;
    InfoArray: array of string;
    HistoArray: array of THistoData;

    function CreateWindow(imagename:string;imagewidth,imageheight:integer): TCanvas;
    procedure RenderImage(ICanvas:TCanvas; Bitmap: TBitmap);  //BM 15-Jun-13
    procedure ViewerFormOnActivate(Sender: TObject);
    procedure ViewerFormOnClose(Sender: TObject; var Action: TCloseAction);
    procedure MyPaintBoxPaint(Sender: TObject);
    procedure SetHistogramPageVisibility(Channel0Data, Channel1Data, Channel2Data: TPDSData);
    procedure SetHistogramCheckBoxesVisibility(Channel0Data, Channel1Data, Channel2Data: TPDSData);
    procedure SetControlPageVisibility(Value: boolean);
    function NewBitmap(AHeight, AWidth: Integer): Integer;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

uses about;   

{ TMainForm }

{$IFNDEF FPC}
  {$R *.dfm}
{$ELSE}
  {$R *.lfm}
{$ENDIF}

procedure TMainForm.RenderImage(ICanvas:TCanvas; Bitmap: TBitmap);
begin
  if Bitmap <> nil then   // no point in trying to render an image unless a bitmap has been assigned
    ICanvas.CopyRect(Rect(0,0,Bitmap.Width,Bitmap.Height),
                     Bitmap.Canvas,
                     Rect(0,0,Bitmap.Width,Bitmap.Height));
end;

function TMainForm.NewBitmap(AHeight, AWidth: Integer): Integer;
var
  idx: integer;
begin
  // create a new instance of a TBitmap object
  SetLength(ImgBMP,Length(ImgBMP)+1);
  idx := High(ImgBMP);
  ImgBMP[idx] := TBitMap.create;
  ImgBMP[idx].PixelFormat := pf24bit;
  ImgBMP[idx].Height := AHeight;
  ImgBMP[idx].Width  := AWidth;
  result := idx;
end;

procedure TMainForm.Open1Click(Sender: TObject);
var
  FileParser: TFileParser;
  PDS: TPDSObject;
  SDDPT: TSDDPTObject;
  VICAR: TVICARObject;
  ImgCanvas: TCanvas;
  idx: integer;
  Status: Integer;
  Value: byte;
  I: Integer;
  FileFilters: string;

  {$IFDEF FPC}
  procedure LoadDataToBitmap(AWidth, AHeight: Integer; AImageData: TPDSData);
  var
    x,y: Integer;
    TempIntfImg: TLazIntfImage;
    ImgHandle,ImgMaskHandle: HBitmap;
    P: PRGBQuadArray;
  begin
    TempIntfImg := TLazIntfImage.Create(0,0);
    {$IFDEF DARWIN}
    TempIntfImg.DataDescription.Init_BPP32_B8G8R8_BIO_TTB(PDS.ImageWidth,PDS.ImageHeight);
    {$ELSE}
    TempIntfImg.DataDescription := GetDescriptionFromDevice(0);
    {$ENDIF}
    TempIntfImg.SetSize(AWidth,AHeight);

    if (TempIntfImg.DataDescription.Depth < 24) then  //bm 05-Mar-16 need at least 24-bits (even though it is monochrome)
    begin
      ShowMessage('WARNING: Invalid colour depth for display. Please configure display depth to support at least 24-bit colour depth')
    end else
    begin
      //idx := NewBitmap(PDS.ImageHeight,PDS.ImageWidth);
      idx := NewBitmap(AHeight,AWidth);

      // copy the image data to Bitmap or IntfImage (monochrome grayscale)
      //for y := 0 to PDS.ImageHeight-1 do
      for y := 0 to AHeight-1 do
      begin
        P := TempIntfImg.GetDataLineStart(y);
        for x := 0 to AWidth-1 do
        begin
          //value := PDS.ImageData[y*PDS.ImageWidth+x];
          value := AImageData[y*AWidth+x];
          //value := PDS.ImageData[y*PDS.ImageWidth+x] shl 2; // brighter
          //value := Trunc(PDS.ImageData[y*PDS.ImageWidth+x] * 1.75); // brighter
          P^[x].rgbRed   := value;
          P^[x].rgbGreen := value;
          P^[x].rgbBlue  := value;
          P^[x].rgbReserved := 0;
        end;
      end;
      TempIntfImg.CreateBitmaps(ImgHandle,ImgMaskHandle,true);
      ImgBMP[idx].Handle :=ImgHandle;
      ImgBMP[idx].MaskHandle :=ImgMaskHandle;
    end;
    TempIntfImg.Free;
  end;
  {$ELSE}
  procedure LoadDataToBitmap(AWidth, AHeight: Integer; AImageData: TPDSData);
  var
    x,y: Integer;
    ptr:integer;
    P: PByteArray;
  begin
    //idx := NewBitmap(PDS.ImageHeight,PDS.ImageWidth);
    idx := NewBitmap(AHeight,AWidth);

    // copy the image data to Bitmap or IntfImage (monochrome grayscale)
    //for y := 0 to PDS.ImageHeight-1 do
    for y := 0 to AHeight-1 do
    begin
      P := ImgBMP[idx].ScanLine[y];
      ptr:= 0;
      //for x := 0 to PDS.ImageWidth-1 do
      for x := 0 to AWidth-1 do
      begin
        //value := PDS.ImageData[y*PDS.ImageWidth+x];
        value := AImageData[y*AWidth+x];
        P[ptr]   := value; // PDS.ImageData[y*PDS.ImageWidth+x];
        P[ptr+1] := value; //PDS.ImageData[y*PDS.ImageWidth+x];
        P[ptr+2] := value; //PDS.ImageData[y*PDS.ImageWidth+x];
        ptr := ptr + 3;
      end;
    end;
  end;
  {$ENDIF}

begin
  // try to open file
  OpenDialog.Title := 'Open Image File';
  {$IFDEF WINDOWS}
  FileFilters := 'red colour channel|*.red|'+
                 'green colour channel|*.grn|'+
                 'blue colour channel|*.blu|'+
                 'Monochrome(BB1-4)|*.bb1;*.bb2;*.bb3;*.bb4|'+
                 'Calibration test image|*.n07;*.n15|'+  //bm 16-Feb-20 n15
                 'Surface image|*.sur|'+
                 'infrared channel 1|*.ir1|'+
                 'infrared channel 2|*.ir2|'+
                 'infrared channel 3|*.ir3|'+
                 'image file(IMG)|*.img|'+
                 'image file(IMQ)|*.imq|'+
                 'image file(LBL)|*.lbl|'+
                 'sun image(SUN)|*.sun|';  //bm 16-Feb-20
                 // BM 11-May-08
  {$ELSE}
  FileFilters := 'red colour channel|*.red;*.RED|'+
                 'green colour channel|*.grn;*.GRN|'+
                 'blue colour channel|*.blu;*.BLU|'+
                 'Monochrome(BB1-4)|*.bb1;*.BB1;*.bb2;*.BB2;*.bb3;*.BB3;*.bb4;*.BB4|'+
                 'Calibration test image|*.n07;*.N07;*.n15;*.N15|'+  //bm 16-Feb-20 n15
                 'Surface image|*.sur;*.SUR|'+
                 'infrared channel 1|*.ir1;*.IR1|'+
                 'infrared channel 2|*.ir2;*.IR2|'+
                 'infrared channel 3|*.ir3;*.IR3|'+
                 'image file(IMG)|*.img;*.IMG|'+
                 'image file(IMQ)|*.imq;*.IMQ|'+
                 'image file(LBL)|*.lbl;*.LBL|'+  //bm 01-Jan-20 bugfix
                 'sun image(SUN)|*.sun;*.SUN|';   //bm 16-Feb-20 new
  {$ENDIF}
  FileFilters := FileFilters + 'SPPDT file|';
  for I := 0 to 9 do
  begin
    FileFilters := FileFilters + '*.' + Format('%.*d',[3, I]);
    if I < 9 then
      FileFilters := FileFilters + ';'
  end;
  FileFilters := FileFilters + '|';
  FileFilters := FileFilters + 'any file|*.*';
  OpenDialog.Filter := FileFilters;

  if not OpenDialog.Execute then
    exit;

  FileParser := TFileParser.Create;       //27-Dec-20
  FileParser.Parse(OpenDialog.Filename);

  case FileParser.FileType of
      ftPDS1,
      ftPDS2,
      ftPDS3,
      ftODL3:
        begin
          PDS := TPDSObject.Create;
          Status := PDS.LoadFromFile(OpenDialog.Filename);
          if (Status = 0) then
          begin
            // copy the PDS label data to InfoArray
            SetLength(InfoArray,Length(InfoArray)+1);
            idx:= High(InfoArray);
            InfoArray[idx] := PDS.Labeldata;

            LoadDataToBitmap(PDS.ImageWidth, PDS.ImageHeight, PDS.ImageData);

            // copy the PDS histogram data to HistoArray
            SetLength(HistoArray,Length(HistoArray)+1);
            idx:= High(HistoArray);
            HistoArray[idx].DataType := PDS.HistogramDataType;
            HistoArray[idx].DataSize := PDS.HistogramItemSize;
            HistoArray[idx].Count := PDS.HistogramItemCount;

            // The length of HistoArray[idx].Data could be set to PDS.HistogramItemcount
            // but it is set to the entire length of PDS.HistogramData instead, so that
            // all data, including filler bytes, is assigned with one line of code.
            SetLength(HistoArray[idx].Channel0Data,Length(PDS.HistogramData));
            HistoArray[idx].Channel0Data := PDS.HistogramData;

            //create a separate window and display the image
            ImgCanvas := CreateWindow(ExtractFileName(OpenDialog.FileName),PDS.ImageWidth,PDS.ImageHeight);
            RenderImage(ImgCanvas,ImgBMP[idx]);
          end else
          begin
            if (Status < 0) then
              ShowMessage('Error in processing image ; status code: '+ IntToStr(Status))
            else
             ShowMessage('Error decoding image on line: '+ IntToStr(Status));
          end;

          if Assigned(PDS) then
            PDS.Free;
        end;
      ftSDDPT:
        begin
          SDDPT := TSDDPTObject.Create;
          Status := SDDPT.LoadFromFile(OpenDialog.Filename);
          If (Status = 0) then
          begin
            //label data
            SetLength(InfoArray,Length(InfoArray)+1);
            idx:= High(InfoArray);
            InfoArray[idx] := SDDPT.Labeldata;

            //no histogram data
            SetLength(HistoArray,Length(HistoArray)+1);
            idx := High(HistoArray);
            HistoArray[idx].DataType := '';
            HistoArray[idx].DataSize := 0;
            HistoArray[idx].Count := 0;

            SetLength(HistoArray[idx].Channel0Data,0);
            HistoArray[idx].Channel0Data := nil;

            //image data
            LoadDataToBitmap(SDDPT.ImageWidth, SDDPT.ImageHeight, SDDPT.ImageData);

            //create a separate window and display the image
            ImgCanvas := CreateWindow(ExtractFileName(OpenDialog.FileName),SDDPT.ImageWidth,SDDPT.ImageHeight);
            RenderImage(ImgCanvas,ImgBMP[idx]);
          end else
            ShowMessage('Error in processing image ; status code: '+ IntToStr(Status));

          If Assigned(SDDPT) then
            SDDPT.Free;
        end;
      ftVICAR:
        begin
           VICAR := TVICARObject.Create;
           Status := VICAR.LoadFromFile(OpenDialog.Filename);
           If (Status = 0) then
           begin
             //label data
             SetLength(InfoArray,Length(InfoArray)+1);
             idx:= High(InfoArray);
             InfoArray[idx]:= VICAR.Labeldata + NL + VICAR.EndOfFileLabelData;

             //no histogram data
             SetLength(HistoArray,Length(HistoArray)+1);
             idx:= High(HistoArray);
             HistoArray[idx].DataType:= '';
             HistoArray[idx].DataSize:= 0;
             HistoArray[idx].Count:= 0;

             SetLength(HistoArray[idx].Channel0Data,0);
             HistoArray[idx].Channel0Data:= nil;

             //image data
             LoadDataToBitmap(VICAR.ImageWidth, VICAR.ImageHeight, VICAR.ImageData);

             //create a separate window and display the image
             ImgCanvas := CreateWindow(ExtractFileName(OpenDialog.FileName),VICAR.ImageWidth,VICAR.ImageHeight);
             RenderImage(ImgCanvas,ImgBMP[idx]);
           end else
             ShowMessage('Error in processing image ; status code: '+ IntToStr(Status));

           if Assigned(VICAR) then
             VICAR.Free;
        end;
  else
    ShowMessage('Error: Unsupported filed type');    //27-Dec-20
  end;
  if Assigned(FileParser) then
    FileParser.Free;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  //
end;

procedure TMainForm.CheckBoxRedClick(Sender: TObject);  //bm 30-Dec-21
begin
  SeriesRed.Active := CheckBoxRed.State = cbChecked;
end;

procedure TMainForm.CheckBoxGreenClick(Sender: TObject); //bm 30-Dec-21
begin
  SeriesGreen.Active := CheckBoxGreen.State = cbChecked;
end;

procedure TMainForm.CheckBoxBlueClick(Sender: TObject); //bm 30-Dec-21
begin
  SeriesBlue.Active := CheckBoxBlue.State = cbChecked;
end;

procedure TMainForm.BtnDebugClick(Sender: TObject);
var
  // TEST DEBUG code
  // *** Not fully tested ***
  // *** Research better way to edit images if possible ***/

  idx: Integer;
  avg: byte;
  AHeight, AWidth: Integer;
  PaintBox: TPaintBox;

  TempIntfImg: TLazIntfImage;
  P: PRGBQuadArray;
  x,y: Integer;
  Value: byte;
  ValueA, ValueB, ValueC: byte;

  ImgHandle,ImgMaskHandle: HBitmap;
  AImageData: TPDSData;

  function GetPaintBoxInForm(AForm: TForm): TPaintBox;
  var
     I: Integer;
  begin
    result := nil;

    for I := 0 to AForm.ControlCount- 1 do
    begin
      if AForm.Controls[I] is TScrollBox then
      begin
        result := TPaintBox(AForm.Controls[I].FindComponent('PaintBox' + IntToStr(idx)));
        exit;
      end;
    end;
  end;

begin
  idx := TForm(Sender).Tag;

  AHeight := ImgBMP[idx].Height;
  AWidth  := ImgBMP[idx].Width;
  SetLength(AImageData, AHeight * AWidth);

  TempIntfImg := ImgBMP[idx].CreateIntfImage;


  // Step 1:
  for y := 0 to AHeight-1 do
   begin
     P := TempIntfImg.GetDataLineStart(y);
     for x := 0 to AWidth-1 do
       AImageData[y*AWidth+x] := P^[x].rgbRed;  //monochrome
   end;

  //Step 2:
  //post image processing
  for y := 0 to AHeight - 1 do
  begin
    for x := 1 to AWidth-2 do    //1. track fill-in
    begin
      valueA := AImageData[y * AWidth +(x-1)];
      valueB := AImageData[y * AWidth +x];
      valueC := AImageData[y * AWidth +(x+1)];

      if (valueB = 0) and (ValueA > 0) and (ValueC > 0) then
      begin
        ValueB := (ValueA + ValueC) shr 1;
        AImageData[y * AWidth +x] := valueB;
      end;
    end;

    for x := 1 to AWidth-2 do  //2. salt 'n pepper removal
    begin
      valueA := AImageData[y * AWidth +(x-1)];
      valueB := AImageData[y * AWidth +x];
      valueC := AImageData[y * AWidth +(x+1)];

      avg := (ValueA + ValueC) shr 1;
      if (abs(avg- ValueA) < 16) and (abs(avg- ValueC) < 16) and (abs(avg- ValueB) > 32) then
      begin
        ValueB := avg;
        AImageData[y * AWidth +x] := valueB;
      end;
    end;
  end;

  //Step 3:
  // copy the image data to Bitmap or IntfImage (monochrome grayscale)
  for y := 0 to AHeight-1 do
  begin
    P := TempIntfImg.GetDataLineStart(y);
    for x := 0 to AWidth-1 do
    begin
      value := AImageData[y*AWidth+x];
      P^[x].rgbRed   := value;
      P^[x].rgbGreen := value;
      P^[x].rgbBlue  := value;
      P^[x].rgbReserved := 0;
    end;
  end;

  TempIntfImg.CreateBitmaps(ImgHandle,ImgMaskHandle,true);
  ImgBMP[idx].Handle := ImgHandle;
  ImgBMP[idx].MaskHandle := ImgMaskHandle;

  //Step 4:
  //find paintbox on form and render image if possible
  PaintBox := GetPaintBoxInForm(ViewForm[idx]);
  if Assigned(PaintBox) then
    RenderImage(PaintBox.Canvas,ImgBMP[idx]);

  AImageData := nil;
  TempIntfImg.Free;

end;

procedure TMainForm.PageControlChange(Sender: TObject);
begin
  //MainForm.Caption := IntToStr(pageControl.TabIndex); // debug
end;

function TMainForm.CreateWindow(imagename:string;imagewidth,imageheight:integer): TCanvas;
var
  MyScroll: TScrollBox;
  MyPaintBox: TPaintBox;
  idx: integer;
begin
  SetLength(ViewForm,Length(ViewForm)+1);
  idx:= High(ViewForm);
  ViewForm[idx]:= TForm.Create(Application);
  ViewForm[idx].Color:=clWhite;
  ViewForm[idx].Caption := imagename;
  ViewForm[idx].Tag:=idx;
  if idx>0 then
  begin
    ViewForm[idx].Left:=ViewForm[idx-1].Left+50;
    ViewForm[idx].Top:= ViewForm[idx-1].Top+50;
  end else
  begin
    ViewForm[idx].Left:=0;
    ViewForm[idx].Top:=0;
  end;

  ViewForm[idx].Width := DEF_WINDOW_WIDTH;
  ViewForm[idx].Height:= DEF_WINDOW_HEIGHT;
  ViewForm[idx].Constraints.MinWidth := DEF_WINDOW_WIDTH;
  ViewForm[idx].Constraints.MinHeight := DEF_WINDOW_HEIGHT;
  ViewForm[idx].OnActivate:=ViewerFormOnActivate;
  ViewForm[idx].OnClose:=ViewerFormOnClose;
  windowcount:=windowcount+1;

  MyScroll:= TScrollBox.Create(ViewForm[idx]);
  MyScroll.Parent:= ViewForm[idx];
  MyScroll.Align:= alClient;

  MyPaintBox:= TPaintBox.Create(MyScroll);
  MyPaintBox.Parent:= MyScroll;
  MyPaintBox.Left:=0;
  MyPaintBox.Top:=0;
  MyPaintBox.Tag:=idx;
  MyPaintBox.Height:= imageheight;
  MyPaintBox.Width:= imagewidth;
  MyPaintBox.OnPaint:=MyPaintBoxPaint;
  MyPaintBox.Name := 'PaintBox'+ IntToStr(idx);  // NEW

  result:= MyPaintBox.Canvas;
  ViewForm[idx].Show;
end;

procedure TMainForm.ViewerFormOnActivate(Sender: TObject);
var
  c,d,idx,ptr: integer;
  SeriesVal: longint;
begin
  idx := TForm(Sender).Tag;

  if idx <> previdx then
  begin
    MemoInfo.Visible:=false;   //update memo with PDS labels of selected image
    MemoInfo.Lines.Clear;
    MemoInfo.Lines.Add(InfoArray[idx]);
    //MemoInfo.Lines.SaveToFile('MemoInfo_debug.txt');  //debug only
    Application.ProcessMessages;
    MemoInfo.Visible:=true;

    //ChartHistogram.Visible:=true;

    // update chart with histogram data of selected image
    SeriesRed.Clear;   // clear series data
    SeriesGreen.Clear;
    SeriesBlue.Clear;

    SetHistogramPageVisibility(HistoArray[idx].Channel0Data,
                               HistoArray[idx].Channel1Data,
                               HistoArray[idx].Channel2Data); //bm 02-Jan-20

    SetHistogramCheckBoxesVisibility(HistoArray[idx].Channel0Data,
                                     HistoArray[idx].Channel1Data,
                                     HistoArray[idx].Channel2Data); //bm 30-Dec-21

    SetControlPageVisibility(true); //bm 06-Jan-20

    ChartHistogram.Title.Text.Text:= TForm(Sender).Caption;

    if HistoArray[idx].Channel0Data <> nil then
    begin
      for c := 0 to HistoArray[idx].Count-1 do
      begin
        SeriesVal := 0;
        if HistoArray[idx].DataType= 'MSB_INTEGER' then   // big endian
          for d:= 0 to HistoArray[idx].DataSize-1 do
          begin
            ptr := c* HistoArray[idx].DataSize + d; // calculate correct address offset
            SeriesVal := SeriesVal + LongInt(HistoArray[idx].Channel0Data[ptr] shl (8*(3-d))); // shift bytes in long word  bm 06-Mar-16 bugfix
          end;

        if HistoArray[idx].DataType= 'VAX_INTEGER' then  // little endian (Viking Orbiter)
          for d:= 0 to (HistoArray[idx].DataSize div 8) -1 do
          begin
            ptr := c* (HistoArray[idx].DataSize div 8) + d;
            SeriesVal := SeriesVal + LongInt(HistoArray[idx].Channel0Data[ptr] shl (8*d));  //bm 06-Mar-16
          end;
        SeriesRed.AddXY(c,SeriesVal);
      end;
    end;

    if HistoArray[idx].Channel1Data<> nil then
    begin
      for c := 0 to HistoArray[idx].Count-1 do
      begin
        SeriesVal:=0;
        if HistoArray[idx].DataType= 'MSB_INTEGER' then   // big endian
          for d:= 0 to HistoArray[idx].DataSize-1 do
          begin
            ptr := c* HistoArray[idx].DataSize+ d; // calculate correct address offset
            SeriesVal := SeriesVal + LongInt(HistoArray[idx].Channel1Data[ptr] shl (8*(3-d))); // shift bytes in long word  bm 06-Mar-16
          end;

        if HistoArray[idx].DataType= 'VAX_INTEGER' then  // little endian (Viking Orbiter) 04-Dec-21
          for d:= 0 to (HistoArray[idx].DataSize div 8) -1 do
          begin
            ptr := c* (HistoArray[idx].DataSize div 8) + d;
            SeriesVal := SeriesVal + LongInt(HistoArray[idx].Channel1Data[ptr] shl (8*d));
          end;
        SeriesGreen.AddXY(c, SeriesVal);
      end;
    end;

    if HistoArray[idx].Channel2Data<> nil then
    begin
      for c := 0 to HistoArray[idx].Count-1 do
      begin
        SeriesVal:=0;
        if HistoArray[idx].DataType= 'MSB_INTEGER' then   // big endian
          for d:= 0 to HistoArray[idx].DataSize-1 do
          begin
            ptr:= c* HistoArray[idx].DataSize+ d; // calculate correct address offset
            SeriesVal := SeriesVal + LongInt(HistoArray[idx].Channel2Data[ptr] shl (8*(3-d))); // shift bytes in long word  bm 06-Mar-16
          end;

        if HistoArray[idx].DataType= 'VAX_INTEGER' then  // little endian (Viking Orbiter) 04-Dec-21
          for d:= 0 to (HistoArray[idx].DataSize div 8) -1 do
          begin
            ptr := c* (HistoArray[idx].DataSize div 8) + d;
            SeriesVal := SeriesVal + LongInt(HistoArray[idx].Channel2Data[ptr] shl (8*d));
          end;
        SeriesBlue.AddXY(c, SeriesVal);
      end;
    end;

    previdx:=idx;
  end;
end;

procedure TMainForm.ViewerFormOnClose(Sender: TObject;var Action: TCloseAction);
var
  idx: integer;
begin
  idx := TForm(Sender).Tag;
  if idx <= High(InfoArray) then
  begin
    InfoArray[idx] := ''; //bm 02-Jan-20
  end;

  if idx <= High(ImgBMP) then
  begin
    ImgBMP[idx].Free;  // free the image

    HistoArray[idx].Channel0Data := nil; // clear histogram channels
    HistoArray[idx].Channel1Data := nil;
    HistoArray[idx].Channel2Data := nil;
    windowcount := windowcount-1;
    if windowcount=0 then
    begin
      MemoInfo.Visible:=false;

      SetHistogramPageVisibility(HistoArray[idx].Channel0Data,
                                 HistoArray[idx].Channel1Data,
                                 HistoArray[idx].Channel2Data); //bm 02-Jan-20

      SetHistogramCheckBoxesVisibility(HistoArray[idx].Channel0Data,
                                       HistoArray[idx].Channel1Data,
                                       HistoArray[idx].Channel2Data); //bm 30-Dec-21

      SetControlPageVisibility(false); //bm 06-Jan-20
    end;
  end;
  //Action := caFree;  //bm 26-Dec-20 get rid of compiler hint
end;

procedure TMainForm.MyPaintBoxPaint(Sender: TObject);
var
  idx: integer;
begin
  idx:= TControl(Sender).Tag;
  RenderImage(TPaintBox(Sender).Canvas,ImgBMP[idx]);
end;

procedure TMainForm.SaveAs1Click(Sender: TObject);
begin
  if previdx>-1 then
    if SaveDialog.Execute then
    begin
      ImgBMP[previdx].SaveToFile(SaveDialog.Filename);
      MessageDlg('Image saved',mtInformation,[mbOK],0);
    end;
end;

procedure TMainForm.Exit1Click(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TMainForm.About1Click(Sender: TObject);
begin
  AboutBox.ShowModal;
end;

procedure TMainForm.OpenColourImage1Click(Sender: TObject);
const
  RED_R_FACTOR = 0.7;
  RED_G_FACTOR = 0.3;
  GRN_R_FACTOR = 0.5;
  GRN_B_FACTOR = 0.5;
var
  path,filename: string;
  RStatus, GStatus, BStatus: Integer;
  RPDS, GPDS, BPDS: TPDSObject;
  RedSDDPT, GrnSDDPT, BluSDDPT:TSDDPTObject;
  imgwidth,imgheight: integer;
  widthArray: array of Integer;

  ImgCanvas: TCanvas;
  idx:integer;
  InfoLength:integer;
  FileParser: TFileParser;
  FileFilters: string;

  {$IFDEF FPC}
  // copy the image data to Bitmap, in full colour if possible
  //  Red = 0.7 x RED + 0.3 x GREEN  = 655 nm (human vision = 650 nm)
  //  Green = 0.5 x GREEN + 0.5 x BLUE = 510 nm (human vision = 510 nm)
  //  Blue = BLUE = 470 nm (human vision =440 nm)

  procedure LoadRGBDataToBitmap(AWidth, AHeight: Integer;
                                RedImageData, GreenImageData, BlueImageData: TPDSData;
                                ColBalance: boolean);
  var
    x,y:integer;
    TempIntfImg: TLazIntfImage;
    ImgHandle,ImgMaskHandle: HBitmap;
    P: PRGBQuadArray;
    RWidth,GWidth,BWidth: Integer;
  begin
    TempIntfImg:=TLazIntfImage.Create(0,0);
    {$IFDEF DARWIN}
    TempIntfImg.DataDescription.Init_BPP32_B8G8R8_BIO_TTB(imgwidth,imgheight);
    {$ELSE}
    TempIntfImg.DataDescription:=GetDescriptionFromDevice(0);
    {$ENDIF}
    TempIntfImg.SetSize(AWidth,AHeight);

    RWidth := Length(RedImageData) div AHeight; //04-Dec-25 not all composite image data may have the same width
    GWidth := Length(GreenImageData) div AHeight;
    BWidth := Length(BlueImageData) div AHeight;

    if TempIntfImg.DataDescription.Depth < 24 then // bm 05-Mar-16 need at least 24-bits
    begin
      ShowMessage('WARNING: Invalid colour depth for display. Please configure display depth to support at least 24-bit colour depth')
    end else
    begin
      idx := NewBitmap(AHeight, AWidth);

      for y:= 0 to AHeight-1 do
      begin
        P:= TempIntfImg.GetDataLineStart(y);
        for x:=0 to AWidth-1 do
        begin
          if (RStatus = 0) then
          begin
            if (GStatus = 0) and (ColBalance) then
              P^[x].rgbRed  := Trunc(RedImageData[y*RWidth+x] * RED_R_FACTOR +
                                     GreenImageData[y*GWidth+x] * RED_G_FACTOR)
            else
              P^[x].rgbRed  := RedImageData[y*RWidth+x];
          end else
            P^[x].rgbRed:=0;

          if (GStatus = 0) then
          begin
            if (BStatus = 0) and (ColBalance) then
              P^[x].rgbGreen:= Trunc(GreenImageData[y*GWidth+x] * GRN_R_FACTOR+
                                     BlueImageData[y*BWidth+x] * GRN_B_FACTOR)
            else
              P^[x].rgbGreen:= GreenImageData[y*GWidth+x];
          end else
            P^[x].rgbGreen:=0;

          if (BStatus =0) then
            P^[x].rgbBlue := BlueImageData[y*BWidth+x]
          else
            P^[x].rgbBlue:=0;

          P^[x].rgbReserved:= 0;
        end;
      end;

      TempIntfImg.CreateBitmaps(ImgHandle,ImgMaskHandle,true);
      ImgBMP[idx].Handle:=ImgHandle;
      ImgBMP[idx].MaskHandle:=ImgMaskHandle;

      TempIntfImg.Free;
    end;
  end;
  {$ELSE}
  procedure LoadRGBDataToBitmap(AWidth, AHeight: Integer;
                                RedImageData, GreenImageData, BlueImageData: TPDSData;
                                ColBalance: boolean);
  var
    x,y:integer;
    ptr:integer;
    P: PByteArray;
  begin
    idx := NewBitmap(AHeight, AWidth);

    // copy the image data to Bitmap, in full colour if possible
    for y:= 0 to AHeight-1 do
    begin   //Delphi bitmap scaline
      P := ImgBMP[idx].ScanLine[y];
      ptr:= 0;
      for x:= 0 to AWidth-1 do
      begin
        if (RStatus = 0) then
        begin
         if (GStatus = 0) and (ColBalance) then
            P[ptr+2] := Trunc(RedImageData[y*AWidth+x]*0.7+
                              GreenImageData[y*AWidth+x]*0.3)
          else
            P[ptr+2] := RedImageData[y*AWidth+x];
        end else
          P[ptr+2]:=0;

        if (GStatus = 0) then
        begin
          if (BStatus = 0) and (ColBalance) then
            P[ptr+1] := Trunc(GreenImageData[y*AWidth+x]*0.5+
                              BlueImageData[y*AWidth+x]*0.5)
          else
            P[ptr+1] := GreenImageData[y*AWidth+x];
        end else
          P[ptr+1]:=0;

        if (BStatus = 0) then
          P[ptr] := BlueImageData[y*AWidth+x]
        else
          P[ptr]:=0;
        ptr := ptr + 3;
      end;
    end;
  end;
  {$ENDIF}

begin
  // open three images for colour processing
  OpenDialog.Title := 'Select RED, GRN or BLU image file';
  {$IFDEF WINDOWS}
  FileFilters := 'colour channels(red,green,blue)|*.red;*.grn;*.blu|';
  {$ELSE}
  FileFilters := 'colour channels(red,green,blue)|*.red;*.RED;*.grn;*.GRN;*.blu;*.BLU|';
  {$ENDIF}
  FileFilters := FileFilters + 'SDDPT channels(001,002,003)|*.001;*.002;*.003|';
  FileFilters := FileFilters + 'any file|*.*';
  OpenDialog.Filter := FileFilters;
  if not OpenDialog.Execute then
    exit;

  Path     := ExtractFilePath(OpenDialog.FileName);   // get path of file
  filename := ExtractFileName(OpenDialog.FileName);   // get filename (without path)

  FileParser := TFileParser.Create;           //27-Dec-20
  FileParser.Parse(OpenDialog.Filename);

  filename := Copy(filename,1,Pos('.',filename)-1);   // discard the extension
  imgHeight:=-1;
  imgWidth:=-1;
  InfoLength:=0;
  widthArray := nil;

  case FileParser.FileType of
      ftPDS2,   //4-Dec-21
      ftPDS3:
        begin
          RPDS:= TPDSObject.Create;
          GPDS:= TPDSObject.Create;
          BPDS:= TPDSObject.Create;

          RStatus:= RPDS.LoadFromFile(Path + filename+ '.RED');
          if (RStatus = -1) then
            RStatus:= RPDS.LoadFromFile(Path + filename+ '.red');  //04-Dec-21 try again

          GStatus:= GPDS.LoadFromFile(Path + filename+ '.GRN');
          if (GStatus = -1) then
            GStatus:= GPDS.LoadFromFile(Path + filename+ '.grn');   //04-Dec-21 try again

          BStatus:= BPDS.LoadFromFile(Path + filename+ '.BLU');
          if (BStatus = -1) then
            BStatus:= BPDS.LoadFromFile(Path + filename+ '.blu');   //04-Dec-21 try again

          if (RStatus = 0) or (GStatus = 0) or (BStatus = 0) then
          begin
            // copy the PDS label data to InfoArray
            SetLength(InfoArray,Length(InfoArray)+1);
            idx:= High(InfoArray);
            SetLength(HistoArray,Length(HistoArray)+1);
            HistoArray[idx].Count:=-1;

            if (RStatus = 0) then
            begin
              SetLength(InfoArray[idx],Length(InfoArray[idx])+Length(RPDS.LabelData));
              InfoLength:=Length(InfoArray[idx]);
              imgheight:= RPDS.ImageHeight;
              SetLength(widthArray,Length(widthArray)+1); //04-Dec-25
              widthArray[high(widthArray)]:= RPDS.ImageWidth; //04-Dec-25
              HistoArray[idx].DataType:=  RPDS.HistogramDataType;
              HistoArray[idx].DataSize:=  RPDS.HistogramItemSize;
              HistoArray[idx].Count:=     RPDS.HistogramItemCount;
            end;

            if (GStatus = 0) then
            begin
              SetLength(InfoArray[idx],Length(InfoArray[idx])+Length(GPDS.LabelData));
              InfoLength := Length(InfoArray[idx]);
              if (imgheight < 0) then
                imgheight := GPDS.ImageHeight;
              SetLength(widthArray,Length(widthArray)+1); //04-Dec-25
              widthArray[high(widthArray)]:= GPDS.ImageWidth; //04-Dec-25
              if HistoArray[idx].Count <0 then
              begin
                HistoArray[idx].DataType:=  GPDS.HistogramDataType;
                HistoArray[idx].DataSize:=  GPDS.HistogramItemSize;
                HistoArray[idx].Count:=     GPDS.HistogramItemCount;
              end;
            end;

            if (BStatus = 0) then
            begin
              SetLength(InfoArray[idx],Length(InfoArray[idx])+Length(BPDS.LabelData));
              InfoLength := Length(InfoArray[idx]);
              if (imgheight < 0) then
                imgheight := BPDS.ImageHeight;
              SetLength(widthArray,Length(widthArray)+1); //04-Dec-25
              widthArray[high(widthArray)]:= BPDS.ImageWidth; //04-Dec-25
              if HistoArray[idx].Count <0 then
              begin
                HistoArray[idx].DataType := BPDS.HistogramDataType;
                HistoArray[idx].DataSize := BPDS.HistogramItemSize;
                HistoArray[idx].Count    := BPDS.HistogramItemCount;
              end;
            end;

            if (RStatus = 0) then
              InfoArray[idx] := RPDS.Labeldata;
            if (GStatus = 0) then
              if InfoLength = Length(GPDS.Labeldata) then
                InfoArray[idx] := GPDS.Labeldata
              else
               InfoArray[idx] := InfoArray[idx]+ NL + GPDS.Labeldata;
            if (BStatus = 0) then
               if InfoLength = Length(BPDS.Labeldata) then
                 InfoArray[idx] := BPDS.Labeldata
               else
                 InfoArray[idx]:= InfoArray[idx] + NL + BPDS.Labeldata;

            imgwidth := MinValue(widthArray); // 04-Dec-25

            LoadRGBDataToBitmap(imgwidth, imgheight,
                                RPDS.ImageData,
                                GPDS.ImageData,
                                BPDS.ImageData,
                                true);      //30-Dec-20

            // copy the PDS histogram data to HistoArray
            if (RStatus = 0) then
            begin
              SetLength(HistoArray[idx].Channel0Data,Length(RPDS.HistogramData));
              HistoArray[idx].Channel0Data:= RPDS.HistogramData;
            end;
            if (GStatus = 0) then
            begin
              SetLength(HistoArray[idx].Channel1Data,Length(GPDS.HistogramData));
              HistoArray[idx].Channel1Data:= GPDS.HistogramData;
            end;
            if (BStatus = 0) then
            begin
              SetLength(HistoArray[idx].Channel2Data,Length(BPDS.HistogramData));
              HistoArray[idx].Channel2Data:= BPDS.HistogramData;
            end;

            //create a separate window and display the image
            ImgCanvas := CreateWindow(filename,imgWidth,imgHeight);
            RenderImage(ImgCanvas,ImgBMP[idx]);
          end;
          BPDS.Free;
          GPDS.Free;
          RPDS.Free;
        end;
     ftSDDPT:
       begin
         RedSDDPT:= TSDDPTObject.Create;
         GrnSDDPT:= TSDDPTObject.Create;
         BluSDDPT:= TSDDPTObject.Create;

         BStatus:= BluSDDPT.LoadFromFile(Path + filename+ '.001');
         GStatus:= GrnSDDPT.LoadFromFile(Path + filename+ '.002');
         RStatus:= RedSDDPT.LoadFromFile(Path + filename+ '.003');

         if (RStatus = 0) or (GStatus = 0) or (BStatus = 0) then
         begin
           // copy the PDS label data to InfoArray
           SetLength(InfoArray,Length(InfoArray)+1);
           idx:= High(InfoArray);

           SetLength(HistoArray,Length(HistoArray)+1);
           HistoArray[idx].DataType:=  '';
           HistoArray[idx].DataSize:=  0;
           HistoArray[idx].Count:=     0;

           SetLength(HistoArray[idx].Channel0Data,0);
           HistoArray[idx].Channel0Data:= nil;

           if (RStatus = 0) then
           begin
             SetLength(InfoArray[idx],Length(InfoArray[idx])+Length(RedSDDPT.LabelData));
             InfoLength:= Length(InfoArray[idx]);
             imgheight:= RedSDDPT.ImageHeight;
             imgwidth:= RedSDDPT.ImageWidth;
           end;

           if (GStatus = 0) then
           begin
             SetLength(InfoArray[idx],Length(InfoArray[idx])+Length(GrnSDDPT.LabelData));
             InfoLength:= Length(InfoArray[idx]);
             if (imgheight<0) or (imgwidth<0) then
             begin
               imgheight := GrnSDDPT.ImageHeight;
               imgwidth := GrnSDDPT.ImageWidth;
             end;
           end;

           if (BStatus = 0) then
           begin
             SetLength(InfoArray[idx],Length(InfoArray[idx])+Length(BluSDDPT.LabelData));
             InfoLength:= Length(InfoArray[idx]);
             if (imgheight<0) or (imgwidth<0) then
             begin
               imgheight := BluSDDPT.ImageHeight;
               imgwidth := BluSDDPT.ImageWidth;
             end;
           end;

           if (RStatus = 0) then
             InfoArray[idx]:= RedSDDPT.Labeldata;
           if (GStatus = 0) then
             if InfoLength = Length(GrnSDDPT.Labeldata) then
               InfoArray[idx]:= GrnSDDPT.Labeldata
             else
              InfoArray[idx]:= InfoArray[idx]+ NL + GrnSDDPT.Labeldata;
           if (BStatus = 0) then
              if InfoLength = Length(BluSDDPT.Labeldata) then
                InfoArray[idx]:= BluSDDPT.Labeldata
              else
                InfoArray[idx]:= InfoArray[idx] + NL + BluSDDPT.Labeldata;

           LoadRGBDataToBitmap(imgwidth, imgheight,
                               RedSDDPT.ImageData,
                               GrnSDDPT.ImageData,
                               BluSDDPT.ImageData,
                               false);

           //create a separate window and display the image
           ImgCanvas:=CreateWindow(filename,imgWidth,imgHeight);
           RenderImage(ImgCanvas,ImgBMP[idx]);
         end;

         RedSDDPT.Free;
         GrnSDDPT.Free;
         BluSDDPT.Free;
       end;
  else
    ShowMessage('Error: Unsupported filed type');   //27-Dec-20
  end;
  if Assigned(FileParser) then
    FileParser.Free;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  MainForm.Caption := 'EDR Image Viewer '+ VERSION_NUM;
  previdx := -1;

  PageControl.Pages[PAGE_HISTOGRAM].TabVisible := false;
  PageControl.Pages[PAGE_CONTROLS].TabVisible := false;
  PageControl.TabIndex := 0;
end;

procedure TMainForm.SetHistogramPageVisibility(Channel0Data, Channel1Data, Channel2Data: TPDSData); //bm 02-Jan-20
begin
  PageControl.Pages[PAGE_HISTOGRAM].TabVisible := (Channel0Data <> nil) or
                                                  (Channel1Data <> nil) or
                                                  (Channel2Data <> nil); // bm 30-Dec-21

end;

procedure TMainForm.SetHistogramCheckBoxesVisibility(Channel0Data, Channel1Data, Channel2Data: TPDSData); //bm 30-Dec-21
begin
  CheckBoxRed.Visible   := (Channel0Data <> nil) and ((Channel1Data <> nil) or (Channel2Data <> nil));
  CheckBoxGreen.Visible := Channel1Data <> nil;
  CheckBoxBlue.Visible  := Channel2Data <> nil;

  CheckBoxRed.State   := cbChecked;
  CheckBoxGreen.State := cbChecked;
  CheckBoxBlue.State  := cbChecked;

  SeriesRed.Active   := Channel0Data <> nil;
  SeriesGreen.Active := Channel1Data <> nil;
  SeriesBlue.Active  := Channel2Data <> nil;
end;

procedure TMainForm.SetControlPageVisibility(Value: boolean); //bm 06-Jan-22
begin
  PageControl.Pages[PAGE_CONTROLS].TabVisible := Value;
end;

end.
