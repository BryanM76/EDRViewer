unit about;
{************************************************************************
 *
 *  Module:       About.pas
 *  Description:  About Box
 *
 *  Runtime Env.: Win32, Linux, macOS
 *  Author(s):    Colin La Place, Bryan Mitchell
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

uses SysUtils, Classes,
 //{$IFDEF MSWINDOWS}
 // Windows,
 //{$ENDIF}
  Graphics, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, Menus, Buttons,
  Clipbrd;

{$I VersionLabel.inc}

type
  { TAboutBox }
  TAboutBox = class(TForm)
    Bevel2: TBevel;
    CompilerLabel: TLabel;
    GDBLabel: TLabel;
    Panel: TPanel;
    Panel1: TPanel;
    Panel2: TPanel;
    AppIcon: TImage;
    Bevel1: TBevel;
    NameLabel: TLabel;
    BuildDate: TLabel;
    Version: TLabel;
    Memo: TMemo;
    AuthorLabel: TLabel;
    URLLabel2: TLabel;
    CloseBtn: TButton;
    procedure FormCreate(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  AboutBox: TAboutBox;

implementation
{$IFNDEF FPC}
  {$R *.dfm}
{$ELSE}
  {$R *.lfm}
{$ENDIF}
{-----------------------------------------------------------}
procedure TAboutBox.FormCreate(Sender: TObject);
var
 {$IFDEF MSWINDOWS}
 MS: TMemoryStatus;
 {$ENDIF}
 DT: TDateTime;
begin
  DT := FileDateToDateTime(FileAge(Application.ExeName));
  BuildDate.Caption := 'Build on: ' + FormatDateTime('mmmm d, yyyy hh:nn', DT);
     //DateTimeToStr(FileDateToDateTime(FileAge(Application.ExeName)));

  NameLabel.Caption := Application.Title;
  AppIcon.Picture.Icon := Application.Icon;
  Version.Caption := 'Version ' + VERSION_NUM;
  {$IFDEF MSWINDOWS}
  //MS.dwLength := SizeOf(TMemoryStatus);
  //GlobalMemoryStatus(MS);
  //PhysMem.Caption := 'Physical Memory: '+
  //                   FormatFloat('#,###" KB"', MS.dwTotalPhys div 1024);
  {$ENDIF}

end;


procedure TAboutBox.CloseBtnClick(Sender: TObject);
begin
  AboutBox.Close;

end;

initialization

end.

