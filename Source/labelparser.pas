unit LabelParser;

{************************************************************************
 *
 *  Module:       LabelParser.pas
 *  Description:  Search and return a string or integer value for a
 *                keyword within a string sequence containing
 *                "keyword=value" pairs.
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

function ReadStringParamValue(buf, Param: string; Dequote:boolean=false): string;
function ReadIntegerParamValue(buf, Param: string): integer;

implementation

function ReadStringParamValue(buf, Param: string; Dequote:boolean): string;
const
  COMMENT_START = '/*';
  COMMENT_END   = '*/';
  CRLF          = #13#10;
var
  fpstart, fpend: integer;
  prefix, suffix, st: string;
  c, temp: integer;
  Content: string;

  function FindParamValue(buf, Param: string; var FParamStart, FParamEnd: integer): string;
  var
    p,q: integer;
    flageq, flagp: boolean;
    n: Integer;
  begin
    Result := '';
    flageq := False;
    flagp := False;
    q := 0;
    p := 1;

    while p > 0 do
    begin
      p := Pos(COMMENT_START, buf);  // Ignore C style comments
      if p > 0 then                  // found start of comment
      begin
        //s1 := Pos(COMMENT_END, buf);  // look for end of comment
        q := buf.IndexOf(COMMENT_END,p+2);  //bm 17-Feb-20 search for end of comment (PDS2))
        if q = -1 then  // not found ?
          q := buf.IndexOf(CRLF,p+2);   //bm 17-Feb-20 search for end of line (PDS1)  (Voyager 1 and 2)
        if (q > 0) then
        begin
          Delete(buf, p, q + 2 - p);
          for n := p to q + 1 do
            Insert(' ', buf, p);  // replace with blanks
        end else
          exit;
      end;
    end;

    p := Pos(Param, buf);
    FParamStart := p;
    if p > 0 then
    begin
      while p <= Length(buf) do
      begin
        if flageq then
        begin
          if buf[p] = ' ' then
          begin
            if flagp and (q = 0) then
              break;
          end
          else if (buf[p] = #13) {or (buf[p]=#0)} then
            break
          else if buf[p] = '"' then
          begin
            if q > 0 then
            begin
              Result := Copy(buf, q, p - q);
              break;
            end
            else
              q := p;
          end
          else
          begin
            Result := Result + buf[p];
            flagp := True;
          end;
        end;
        if (buf[p] = '=') then
          flageq := True;
        p := p + 1;
      end;
      FParamEnd := p;
    end else
      FParamEnd := 0; //bm 22-Feb-20 not found
  end;

begin
  fpstart := 0;
  fpend := 0;
  temp := 0;
  //showmessage('param '+param); //debug
  c := Pos('.', Param);  // check for possible object descriptions
  if c > 0 then
  begin
    prefix := Copy(Param, 1, c - 1); // get object name
    suffix := Copy(Param, c + 1, Length(Param) - c + 1);

    while fpstart < Length(buf) do
    begin
      st := FindParamValue(buf, 'OBJECT', fpStart, temp);  // look for OBJECT tag
      if temp = 0  then //bm 22-Feb-20 not found
      begin
        Content := '';
        break;//exit;
      end;     //

      buf := Copy(buf, temp, Length(buf) - temp);
      fpstart := 0;
      if st = prefix then  // 'object' found ?
      begin
        while Length(buf) > 0 do  // bm 26-Jun-13
        begin
          //*st:= FindParamValue(buf,'END_OBJECT',temp,fpEnd);  //look for END_OBJECT
          //*if st= prefix then    // end object found ?

          fpEnd := Pos('END_OBJECT', buf);  // bm 18-Jul-13 this change made for
          if fpEnd > 0 then                 // PDS2 variable length records
          begin
            buf := Copy(buf, fpStart, fpEnd - fpStart - 1);
            Content := ReadStringParamValue(buf, suffix);
            break;
          end;
        end;
        break;
      end;
    end;
    //exit; //?
  end else
    Content := FindParamValue(buf, Param, fpStart, fpEnd);

  if Dequote then
    Result := Content.DeQuotedString  //remove single quotes surrounding content (if any)
  else
    Result := Content;
end;

function ReadIntegerParamValue(buf, Param: string): integer;
var
  V, c: integer;
begin
  Result := -1;
  Val(ReadStringParamValue(buf, Param), V, c);
  if c = 0 then
    Result := V;
end;

end.

