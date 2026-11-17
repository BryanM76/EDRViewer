unit FileParser;

{************************************************************************
 *
 *  Module:       FileParser.pas
 *  Description:  Help identify file type
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
  TPDSFileType = (ftUnknown, ftPDS1, ftPDS2, ftPDS3, ftODL3, ftVICAR, ftSDDPT);
  TPDSRecordType = (rtUndefined, rtVar, rtFixed);

  TFileParser = class(TObject)
  private
    FLabelData: string;
    FRecordType: TPDSRecordType;
    FFileType: TPDSFileType;
    FRecSize: Integer;
    FLabelRecSize: Integer;
    FLabelSize: Integer;
  public
    constructor Create;
    function Parse(Filename: string): Integer;
  published
    property RecordType: TPDSRecordType read FRecordType;
    property LabelData: string read FLabelData;
    property FileType: TPDSFileType read FFileType;
    property RecSize: Integer read FRecSize;
    property LabelRecSize: Integer read FLabelRecSize;
    property LabelSize: Integer read FLabelSize;
  end;

implementation

uses
  LabelParser;

constructor TFileParser.Create;
begin
  FLabelData := '';
  FRecordType := rtUndefined;
  FLabelSize := -1;
  FRecSize := -1;
  FLabelRecSize := -1;

end;

function TFileParser.Parse(Filename: string): Integer;
var
  infile: file;
  flength: integer;
  linebuf:string;
  pad: byte;
  d: byte;
  wordID: word;
  flagSDDPT, flagPDS3, flagODL3, flagVIC, flagPDS1, flagPDS2: boolean;
  RecordTypeString: string;
  FileExt: string;
  FileValue: Integer;
  C: Integer;
  FileNumExt:boolean;
begin
  AssignFile(infile, Filename);
  {$I-}
  Reset(infile, 1);
  {$I+}
  if IOResult <> 0 then
  begin
    result := -1;
    exit;    // exit if there was problem in opening the file
  end;

  d := 0;
  wordID := 0;
  pad := 0;
  flength := 0;
  FLabelData := '';

  FileExt := LowerCase(ExtractFileExt(Filename));
  Val(Copy(FileExt,2,3), Filevalue, C);
  FileNumExt := (C = 0);

  if (FileNumExt) then                 //possible SDDPT file
  begin
    blockread(infile,wordID,2);
    if wordID <> 256 then
      blockread(infile,wordID,2);
  end else if FileExt = '.imq' then    //variable length
  begin
    while not EOF(infile) do
    begin
      blockread(infile, flength, 2);   //expect 16-bit length field
      if flength = 0 then
        break;
      SetLength(linebuf, flength);
      blockread(infile, linebuf[1], flength);
      if (flength and 1 = 1) then  // is the length an odd number ?
        blockread(infile, pad, 1);    // then read the final 'padding' byte
      FLabelData := FLabelData + linebuf + #13#10;
      if linebuf = 'END' then  // end of SFDU label encountered ?
        break;
    end;
  end else
  begin      //fixed length
    while not EOF(infile) do
    begin
      blockread(infile, d, 1);      // fetch a line one character at a time
      linebuf := linebuf + Chr(d);  // copy data to FLabelData
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
  end;
  CloseFile(infile);

  flagPDS1 := (Pos('NJPL1I00PDS100000000', FLabelData) > 0);
  flagPDS2 := (Pos('NJPL3IF0PDS200000001', FLabelData) > 0);
  flagPDS3 := (ReadStringParamValue(FLabelData, 'PDS_VERSION_ID') = 'PDS3');
  flagODL3 := (ReadStringParamvalue(FLabelData, 'ODL_VERSION_ID') = 'ODL3');
  flagVIC  := (ReadIntegerParamValue(FLabelData,'LBLSIZE') > -1);
  flagSDDPT := (wordID = 256);

  if flagPDS1 then
    FFileType := ftPDS1
  else if flagPDS2 then
    FFileType := ftPDS2
  else if flagPDS3 then
    FFileType := ftPDS3
  else if flagODL3 then
    FFileType  := ftODL3
  else if flagVIC then
    FFileType := ftVICAR
  else if flagSDDPT then
    FFileType := ftSDDPT
  else
    FFileType := ftUnknown;

  RecordTypeString := (ReadStringParamValue(FLabeldata, 'RECORD_TYPE'));
  if (RecordTypeString = 'VARIABLE_LENGTH') then
    FRecordType := rtVar
  else if (RecordTypeString = 'FIXED_LENGTH') then
    FRecordType := rtFixed
  else
    FRecordType := rtUndefined; //undefined

  FRecSize      := ReadIntegerParamValue(FLabelData, 'RECORD_BYTES');
  FLabelRecSize := ReadIntegerParamValue(FLabelData, 'LABEL_RECORDS');
  FLabelSize    := Length(FLabelData);
end;


end.

