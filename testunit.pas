unit TestUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Grids;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnTest: TButton;
    LabelText: TLabel;
    Memo: TMemo;
    StringGrid: TStringGrid;
    StringGrid1: TStringGrid;
    procedure btnTestClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { private declarations }
    function TestIMQvsBMP(file1, file2: string): Integer;
    function TestBMPvsBMP(file1, file2: string): Integer;
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}
uses
  PDSInfo, decomp;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  //StringGrid.Cells[0, 0] := 'C:\EDRViewer\Vov\f035a72.bmp';
  //StringGrid.Cells[1, 0] := 'C:\EDRViewer\Data\Viking Orbiters\f035a72.imq';
  //StringGrid.Cells[0, 1] := 'C:\EDRViewer\Vov\f070a13.bmp';
  //StringGrid.Cells[1, 1] := 'C:\EDRViewer\Data\Viking Orbiters\f070a13.imq';
  //StringGrid.Cells[0, 2] := 'C:\EDRViewer\Vov\f101a32.bmp';
  //StringGrid.Cells[1, 2] := 'C:\EDRViewer\Data\Viking Orbiters\f101a32.imq';
  //StringGrid.Cells[0, 3] := 'C:\EDRViewer\Vov\f122s01.bmp';
  //StringGrid.Cells[1, 3] := 'C:\EDRViewer\Data\Viking Orbiters\f122s01.imq';

  StringGrid.Cells[0, 0] := '/home/bryan/EDRViewer/Vov/f035a72.bmp';
  StringGrid.Cells[1, 0] := '/home/bryan/EDRViewer/Data/Viking Orbiters/f035a72.imq';
  StringGrid.Cells[0, 1] := '/home/bryan/EDRViewer/Vov/f070a13.bmp';
  StringGrid.Cells[1, 1] := '/home/bryan/EDRViewer/Data/Viking Orbiters/f070a13.imq';
  StringGrid.Cells[0, 2] := '/home/bryan/EDRViewer/Vov/f101a32.bmp';
  StringGrid.Cells[1, 2] := '/home/bryan/EDRViewer/Data/Viking Orbiters/f101a32.imq';
  StringGrid.Cells[0, 3] := '/home/bryan/EDRViewer/Vov/f122s01.bmp';
  StringGrid.Cells[1, 3] := '/home/bryan/EDRViewer/Data/Viking Orbiters/f122s01.imq';

  StringGrid1.Cells[0, 0] := '/home/bryan/EDRViewer/Res/22D180.bmp';
  StringGrid1.Cells[1, 0] := '/home/bryan/EDRViewer/Res/vl_1422.bmp';


end;

function TForm1.TestIMQvsBMP(file1, file2: string): Integer;
var
  ABitmap: TBitmap;
  APDS: TPDSObject;
  P, PixelPtr: PInteger;
  BytePerPixel: integer;
  x, y: integer;

  Colour: TColor;
  R,G,B,V: byte;
  Status: Integer;

begin
  ABitmap := TBitmap.Create;
  ABitmap.LoadFromFile(file1);

  APDS := TPDSObject.Create;
  Status := APDS.LoadFromFile(file2);

  Result := 0;

  if (Status = 0) then
  begin
    if (APDS.ImageWidth <> ABitmap.Width) or
       (APDS.ImageHeight <> ABitmap.Height) then
      Result := 1;

    P := PInteger(ABitmap.RawImage.Data);
    BytePerPixel := ABitmap.RawImage.Description.BitsPerPixel div 8;

    for y := 0 to ABitmap.Height - 1 do
    begin
      if (Result <> 0) then
        break;
      PixelPtr := P;
      for x := 0 to ABitmap.Width - 1 do
      begin
        Colour := PixelPtr^;
        V := APDS.ImageData[y * APDS.ImageWidth + x];
        RedGreenBlue(Colour, R, G, B);
        //ShowMessage(IntToHex((R or G or B), 2)+' '+ IntToHex(V,2));
        if ((R or G or B) <> V) then
        begin
          ShowMessage(IntToHex(Colour, 8)+' '+ IntToHex(V,2)+' X:'+IntToStr(x)+' Y:'+ IntToStr(y));
          //Result := 2;
          break;
        end;
        Inc(PByte(PixelPtr), BytePerPixel);
      end;
      Inc(PByte(P), ABitmap.RawImage.Description.BytesPerLine);
    end;
  end else
    Result := -1;

  APDS.Free;
  ABitmap.Free;
end;

function TForm1.TestBMPvsBMP(file1, file2: string): Integer;
var
  ABitmap, BBitmap: TBitmap;
  P, PixelPtr: PInteger;
  Q, PixelPtr2: PInteger;

  BytePerPixel, BytePerPixel2: integer;
  x, y: integer;
  ColourA, ColourB: TColor;
  Status: Integer;
begin
  ABitmap := TBitmap.Create;
  ABitmap.LoadFromFile(file1);

  BBitmap := TBitmap.Create;
  BBitmap.LoadFromFile(file2);

  Status := 0;

  if (BBitmap.Width <> ABitmap.Width) or
     (BBitmap.Height <> ABitmap.Height) then
  begin
    Result := 1;
    exit;
  end;

  P := PInteger(ABitmap.RawImage.Data);
  BytePerPixel := ABitmap.RawImage.Description.BitsPerPixel div 8;
  BytePerPixel2 := BBitmap.RawImage.Description.BitsPerPixel div 8;

  Q := PInteger(BBitmap.RawImage.Data);


  for y := 0 to ABitmap.Height - 1 do
  begin
    PixelPtr := P;
    PixelPtr2 := Q;
    for x := 0 to ABitmap.Width - 1 do
    begin
      ColourA := PixelPtr^;
      ColourB := PixelPtr2^;
      if (ColourA <> ColourB) then
      begin
        Memo.Lines.Add(IntToHex(ColourA, 8)+' vs ' + IntToHex(ColourB, 8)  +' at X:'+IntToStr(x)+' Y:'+ IntToStr(y));
        Status := 2;
      end;
      Inc(PByte(PixelPtr), BytePerPixel);
      Inc(PByte(PixelPtr2), BytePerPixel2);
    end;
    Inc(PByte(P), ABitmap.RawImage.Description.BytesPerLine);
    Inc(PByte(Q), BBitmap.RawImage.Description.BytesPerLine);
  end;

  BBitmap.Free;
  ABitmap.Free;
  Result := Status;
end;

procedure TForm1.btnTestClick(Sender: TObject);
var
  I: integer;
  Status: integer;
begin
  for I := 0 to StringGrid.RowCount - 1 do
  begin
    if FileExists(StringGrid.Cells[0, I]) and FileExists(StringGrid.Cells[1, I]) then
    begin
      Status := TestIMQvsBMP(StringGrid.Cells[0, I], StringGrid.Cells[1, I]);
      case Status of
       -1: StringGrid.Cells[2,I] := 'Error: processing';
        0: StringGrid.Cells[2,I] := 'Success';
        1: StringGrid.Cells[2,I] := 'Error: Image size mismatch';
        2: StringGrid.Cells[2,I] := 'Error: data mismatch';
      end;
    end;
  end;

  for I := 0 to StringGrid1.RowCount - 1 do
  begin
    if FileExists(StringGrid1.Cells[0, I]) and FileExists(StringGrid1.Cells[1, I]) then
    begin
      Status := TestBMPvsBMP(StringGrid1.Cells[0, I], StringGrid1.Cells[1, I]);
      case Status of
       -1: StringGrid1.Cells[2,I] := 'Error: processing';
        0: StringGrid1.Cells[2,I] := 'Success';
        1: StringGrid1.Cells[2,I] := 'Error: Image size mismatch';
        2: StringGrid1.Cells[2,I] := 'Error: data mismatch';
      end;
    end;
  end;

end;

end.

