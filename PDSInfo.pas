unit PDSInfo;

{************************************************************************
 *
 *  Module:       PDSInfo.pas
 *  Description:  PDSInfo object for holding and processing PDS3 data
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
  Classes, SysUtils, Dialogs;

type
  TPDSData = array of byte;

  TPDSObject = class(TObject)
  private
    FRecSize, FLabelRecSize: integer;
    FImageHeight: integer;
    FImageWidth: integer;
    FImageStart: integer;
    FImageHeaderStart: Integer;
    FLabelData: string;
    FHistStart: integer;
    FHistData: TPDSData;
    FHistItemCount: integer;
    FHistItemSize: integer;
    FHistDataType: string;
    FImageData: TPDSData;
    FHuffTreeStart: integer;
    FEngTableStart: integer;
    FLHTableStart: integer;
    FEncHist: TPDSData;
    FPrefixBytes: Integer;
    function BitmasktoBPP(SampleMask: string): Integer;
    function BitmasktoBits(SampleMask: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadFromFile(const Filename: string): Integer;
    property HistogramData: TPDSData read FHistData;
    property HistogramItemCount: integer read FHistItemCount;
    property HistogramDataType: string read FHistDataType;
    property HistogramItemSize: integer read FHistItemSize;
    property ImageData: TPDSData read FImageData;
    property ImageHeight: integer read FImageHeight;
    property ImageWidth: integer read FImageWidth;
  published
    property LabelData: string read FLabelData;
  end;

implementation

uses
  Math, Decomp, LabelParser;

constructor TPDSObject.Create;
begin
  //inherited;

  FHistDataType := '';
  FRecSize := -1;
  FLabelRecSize := -1;
  FHistStart := -1;
  FHistItemCount := 0;
  FHistItemSize := 0;
  FHuffTreeStart := 0;
  FEngTableStart := 0;
  FLHTableStart := 0;
  FImageStart := 0;
  FImageHeight := 0;
  FImageWidth := 0;

  FHistData := nil;
  FEncHist := nil;
  FImageData := nil;
end;

destructor TPDSObject.Destroy;
begin
  FHistData := nil;
  FImageData := nil;
  FEncHist := nil; // bm 02-Jan-20

  inherited;
end;

function TPDSObject.LoadFromFile(const Filename: string): Integer;
const
  DEFAULT_BPP = 8;  //for now assume display uses at least 8 bits per pixel
var
  infile: file;
  m,n: Integer;
  ptr: integer;
  d: byte;
  textbuf: string;
  inbuf, outbuf: array of byte;
  flength: word;
  pad: byte;
  flagPDS3, flagPDS2: boolean;

  FSampleMask: string;
  FSampleBits: Integer;
  FBitsPerPixel: Integer;
  MaxSrcRange, MaxDstRange: Integer;
  dvalue: Integer;
  linebuf: string;

  //FPosDebug: integer;  //debug
  LabelEnd : Integer;
begin
  pad := 0;
  flength := 0;

  flagPDS3 := false;
  flagPDS2 := false;

  Result := -1;
  FRecSize := -1;
  FLabelRecSize := -1;
  LabelEnd := -1;

  //STEP 1: check if the file contains PDS_VERSION, RECORD_BYTES and LABEL_RECORDS
  //        labels in order to distinguish it as valid.
  //        Copy PDS label data to FLabelData
  AssignFile(infile, Filename);
  {$I-}
  Reset(infile, 1);
  {$I+}
  if IOResult <> 0 then
    exit;    // exit if there was problem in opening the file

  if LowerCase(ExtractFileExt(Filename)) = '.imq' then     //variable length IMQ
  begin
    while not EOF(infile) do       // fetch label records
    begin
      blockread(infile, flength, 2);
      if flength = 0 then
        break;
      SetLength(textbuf, flength);
      blockread(infile, textbuf[1], flength);
      if (flength and 1 = 1) then  // is the length an odd number ?
        blockread(infile, pad, 1);    // then read the final 'padding' byte
      FLabelData := FLabelData + textbuf + #13#10;
      if textbuf = 'END' then  // end of SFDU label encountered ?
        break;
    end;

    FRecSize      := ReadIntegerParamValue(FLabelData, 'RECORD_BYTES');
    FLabelRecSize := ReadIntegerParamValue(FLabelData, 'LABEL_RECORDS');

    if (FRecSize < 0) or (FLabelRecSize < 0) then
      exit;  //exit if label records or record bytes parameters are not found

    FHistStart      := ReadIntegerParamValue(FLabelData, '^IMAGE_HISTOGRAM');
    FHistItemCount  := ReadIntegerParamValue(FLabelData, 'IMAGE_HISTOGRAM.ITEMS');
    if FHistItemCount > 0 then
    begin
      FHistDataType := ReadStringParamValue(FLabelData,  'IMAGE_HISTOGRAM.ITEM_TYPE');
      FHistItemSize := ReadIntegerParamValue(FLabelData, 'IMAGE_HISTOGRAM.ITEM_BITS');
    end;
    FHuffTreeStart  := ReadIntegerParamValue(FLabelData, '^ENCODING_HISTOGRAM');
    FEngTableStart  := ReadIntegerParamValue(FLabelData, '^ENGINEERING_TABLE');
    FLHTableStart   := ReadIntegerParamValue(FLabelData, '^LINE_HEADER_TABLE');
    FImageStart     := ReadIntegerParamValue(FLabelData, '^IMAGE ');
    FImageHeight    := ReadIntegerParamValue(FLabelData, 'IMAGE.LINES');
    FImageWidth     := ReadIntegerParamValue(FLabelData, 'IMAGE.LINE_SAMPLES');
    FSampleMask     := ReadStringParamValue(FLabelData,  'SAMPLE_BIT_MASK'); //bm 18-Feb-20

    ptr := 0;
    for n := FHistStart to FHuffTreeStart - 1 do      //read image histogram
    begin
      blockread(infile, flength, 2);
      SetLength(FHistData, Length(FHistData) + flength);
      blockread(infile, FHistData[ptr], flength);
      ptr := ptr + flength;
    end;

    ptr := 0;
    for n := FHuffTreeStart to FEngTableStart - 1 do      //read encoding histogram table
    begin
      blockread(infile, flength, 2);
      SetLength(FEncHist, Length(FEncHist) + flength);
      blockread(infile, FEncHist[ptr], flength);
      ptr := ptr + flength;
    end;

    if FEngTableStart > -1 then
    begin
      for n := FEngTableStart to FLHTableStart - 1 do  // skip engineering table (not used)
      begin
        blockread(infile, flength, 2);
        SetLength(inbuf, flength);
        blockread(infile, inbuf[0], flength);
      end;
    end;

    if FLHTableStart > -1 then  //bm 17-Feb-20 PDS1
    begin
      for n := FLHTableStart to FImageStart - 1 do  // skip line header table (not used)
      begin
        blockread(infile, flength, 2);
        SetLength(inbuf, flength);
        blockread(infile, inbuf[0], flength);
      end;
    end;

    SetLength(FImageData, FImageHeight * FImageWidth);  // setup image data
    SetLength(outbuf, FImageWidth);

    InitTree(FEncHist);   //intialise huffman tree (for decompression)

    for n := 0 to FImageHeight - 1 do
    begin
      blockread(infile, flength, 2);
      SetLength(inbuf, flength);
      blockread(infile, inbuf[0], flength);

      if (flength and 1 = 1) then   // is the length an odd number ?
        blockread(infile, pad, 1);    // then read the final 'padding' byte

      try
        Decompress(inbuf,outbuf);    // decompress line data
      except
        Result := n;
        exit;
      end;

      for m:=0 to FImageWidth-1 do
        FImageData[n*FImageWidth+m] := outbuf[m];  // assign decompressed data to FImageData

      //for m := 0 to flength - 1 do
      //  FImageData[n * FImageWidth + m] := inbuf[m]; //DEBUG copy UNCOMPRESSED data as is
    end;
    FreeTree;  // free the tree when done
    //outbuf := nil;
  end else
  begin                           // assume fixed length
    d := 0;
    linebuf := '';
    while not EOF(infile) do
    begin
      blockread(infile, d, 1);      // fetch a line one character at a time
      linebuf := linebuf + Chr(d);  // copy data to linebuf
      if (d = 0) then
        break;                      // exit on NULL
      if (d= 10) then               // linefeed ?
      begin
        if FRecSize < 0 then   // is the record size known ?
          FRecSize := ReadIntegerParamValue(linebuf, 'RECORD_BYTES');  // see if it exists
        if FLabelRecSize < 0 then  // is the label record size known
          FLabelRecSize := ReadIntegerParamValue(linebuf, 'LABEL_RECORDS'); //see if it exists
        linebuf := '';  //clear
      end;

      FLabelData := FLabelData + Chr(d);  //add to Label

      if (FRecSize > -1) and (FLabelRecSize > -1) then  // are both the record size and label record sizes known ?
      begin
        // does the current label size match or exceed that of the expected size ?
        if Length(FLabelData) >= (FRecSize * FLabelRecSize) then
          break;  //exit if so
      end;
    end;
    if (FRecSize <= 0) or (FLabelRecSize <= 0) then
      exit;  //exit if label records or record bytes parameters are not found

    LabelEnd := FRecSize * FLabelRecSize;               //bm 31-Dec-20 for some .IMG files (PathFinder, Sojourner)
    if Length(FLabelData) < (LabelEnd) then
       for n := Length(FLabelData)+1 to LabelEnd-1 do
         blockread(infile, d, 1);

    flagPDS2 := (Pos('NJPL3IF0PDS200000001', FLabelData) > 0);
    flagPDS3 := (ReadStringParamValue(FLabelData, 'PDS_VERSION_ID') = 'PDS3');


    //if flagVICAR then  //debug
    //  FImageStart   := FLabelRecSize +  FPrefixBytes
    //else
    FImageStart   := ReadIntegerParamValue(FLabelData, '^IMAGE ');

    if flagPDS3 then
      FHistStart      := ReadIntegerParamValue(FLabelData, '^HISTOGRAM');  //PDS3
    if flagPDS2 then
      FHistStart    := ReadIntegerParamValue(FLabelData, '^IMAGE_HISTOGRAM'); //PDS2

    if FHistStart > -1 then
    begin
      if flagPDS3 then
      begin
        FHistItemCount := ReadIntegerParamValue(FLabelData, 'HISTOGRAM.ITEMS');
        FHistDataType  := ReadStringParamValue(FLabelData,  'HISTOGRAM.DATA_TYPE');
        FHistItemSize  := ReadIntegerParamValue(FLabelData, 'HISTOGRAM.ITEM_BYTES');
      end;
      if flagPDS2 then
      begin
        FHistItemCount := ReadIntegerParamValue(FLabelData, 'IMAGE_HISTOGRAM.ITEMS');
        FHistDataType  := ReadStringParamValue(FLabelData,  'IMAGE_HISTOGRAM.ITEM_TYPE');
        FHistItemSize  := ReadIntegerParamValue(FLabelData, 'IMAGE_HISTOGRAM.ITEM_BITS');
      end;
      if FHistItemCount > 0 then // 27-Dec-20
      begin
        // calculate offset addresses for histogram and image objects
        FImageStart := (FImageStart - 1) * FRecSize;    // 27-Dec-20
        FHistStart := (FHistStart - 1) * FRecSize;   // 27-Dec-20

        SetLength(FHistData, FImageStart - FHistStart);
        blockread(infile, FHistData[0], dword(FImageStart - FHistStart));
      end;
    end;

    {
    if flagVICAR then //bm 19-Feb-20 debug
    begin
      FImageHeight := ReadIntegerParamValue(FLabelData, 'NL');
      FImageWidth  := ReadIntegerParamValue(FLabelData, 'NS');
      FSampleMask  := '2#11111111#';
    end else
    begin}
    FImageHeight    := ReadIntegerParamValue(FLabelData, 'IMAGE.LINES');
    FImageWidth     := ReadIntegerParamValue(FLabelData, 'IMAGE.LINE_SAMPLES');
    FSampleMask     := ReadStringParamValue(FLabelData,  'SAMPLE_BIT_MASK'); //bm 18-Feb-20
    FSampleBits     := ReadIntegerParamValue(FLabelData, 'SAMPLE_BITS'); //bm 31-Dec-20
    //end;

    //if flagVICAR then  //debug
    //  FPrefixBytes  := ReadIntegerParamValue(FLabelData, 'NBB')
    //else
    FPrefixBytes    := ReadIntegerParamValue(FLabelData, 'LINE_PREFIX_BYTES'); //bm 18-Feb-20
    if FPrefixBytes > -1 then
      FImageWidth := FImageWidth + FPrefixBytes; // Issue 008


    // Read image header data  (ODL3)
    // In future, the image header info could possibly be assigned to its own tab
    FImageHeaderStart  := ReadIntegerParamValue(FLabelData, '^IMAGE_HEADER');  //bm-18-Feb-20
    if FImageHeaderStart > 0 then
    begin
      FImageStart := (FImageStart - 1) * FRecSize;  // to be refactored maybe
      FImageHeaderStart := (FImageHeaderStart - 1) * FRecSize;
      SetLength(inbuf,FImageStart - FImageHeaderStart);
      Blockread(infile, inbuf[0], dword(FImageStart - FImageHeaderStart));
    end;
          {
    if flagVICAR then  //debug
    begin                     //read past zero bytes
      offset := FLabelRecSize - Length(FLabelData);
      SetLength(inbuf,offset);
      Blockread(infile, inbuf[0], offset);  // skip
    end; }

    //STEP 4: process image data
    //FSampleMask :=  '2#0000111111111111#'; //DEBUG for MSL
    FBitsPerPixel := BitmasktoBPP(FSampleMask);   // bits per pixel in use in image data
    //FNumBits      := BitmasktoBits(FSampleMask);  // number of bits used to hold data type
    if FBitsPerPixel = 0 then
      FBitsPerPixel := FSampleBits;    //bm 31-Dec-20

    MaxSrcRange   := (2**FBitsPerPixel) -1;       // max. range of pixel data
    MaxDstRange   := (2**DEFAULT_BPP) -1;         // max. range to display pixel (usually 255)

    SetLength(FImageData, FImageHeight * FImageWidth);   // setup image data (assume 8 BPP)
    //-- blockread(infile, FImageData[0], dword(FImageHeight * FImageWidth));  // normal 8 bpp

    SetLength(inbuf, FRecSize);
    SetLength(outbuf, FImageWidth);

    for n := 0 to FImageHeight - 1 do
    begin
      blockread(infile, inbuf[0], FRecSize);     // read one line at a time

      for m := 0 to FImageWidth-1 do
      begin
        if (FSampleBits > DEFAULT_BPP) then         // number of storage bit per pixel exceeds default ?
          dvalue := inbuf[m*2+0] * 256 + inbuf[m*2+1]; // read 16-bits (big endian) if so
        if (MaxSrcRange > MaxDstRange) then      // range from source exceeds display capability ?
          outbuf[m] := Round((dvalue/MaxSrcRange) * MaxDstRange)  // downsize if so
        else
          outbuf[m] := inbuf[m];               // no processing required
      end;

      for m := 0 to FImageWidth-1 do
        FImageData[n * FImageWidth +m] := outbuf[m]; //copy final output
    end;

  end;
  closefile(infile);
  inbuf := nil; //bm 29-Dec-21
  outbuf := nil; //bm 29-Dec-21
  Result := 0;
end;

///
/// Returns the number of bits per pixel required by image as specified in the sample mask
///
function TPDSObject.BitmasktoBPP(SampleMask: string): Integer;
var
  n,s1,s2:Integer;
begin
  //result := 8;
  result := 0; //bm 31-Dec-20
  if Length(SampleMask) < 1 then
    exit;

  if SampleMask[1] = '2' then
  begin
    s1 := SampleMask.IndexOf('#',1);
    if (s1 > -1) then
    begin
      s1 := s1 + 1;
      s2 := SampleMask.IndexOf('#',s1+1);
      if (s2 > -1) then
      begin
        //result := s2 - s1;
        result := 0;
        for n := (s1+1) to s2 do
          if SampleMask[n] = '1' then
            result := result + 1;
      end;
    end;
  end;
end;

///
/// Returns the number of bits used to store pixel data as specified in the sample mask
///
function TPDSObject.BitmasktoBits(SampleMask: string): Integer;

var
  s1,s2:Integer;
begin
  result := 8;
  if Length(SampleMask) < 1 then
    exit;

  if SampleMask[1] = '2' then
  begin
    s1 := SampleMask.IndexOf('#',1);
    if (s1 > -1) then
    begin
      s1 := s1 + 1;
      s2 := SampleMask.IndexOf('#',s1+1);
      if (s2 > -1) then
        result := s2 - s1;
    end;
  end;
end;

end.
