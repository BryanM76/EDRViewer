unit decomp;
{************************************************************************
 *
 *  Module:       decomp.pas
 *  Description:  Huffman first difference decompressor
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
  SysUtils;

{
type
  PHuffNode = ^THuffNode;
  THuffNode = record
    dn: smallint;
    Right: PHuffNode;
    Left : PHuffNode;
  end;

  TBuf = array of byte;
  PBuf = ^TBuf;
}

type
  THuffNode = record
    dn: smallint;
    LeftIndex : Integer;
    RightIndex: Integer;
  end;
  TBuf = array of byte;

procedure InitTree(hist: TBuf);
procedure Decompress(inbuf,outbuf:TBuf);
procedure FreeTree;

implementation

var
  HuffTree: array of THuffNode;
  NewNode: array of THuffNode;

(*
procedure InitTree(hist: PBuf);
var
  SortFreq: array of integer;
  hlen,i,k,m,n: integer;
  count: Int64;

  procedure SortByFrequency(var Freq: array of integer; var Tree: array of THuffNode);
  var
    i,j,k: Integer;
    t: THuffNode;
  begin   //bubble sort algorithm
    for i:= High(Freq) downto Low(Freq) do
      for j:= Low(Freq) to High(Freq) - 1 do
        if Freq[j] > Freq[j+1] then
        begin
          k:= Freq[j];
          Freq[j]:=Freq[j+1];
          Freq[j+1]:=k;

          t:= Tree[j];
          Tree[j]:= Tree[j+1];
          Tree[j+1]:= t;
        end;
  end; 

begin
  HuffTree := nil;
  NewNode := nil;

  SetLength(SortFreq, 512);
  SetLength(HuffTree, 512);

  hlen := Length(hist^) div 4;
  if hlen > 512 then
    exit;   // histogram cannot exceed a length of 512

  // step 1: initalise huffman tree and sort frequency array
  for n := 0 to hlen -1 do   // 2044 div 4 -> 511 elements expected
  begin
    count :=0;
    for m := 0 to 3 do
      count := count+ hist^[n*4+m] shl (8*m);
    SortFreq[n]:= count;
    HuffTree[n].dn:=n+1;
    //HuffTree[n].Left:= nil;
    //HuffTree[n].Right:=nil;
    HuffTree[n].LeftIndex:= -1;
    HuffTree[n].RightIndex:= -1;
  end;
  SortFreq[511] := 0;
  HuffTree[511].dn := 512;

  //Step 2: sort initial nodes in huffman tree by frequency, in ascending order
  SortByFrequency(SortFreq,HuffTree);

  //Step 3: scan through nodes, eliminate records with frequencies of zero
  //       and shift records to the top
  m := 0;
  for n :=0 to 511 do
    if SortFreq[n]>0 then
    begin
      HuffTree[m] := HuffTree[n];
      SortFreq[m] := SortFreq[n];
      m := m + 1;
    end;
  SetLength(HuffTree,m);
  SetLength(SortFreq,m);

  //step 4: reconstruct huffman tree
  i:=0;
  for n:= 0 to m-2 do
  begin
    Setlength(NewNode,Length(NewNode)+1);   // create extra nodes
    k:=High(NewNode);

    NewNode[k]:=HuffTree[i+1];           //copy left leaf
    HuffTree[i+1].dn:=-1;
    //HuffTree[i+1].Right := @HuffTree[i];  // assign right leaf
    //HuffTree[i+1].Left := @NewNode[k];    // assign left leaf
    HuffTree[i+1].RightIndex := i;  // assign right leaf index
    HuffTree[i+1].LeftIndex := k;    // assign left leaf index
    i:=i+1;

    SortFreq[n+1]:= SortFreq[n+1]+ SortFreq[n]; //sum of frequencies
    SortFreq[n]:=0;
    SortByFrequency(SortFreq,HuffTree); // sort again
  end;
                     //debug
  {
  AssignFile(f,'C:\EDRViewer\Res\HuffmanTree.csv');
  append(f);
  WriteLn(f,'HuffTree:');
  for n:=0 to High(HuffTree) do
  begin
    Write(f,IntToStr(n)+','+IntToStr(HuffTree[n].dn));
    if Assigned(HuffTree[n].Left) then
      Write(f,','+IntToStr(HuffTree[n].left.dn));
    if Assigned(HuffTree[n].Right) then
      Write(f,','+IntToStr(HuffTree[n].right.dn));
    WriteLn(f);
  end;
  WriteLn(f,'NewNode:');
  for n:=0 to High(NewNode) do
  begin
    Write(f,IntToStr(n)+','+IntToStr(NewNode[n].dn));
    if Assigned(NewNode[n].Left) then
      Write(f,','+IntToStr(NewNode[n].left.dn));
    if Assigned(NewNode[n].Right) then
      Write(f,','+IntToStr(NewNode[n].right.dn));
    WriteLn(f);
  end;
  WriteLn(f,'end');
  CloseFile(f); }
end; *)

procedure InitTree(hist: TBuf);
const
  NUM_FREQ = 512;

var
  SortFreq: array of integer;
  hlen,i,k,m,n: integer;
  count: Int64;

  {
  procedure SortByFrequency(var Freq: array of integer; var Tree: array of THuffNode);
  var   //bubble sort algorithm (SLOW)
    i,j,k: Integer;
    t: THuffNode;
  begin
    for i := High(Freq) downto Low(Freq) do
      for j := Low(Freq) to High(Freq) - 1 do
        if Freq[j] > Freq[j+1] then
        begin
          k := Freq[j];
          Freq[j] := Freq[j+1];
          Freq[j+1] := k;

          t := Tree[j];
          Tree[j] := Tree[j+1];
          Tree[j+1] := t;
        end;
  end; }

  procedure SortByFrequency(var Freq: array of Integer; var Tree: array of THuffNode);  //bm 30-Dec-21
  var   //bubble sort algorithm (faster but not the fastest)
    n, newn, i: Integer;
    temp: Integer;
    tempNode: THuffNode;
  begin
    n := High(Freq);
    repeat
      newn := 0;
      for i := 1 to n do
      begin
        if Freq[i - 1] > Freq[i] then
        begin
          temp := Freq[i-1];
          Freq[i-1] := Freq[i];
          Freq[i] := temp;

          tempNode := Tree[i-1];
          Tree[i-1] := Tree[i];
          Tree[i] := tempNode;

          newn := i;
        end;
      end;
      n := newn;
    until n = 0;
  end;


begin
  HuffTree := nil;  //bm 03-Jan-20
  NewNode := nil;  //bm 02-Jan-20

  SetLength(SortFreq, NUM_FREQ);
  SetLength(HuffTree, NUM_FREQ);

  hlen := Length(hist) div 4;
  if hlen > NUM_FREQ then
    exit;   // histogram cannot exceed a length of 512 elements

  // step 1: initalise huffman tree and sort frequency array
  for n := 0 to hlen -1 do   // 2044 div 4 -> 511 elements expected
  begin
    count := 0;
    for m := 0 to 3 do
      count := count + hist[n*4+m] shl (8*m);
    SortFreq[n] := count;
    HuffTree[n].dn := n+1;
    HuffTree[n].LeftIndex := -1;
    HuffTree[n].RightIndex := -1;
  end;
  SortFreq[511] := 0;
  HuffTree[511].dn := 512;

  //Step 2: sort initial nodes in huffman tree by frequency, in ascending order
  SortByFrequency(SortFreq,HuffTree);

  //Step 3: scan through nodes, eliminate records with frequencies of zero
  //       and shift records to the top
  m := 0;
  for n := 0 to NUM_FREQ-1 do
    if SortFreq[n] > 0 then
    begin
      HuffTree[m] := HuffTree[n];
      SortFreq[m] := SortFreq[n];
      m := m + 1;
    end;

  SetLength(HuffTree,m);
  SetLength(SortFreq,m);

  //step 4: reconstruct huffman tree
  i := 0;
  for n := 0 to m-2 do
  begin
    Setlength(NewNode,Length(NewNode)+1);   // create extra nodes
    k := High(NewNode);

    NewNode[k] := HuffTree[i+1];           //copy left leaf
    HuffTree[i+1].dn := -1;
    HuffTree[i+1].RightIndex := i;  // assign right leaf index
    HuffTree[i+1].LeftIndex := k;    // assign left leaf index
    i := i + 1;

    SortFreq[n+1] := SortFreq[n+1] + SortFreq[n]; //sum of frequencies
    SortFreq[n] := 0;
    SortByFrequency(SortFreq,HuffTree); // sort again
  end;
end;

        (*
procedure Decompress(inbuf,outbuf:PBuf);
var
  Node: THuffNode;
  i,k,m:integer;
  test:byte;
  root:integer;
  inbyte, outbyte: byte;

begin
  root := High(HuffTree);
  Node := HuffTree[root];  // start at root node

  inbyte := inbuf^[0];  // fetch very first byte from stream
  outbyte := inbyte;
  outbuf^[0] := outbyte;
  k := 1;

  for i := 1 to High(inbuf^) do
  begin
    inbyte := inbuf^[i];  // fetch byte from compressed stream
    test := $80;
    for m := 0 to 7 do
    begin
      if (test and inbyte) > 0 then
        Node := Node.left^   // set
      else
        Node := Node.right^; // reset

      //if Node.dn <- 1 then exit;  // safety debug

      if Node.dn >-1 then  //is this node a leaf ?
      begin
        outbyte := outbyte - byte(Node.dn+256);
        outbuf^[k] := outbyte;
        k := k + 1;
        if k >= High(outbuf^) then
          exit;
        Node := HuffTree[root];  //start at root node again
      end;

      test := test shr 1;
    end;
  end;
end;  *)

procedure Decompress(inbuf,outbuf:TBuf);
var
  Node: THuffNode;
  i,k,m:integer;
  test:byte;
  root:integer;
  inbyte, outbyte: byte;

begin
  root := High(HuffTree);
  Node := HuffTree[root];  // start at root node

  inbyte := inbuf[0];  // fetch very first byte from stream
  outbyte := inbyte;
  outbuf[0] := outbyte;
  k := 1;


  for i := 1 to High(inbuf) do
  begin
    inbyte := inbuf[i];  // fetch byte from compressed stream
    test := $80;
    for m := 0 to 7 do
    begin
      if (test and inbyte) > 0 then
        Node := NewNode[Node.LeftIndex]   // set
      else
        Node := HuffTree[Node.RightIndex]; // reset

      //if Node.dn <- 1 then exit;  // safety debug

      if Node.dn >-1 then  //is this node a leaf ?
      begin
        outbyte := outbyte - byte(Node.dn+256);
        outbuf[k] := outbyte;
        k := k + 1;
        //if k >= High(outbuf) then
        if k > High(outbuf) then  //bm 03-Jan-20
          exit;
        Node := HuffTree[root];  //start at root node again
      end;
      test := test shr 1;
    end;
  end;
end;

procedure FreeTree;
begin
  NewNode:=nil;
  HuffTree:=nil;
end;

end.
