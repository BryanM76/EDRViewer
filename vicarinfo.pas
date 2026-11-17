unit VICARInfo;
{************************************************************************
 *
 *  Module:       VICARInfo.pas
 *  Description:  VICAR object for holding and processing VICAR data
 *                objects.
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

interface

uses
  Classes, SysUtils;

type
  TData = array of byte;

  TVicarObject = class(TObject)
  private
    FLabelData,FEOFLabelData: string;
    FImageData: TData;
    FImageHeight: Integer;
    FImageWidth: Integer;
    FRecSize: Integer;
    FLabelRecSize: Integer;
    FImageStart: Integer;
    FflagEOL: boolean;
    //FSpare: Int64;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadFromFile(const Filename: string): Integer;
  published
    property ImageData: TData read FImageData;
    property ImageHeight: integer read FImageHeight;
    property ImageWidth: integer read FImageWidth;
    property LabelData: string read FLabelData;
    property EndOfFileLabelData: string read FEOFLabelData;
    property EOLLabel: boolean read FflagEOL;
  end;

implementation

uses
  Math, LabelParser;

constructor TVicarObject.Create;
begin
  FRecSize := -1;
  FLabelRecSize := -1;
  FImageStart := 0;
  FImageHeight := 0;
  FImageWidth := 0;

  FImageData := nil;
end;

destructor TVicarObject.Destroy;
begin
  FImageData := nil;

  inherited;
end;

function TVicarObject.LoadFromFile(const Filename: string): Integer;
const
  DEFAULT_BPP = 8;  //for now assume display uses at least 8 bits per pixel
var
  infile: file;
  d: byte;
  dvalue: Integer;
  m,n: Integer;
  inbuf, outbuf: array of byte;
  filetype: string;
  dataformat: string;
  FPrefixBytes: Integer;
  FBitsPerPixel: Integer;
  FNumLines: Integer;
  MaxSrcRange, MaxDstRange: Integer;
  lineoffset: Integer;

  function ReadLabel: string;
  var
    LocalRecSize, count: Integer;
    LocalData: string;
  begin
    count := 0;
    LocalRecSize := -1;
    LocalData := '';

    while not EOF(infile) do
    begin
      blockread(infile, d, 1);
      if (d > 0) then
        LocalData := LocalData + Chr(d);

      if (d = 32) and (LocalRecSize = -1) then
        LocalRecSize := ReadIntegerParamValue(LocalData, 'LBLSIZE');
      if (d = 0) and (LocalRecSize = -1) then
        break;
      count := count + 1;
      if (LocalRecSize > -1) then
        if count >= (LocalRecSize) then
          break;
    end;
    Result := LocalData;
  end;

begin
  Result := -1;

  FRecSize := -1;
  FLabelRecSize := -1;
  FLabelData := '';
  FEOFLabelData := '';

  AssignFile(infile, Filename);
  {$I-}
  Reset(infile, 1);
  {$I+}
  if IOResult <> 0 then
    exit;

  try
    d := 0;

    FLabelData    :=  ReadLabel;

    FLabelRecSize := ReadIntegerParamValue(FLabelData, 'LBLSIZE');
    FRecSize      := ReadIntegerParamValue(FLabelData, 'RECSIZE');
    FImageHeight  := ReadIntegerParamValue(FLabelData, 'NL');
    FImageWidth   := ReadIntegerParamValue(FLabelData, 'NS');
    filetype      := ReadStringParamValue(FLabelData, 'TYPE', true);  //drop single quotes
    FflagEOL      := (ReadIntegerParamValue(FLabelData, 'EOL') = 1);
    dataformat    := ReadStringParamValue(FLabelData, 'FORMAT', true); //drop single quotes
    //FSpare := Length(FLabelData); //debug
    //FSpare := FilePos(infile);  //debug

    if (FRecSize <= 0) or (FLabelRecSize <= 0) then
      exit;  //exit if label records or record bytes parameters are not found

    if (filetype <> 'IMAGE') then
      exit;                  // exit if not an image file

    if dataformat = 'BYTE' then
      FBitsPerPixel := 8
    else if dataformat = 'HALF' then
      FBitsPerPixel := 16
    else if dataformat = 'FULL' then
      FBitsPerPixel := 32
    else
      exit; // unsupported data type

    //Get the number of bytes of binary prefix before each record
    FPrefixBytes  := ReadIntegerParamValue(FLabelData, 'NBB');
    //Get the number of lines (records) of binary header at the top of the file (between the label and the image)
    FNumLines     := ReadIntegerParamvalue(FLabeldata, 'NLB');

    MaxSrcRange   := (2**FBitsPerPixel) -1;       // max. range of pixel data
    MaxDstRange   := (2**DEFAULT_BPP) -1;         // max. range to display pixel (usually 255)

    SetLength(FImageData, FImageHeight * FImageWidth);   // setup image data (use 8 BPP)

    SetLength(inbuf, FRecSize);
    SetLength(outbuf, FImageWidth);

    if (FNumLines > 0) then
      for n := 0 to FNumLines-1 do
        blockread(infile, inbuf[0], FRecSize); // read past number of lines

    for n := 0 to FImageHeight - 1 do
    begin
      blockread(infile, inbuf[0], FRecSize);     // read one record at a time

      for m := 0 to FImageWidth-1 do
      begin
        lineoffset := FPrefixBytes + m;
        if (FBitsPerPixel > DEFAULT_BPP) then         // number of storage bit per pixel exceeds default ?
          dvalue := inbuf[lineoffset*2+0] * 256 +
                    inbuf[lineoffset*2+1];          // read 16-bits (big endian) if so
        if (MaxSrcRange > MaxDstRange) then      // range from source exceeds display capability ?
          outbuf[m] := Round((dvalue/MaxSrcRange) * MaxDstRange)  // downsize if so
        else
          outbuf[m] := inbuf[lineoffset];   // no processing required
      end;

      for m := 0 to FImageWidth-1 do
        FImageData[n * FImageWidth +m] := outbuf[m]; //copy final output line sample to ImageData
    end;

    if FflagEOL then
      FEOFLabelData := ReadLabel;    //Read End Of file Labels if present

  finally
    CloseFile(infile);
  end;
  result := 0;
end;


end.

