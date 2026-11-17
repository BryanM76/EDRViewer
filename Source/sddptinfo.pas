unit SDDPTInfo;

{************************************************************************
 *
 *  Module:       SDDPTInfo.pas
 *  Description:  SDDPTInfo object for holding and processing SDDPT data.
 *
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

const
  LOGREC_SIZE = 72;
  EBCDICToASCIITable: array[0..255] of byte =
    (
          0,  1,  2,  3,156,  9,134,127,151,141,142, 11, 12, 13, 14, 15,
         16, 17, 18, 19,157,133,  8,135, 24, 25,146,143, 28, 29, 30, 31,
        128,129,130,131,132, 10, 23, 27,136,137,138,139,140,  5,  6,  7,
        144,145, 22,147,148,149,150,  4,152,153,154,155, 20, 21,158, 26,
         32,160,161,162,163,164,165,166,167,168, 91, 46, 60, 40, 43, 33,
         38,169,170,171,172,173,174,175,176,177, 93, 36, 42, 41, 59, 94,
         45, 47,178,179,180,181,182,183,184,185,124, 44, 37, 95, 62, 63,
        186,187,188,189,190,191,192,193,194, 96, 58, 35, 64, 39, 61, 34,
        195, 97, 98, 99,100,101,102,103,104,105,196,197,198,199,200,201,
        202,106,107,108,109,110,111,112,113,114,203,204,205,206,207,208,
        209,126,115,116,117,118,119,120,121,122,210,211,212,213,214,215,
        216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,
        123, 65, 66, 67, 68, 69, 70, 71, 72, 73,232,233,234,235,236,237,
        125, 74, 75, 76, 77, 78, 79, 80, 81, 82,238,239,240,241,242,243,
         92,159, 83, 84, 85, 86, 87, 88, 89, 90,244,245,246,247,248,249,
         48, 49, 50, 51, 52, 53, 54, 55, 56, 57,250,251,252,253,254,255
    );   //derived from avaneya.com (VikingExtractor)

type
  TSDDPTData = array of byte;
  TLogicalRec = array [0..LOGREC_SIZE-1] of byte;

  TSDDPTObject = class(TObject)
  private
    FImageHeight: Integer;
    FImageWidth: Integer;
    FImageData: TSDDPTData;
    FLabelData: string;
    FSpare: Int64;
    function EBCDICtoAscii(Input: TLogicalRec; FromOffset: Integer=0):string;
    function GetIntegerValue(Input:String; Offset:Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadFromFile(const Filename: string): Integer;
    property ImageData: TSDDPTData read FImageData;
    property ImageHeight: integer read FImageHeight;
    property ImageWidth: integer read FImageWidth;
  published
    property LabelData: string read FLabelData;
  end;

implementation

constructor TSDDPTObject.Create;
begin
  //
end;

destructor TSDDPTObject.Destroy;
begin
  FImageData := nil;

  inherited;
end;

function TSDDPTObject.EBCDICtoAscii(Input: TLogicalRec; FromOffset: Integer):string;
var
  I: Integer;
  st: string;
  c,d: byte;
begin
  st := '';
  For I := FromOffset to 71 do
  begin
    c := Input[I];
    d := (EBCDICToASCIITable[c]);
    //bm 04-Jan-22 safety for macOS and Linux: Ignore values that fall outside of this range
    if (d > 31) and (d < 128) then
    //if d > 31 then
      st := st + Chr(d);
  end;
  result := st;
end;

function TSDDPTObject.GetIntegerValue(Input:String; Offset:Integer): Integer;
var
  s: string;
  I,v,c: Integer;
begin
  s:= '';
  For I := Offset to Length(Input) do
  begin
    if Input[I] = #32 then
      break;
    s := s + Input[I];
  end;
  Val(s, v, c);
  if c = 0 then
    Result := v
  else
    Result := -1;
end;

function TSDDPTObject.LoadFromFile(const Filename: string): Integer;
const
  SDDPT_ID = $0100;
  ID_CONT  = $C3;
  ID_EOL   = $D3;
  CH_SPC   = $40;
var
  infile: file;
  FileID: word;
  RecLength: Integer;
  RecSize: Integer;
  Rec: TLogicalRec;
  textbuf: string;
  BytesRead, ByteCount: Integer;
  InBuf: array of byte;
  Flag_EndOfLabel: boolean;
  I,J,K: Integer;
  FMode: Integer;

  //outfile: textfile; //debug
begin
  result := -1;
  FileID := 0;
  RecLength := 360; //default
  ByteCount := 0;
  BytesRead := 0;
  Flag_EndOfLabel := false;

  AssignFile(infile, Filename);
  {$I-}
  Reset(infile, 1);
  {$I+}
  if IOResult <> 0 then
    exit;    // exit if there was problem in opening the file

  try
    BlockRead(infile, FileID,2);
    if (FileID <> SDDPT_ID) then
    begin
      RecLength := FileID;
      FMode := 1;
    end else
    begin
      Seek(infile,0);
      FMode := 0;
    end;

    BlockRead(infile, Rec,LOGREC_SIZE, ByteCount);  // First logical record
    FileID := Rec[1] shl 8 + Rec[0];

    if (FileID <> SDDPT_ID) then
      exit;

    if Rec[LOGREC_SIZE-1] <> ID_CONT then
      exit;

    Rec[LOGREC_SIZE-1] := CH_SPC;   // change to EBCDIC space

    //convert first logical record, skipping 2 bytes from the start
    textbuf := EBCDICtoAscii(Rec,2);

    //FImageHeight := GetIntegerValue(textbuf,31);
    //FImageWidth  := GetIntegerValue(textbuf,36);
    //RecSize := FImageWidth;

    FImageHeight := GetIntegerValue(textbuf,36);
    FImageWidth  := GetIntegerValue(textbuf,31);
    if FImageWidth = -1 then
      FImageWidth  := GetIntegerValue(textbuf,32);  //!
    RecSize := FImageHeight;

    SetLength(InBuf,RecSize - RecLength);

    if (FImageHeight < 0) or (FImageWidth < 0) then
      exit;

    while not EOF(infile) do
    begin
      BlockRead(infile, Rec,LOGREC_SIZE, BytesRead);
      ByteCount := ByteCount + BytesRead;

      if not Flag_EndofLabel then
        if not ((Rec[LOGREC_SIZE-1] = ID_CONT) or (Rec[LOGREC_SIZE-1] = ID_EOL)) then
          break;

      if (Rec[LOGREC_SIZE-1] = ID_EOL) then
        Flag_EndOfLabel := true;
      Rec[LOGREC_SIZE-1] := CH_SPC;

      if not Flag_EndOfLabel then
        textbuf := textbuf + EBCDICtoAscii(Rec);

      if (ByteCount >= RecLength) then
      begin
        if (FMode = 0) then
          BlockRead(infile, InBuf[0], RecSize - RecLength);
        if (FMode = 1) then
        begin
          BlockRead(infile, FileID,2);
          if (RecLength <> FileID) then
            break;
        end;
        ByteCount := 0;
        if (FMode = 0) then
          if Flag_EndOfLabel then
            break;
      end;
    end;
    FLabelData := textbuf;
    //FLabelData := Copy(textbuf,1,128); //debug DEBUG TEST


    //FSpare := FilePos(infile);  //debug
    FSpare := Length(FLabelData);

    //AssignFile(outfile,'debug.txt');
    //Rewrite(outfile);
    //Write(outfile, textbuf);
    //CloseFile(outfile);  //DEBUG


    SetLength(FImageData, FImageHeight * FImageWidth);

    if (FMode = 1) then
    begin
      RecLength := FileID;
      SetLength(InBuf, RecLength);
      for I := 0 to FImageWidth -1 do
      begin
        if (I > 0) then
        begin
          BlockRead(infile, FileID,2);
          if (RecLength <> FileID) then
            break;
        end;
        BlockRead(infile,InBuf[0], FImageHeight);
        K := 0;
        for J := FImageHeight-1 downto 0 do
        begin
          FImageData[J * FImageWidth + I] := inbuf[K];
          K := K + 1;
        end;
      end;
    end;

    if (FMode = 0) then
    begin
      //SetLength(InBuf, FImageWidth);
      //for I := 0 to FImageHeight -1 do
      //begin
      //  BlockRead(infile,InBuf[0], FImageWidth);
      //  for J := 0 to FImageWidth -1 do
      //    FImageData[I * FImageWidth + J] := inbuf[J];
      //end;

      SetLength(InBuf, FImageHeight);
      for I := 0 to FImageWidth -1 do
      begin
        BlockRead(infile,InBuf[0], FImageHeight);
        K := 0;
        for J := FImageHeight-1 downto 0 do
        begin
          FImageData[J * FImageWidth + I] := inbuf[K];
          K := K + 1;
        end;
      end;
    end;
  finally
    CloseFile(infile);
  end;
  result := 0;
end;



end.

