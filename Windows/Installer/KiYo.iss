; Build with the pinned Inno Setup compiler via ../build-installer.ps1.
#ifndef AppVersion
  #define AppVersion "0.1.0-alpha.4"
#endif
#define AppId "{E9DA26F5-7C42-4B65-9E38-6A75434CFC81}"

[Setup]
AppId={{E9DA26F5-7C42-4B65-9E38-6A75434CFC81}
AppName=KiYo
AppVersion={#AppVersion}
AppVerName=KiYo {#AppVersion}
AppPublisher=Raven Systems
AppPublisherURL=https://ravensystems.io/
AppSupportURL=https://github.com/RavenSystemsDev/KiYo/issues
AppUpdatesURL=https://github.com/RavenSystemsDev/KiYo
VersionInfoVersion=0.1.0.4
VersionInfoDescription=KiYo Setup
DefaultDirName={localappdata}\Programs\Raven Systems\KiYo
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible or arm64
ArchitecturesInstallIn64BitMode=x64compatible or arm64
MinVersion=10.0.22000
AppMutex=Local\RavenSystems.KiYo.Windows
SetupMutex=Local\RavenSystems.KiYo.Setup
CloseApplications=no
RestartApplications=no
UninstallDisplayIcon={app}\KiYo.exe
SetupIconFile=..\KiYo.Windows\Assets\KiYo.ico
WizardStyle=modern dark
WizardBackColor=#191b1d
WizardResizable=no
DisableWelcomePage=no
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableFinishedPage=no
ShowLanguageDialog=yes
LanguageDetectionMethod=uilanguage
OutputDir=..\artifacts
OutputBaseFilename=KiYo-Setup
Compression=lzma2/normal
SolidCompression=yes
DiskSpanning=no
UninstallLogMode=append

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
Source: "..\..\Resources\AppIcon.png"; Flags: dontcopy
Source: "..\..\LICENSE"; Flags: dontcopy
Source: "..\artifacts\KiYo-Windows-{#AppVersion}-win-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: not IsArm64
Source: "..\artifacts\KiYo-Windows-{#AppVersion}-win-arm64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: IsArm64

[Icons]
Name: "{userprograms}\KiYo"; Filename: "{app}\KiYo.exe"; WorkingDir: "{app}"; Comment: "KiYo — Raven Systems"
Name: "{userdesktop}\KiYo"; Filename: "{app}\KiYo.exe"; WorkingDir: "{app}"; Check: WantsDesktopShortcut

[Run]
Filename: "{app}\KiYo.exe"; WorkingDir: "{app}"; Description: "KiYo"; Flags: nowait postinstall skipifsilent; Check: ShouldLaunch

[Code]
const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  Background = $1D1B19;
  Secondary = $B8B1AC;
var
  Surface: TPanel;
  Logo, TrayLogo, ProgressTrack, CompleteBadge: TBitmapImage;
  Heading, Subtitle, Features, Percentage, TrayHint: TNewStaticText;
  OptionsButton, LicenseButton, CloseButton: TNewButton;
  StartupCheck: TNewCheckBox;
  TrayPanel: TPanel;
  DesktopShortcut, LaunchWanted: Boolean;

function T(const Ru, En: String): String;
begin
  if ActiveLanguage = 'russian' then Result := Ru else Result := En;
end;

function WantsDesktopShortcut: Boolean;
begin
  Result := DesktopShortcut;
end;

function ShouldLaunch: Boolean;
begin
  Result := LaunchWanted and not WizardSilent;
end;

function AppCommand: String;
begin
  Result := '"' + ExpandConstant('{app}\KiYo.exe') + '"';
end;

function Text(Parent: TWinControl; const Value: String; Y, H, Size: Integer): TNewStaticText;
begin
  Result := TNewStaticText.Create(WizardForm);
  Result.Parent := Parent;
  Result.AutoSize := False;
  Result.SetBounds(ScaleX(28), ScaleY(Y), ScaleX(404), ScaleY(H));
  Result.Caption := Value;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := Size;
  Result.Font.Color := clWhite;
  Result.StyleElements := [];
  Result.Color := Background;
  Result.WordWrap := True;
  Result.ShowAccelChar := False;
  Result.Alignment := taCenter;
end;

procedure PlaceButton(Button: TNewButton; Y, H: Integer);
begin
  Button.Parent := Surface;
  Button.SetBounds(ScaleX(28), ScaleY(Y), ScaleX(404), ScaleY(H));
  Button.Font.Name := 'Segoe UI';
  Button.Font.Size := 11;
end;

procedure OpenBrand(Sender: TObject);
var ErrorCode: Integer;
begin
  ShellExec('open', 'https://ravensystems.io/', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
end;

procedure ShowLicense(Sender: TObject);
var Dialog: TSetupForm; Viewer: TRichEditViewer; Done: TNewButton; Content: AnsiString;
begin
  Dialog := CreateCustomForm(620, 460, False, False);
  try
    Dialog.Caption := T('Лицензия KiYo', 'KiYo license');
    Viewer := TRichEditViewer.Create(Dialog);
    Viewer.Parent := Dialog;
    Viewer.SetBounds(ScaleX(20), ScaleY(20), ScaleX(580), ScaleY(370));
    Viewer.ReadOnly := True;
    Viewer.ScrollBars := ssVertical;
    Viewer.UseRichEdit := False;
    LoadStringFromFile(ExpandConstant('{tmp}\LICENSE'), Content);
    Viewer.Text := String(Content);
    Done := TNewButton.Create(Dialog);
    Done.Parent := Dialog;
    Done.SetBounds(ScaleX(440), ScaleY(408), ScaleX(160), ScaleY(32));
    Done.Caption := T('Готово', 'Done');
    Done.ModalResult := mrOK;
    Done.Default := True;
    Done.Cancel := True;
    Dialog.ShowModal;
  finally
    Dialog.Free;
  end;
end;

var FolderEdit: TNewEdit;
procedure BrowseFolder(Sender: TObject);
var Directory: String;
begin
  Directory := FolderEdit.Text;
  if BrowseForFolder(T('Папка KiYo', 'KiYo folder'), Directory, True) then
    FolderEdit.Text := Directory;
end;

procedure ShowOptions(Sender: TObject);
var Dialog: TSetupForm; CaptionLabel: TNewStaticText; Browse, Done, Cancel: TNewButton;
    Desktop: TNewCheckBox;
begin
  Dialog := CreateCustomForm(460, 230, False, False);
  try
    Dialog.Caption := T('Параметры установки', 'Installation options');
    CaptionLabel := Text(Dialog, T('Папка установки', 'Installation folder'), 24, 24, 10);
    CaptionLabel.Alignment := taLeftJustify;
    FolderEdit := TNewEdit.Create(Dialog);
    FolderEdit.Parent := Dialog;
    FolderEdit.SetBounds(ScaleX(28), ScaleY(54), ScaleX(314), ScaleY(28));
    FolderEdit.Text := WizardDirValue;
    { Inno Setup validates the selected directory before copying files. }
    FolderEdit.ReadOnly := True;
    Browse := TNewButton.Create(Dialog);
    Browse.Parent := Dialog;
    Browse.SetBounds(ScaleX(350), ScaleY(53), ScaleX(82), ScaleY(30));
    Browse.Caption := T('Выбрать…', 'Browse…');
    Browse.OnClick := @BrowseFolder;
    Desktop := TNewCheckBox.Create(Dialog);
    Desktop.Parent := Dialog;
    Desktop.SetBounds(ScaleX(28), ScaleY(104), ScaleX(404), ScaleY(28));
    Desktop.Caption := T('Ярлык на рабочем столе', 'Create a desktop shortcut');
    Desktop.Checked := DesktopShortcut;
    Cancel := TNewButton.Create(Dialog);
    Cancel.Parent := Dialog;
    Cancel.SetBounds(ScaleX(170), ScaleY(172), ScaleX(122), ScaleY(34));
    Cancel.Caption := T('Отмена', 'Cancel');
    Cancel.ModalResult := mrCancel;
    Cancel.Cancel := True;
    Done := TNewButton.Create(Dialog);
    Done.Parent := Dialog;
    Done.SetBounds(ScaleX(302), ScaleY(172), ScaleX(130), ScaleY(34));
    Done.Caption := T('Сохранить', 'Save');
    Done.ModalResult := mrOK;
    Done.Default := True;
    if Dialog.ShowModal = mrOK then begin
      WizardForm.DirEdit.Text := FolderEdit.Text;
      DesktopShortcut := Desktop.Checked;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure CloseWithoutLaunch(Sender: TObject);
begin
  LaunchWanted := False;
  WizardForm.NextButton.OnClick(WizardForm.NextButton);
end;

procedure InitializeWizard;
var Footer, Agreement, TrayText: TNewStaticText;
begin
  ExtractTemporaryFile('AppIcon.png');
  ExtractTemporaryFile('LICENSE');
  LaunchWanted := True;
  DesktopShortcut := False;
  WizardForm.Caption := 'KiYo';
  WizardForm.ClientWidth := ScaleX(460);
  WizardForm.ClientHeight := ScaleY(600);
  WizardForm.Position := poScreenCenter;
  Surface := TPanel.Create(WizardForm);
  Surface.Parent := WizardForm;
  Surface.SetBounds(0, 0, WizardForm.ClientWidth, WizardForm.ClientHeight);
  Surface.BevelOuter := bvNone;
  Surface.Color := Background;
  Surface.StyleElements := [];
  Logo := TBitmapImage.Create(WizardForm);
  Logo.Parent := Surface;
  Logo.SetBounds(ScaleX(158), ScaleY(34), ScaleX(144), ScaleY(144));
  Logo.PngImage.LoadFromFile(ExpandConstant('{tmp}\AppIcon.png'));
  Logo.Stretch := True;
  Logo.BackColor := Background;
  CompleteBadge := TBitmapImage.Create(WizardForm);
  CompleteBadge.Parent := Surface;
  CompleteBadge.SetBounds(ScaleX(282), ScaleY(148), ScaleX(44), ScaleY(44));
  CompleteBadge.Bitmap.Width := CompleteBadge.Width;
  CompleteBadge.Bitmap.Height := CompleteBadge.Height;
  with CompleteBadge.Bitmap.Canvas do begin
    Brush.Color := Background;
    Pen.Color := Background;
    Rectangle(0, 0, CompleteBadge.Width, CompleteBadge.Height);
    Brush.Color := $7FC126;
    Pen.Color := $7FC126;
    Ellipse(1, 1, CompleteBadge.Width - 1, CompleteBadge.Height - 1);
    Pen.Color := clWhite;
    Pen.Width := ScaleX(3);
    MoveTo(ScaleX(12), ScaleY(22));
    LineTo(ScaleX(19), ScaleY(29));
    LineTo(ScaleX(32), ScaleY(15));
  end;
  Heading := Text(Surface, '', 200, 40, 20);
  Heading.Font.Style := [fsBold];
  Subtitle := Text(Surface, '', 248, 60, 11);
  Subtitle.Font.Color := Secondary;
  Features := Text(Surface, T('↔   Автосмена RU / EN', '↔   Automatic RU / EN switching') + #13#10#13#10 +
    T('Т   Исправление выделенного текста', 'T   Convert selected text') + #13#10#13#10 +
    T('≡   Ваши слова в исключениях', '≡   Your words in exceptions'), 320, 112, 11);
  Features.Alignment := taLeftJustify;
  Features.Left := ScaleX(52);
  Features.Width := ScaleX(370);
  ProgressTrack := TBitmapImage.Create(WizardForm);
  ProgressTrack.Parent := Surface;
  ProgressTrack.SetBounds(ScaleX(40), ScaleY(336), ScaleX(380), ScaleY(12));
  ProgressTrack.Bitmap.Width := ProgressTrack.Width;
  ProgressTrack.Bitmap.Height := ProgressTrack.Height;
  Percentage := Text(Surface, '0%', 362, 28, 11);
  Percentage.Font.Color := Secondary;
  WizardForm.ProgressGauge.Parent := Surface;
  WizardForm.ProgressGauge.SetBounds(ScaleX(40), ScaleY(336), ScaleX(380), ScaleY(12));
  OptionsButton := TNewButton.Create(WizardForm);
  PlaceButton(OptionsButton, 510, 30);
  OptionsButton.Caption := T('Параметры установки', 'Installation options');
  OptionsButton.OnClick := @ShowOptions;
  LicenseButton := TNewButton.Create(WizardForm);
  LicenseButton.Parent := Surface;
  LicenseButton.SetBounds(ScaleX(286), ScaleY(548), ScaleX(146), ScaleY(24));
  LicenseButton.Caption := T('Лицензия', 'License');
  LicenseButton.Font.Size := 9;
  LicenseButton.OnClick := @ShowLicense;
  Agreement := Text(Surface, T('Устанавливая, вы принимаете', 'By installing, you accept the'), 551, 22, 8);
  Agreement.Left := ScaleX(28);
  Agreement.Width := ScaleX(250);
  Agreement.Font.Color := Secondary;
  Agreement.Tag := 1;
  StartupCheck := TNewCheckBox.Create(WizardForm);
  StartupCheck.Parent := Surface;
  StartupCheck.SetBounds(ScaleX(38), ScaleY(412), ScaleX(394), ScaleY(28));
  StartupCheck.Caption := T('Запускать при входе в Windows', 'Launch when I sign in to Windows');
  StartupCheck.Font.Size := 10;
  TrayPanel := TPanel.Create(WizardForm);
  TrayPanel.Parent := Surface;
  TrayPanel.SetBounds(ScaleX(56), ScaleY(322), ScaleX(348), ScaleY(66));
  TrayPanel.BevelOuter := bvNone;
  TrayPanel.Color := $272523;
  TrayPanel.StyleElements := [];
  TrayLogo := TBitmapImage.Create(WizardForm);
  TrayLogo.Parent := TrayPanel;
  TrayLogo.SetBounds(ScaleX(92), ScaleY(10), ScaleX(46), ScaleY(46));
  TrayLogo.PngImage.Assign(Logo.PngImage);
  TrayLogo.Stretch := True;
  TrayLogo.BackColor := $272523;
  TrayText := Text(TrayPanel, #$E70D, 20, 26, 16);
  TrayText.Font.Name := 'Segoe MDL2 Assets';
  TrayText.SetBounds(ScaleX(30), ScaleY(18), ScaleX(32), ScaleY(30));
  TrayText := Text(TrayPanel, #$E701 + '   ' + #$E767, 22, 26, 15);
  TrayText.Font.Name := 'Segoe MDL2 Assets';
  TrayText.SetBounds(ScaleX(158), ScaleY(22), ScaleX(88), ScaleY(26));
  TrayText := Text(TrayPanel, '14:27', 22, 26, 11);
  TrayText.SetBounds(ScaleX(260), ScaleY(22), ScaleX(70), ScaleY(26));
  TrayHint := Text(Surface, T('Также ищите KiYo под стрелкой ⌃', 'KiYo may also be under the ⌃ arrow'), 388, 22, 9);
  TrayHint.Font.Color := Secondary;
  CloseButton := TNewButton.Create(WizardForm);
  PlaceButton(CloseButton, 510, 32);
  CloseButton.Caption := T('Закрыть', 'Close');
  CloseButton.OnClick := @CloseWithoutLaunch;
  Footer := Text(Surface, 'Raven Systems', 580, 18, 8);
  Footer.Font.Color := Secondary;
  Footer.Cursor := crHandPoint;
  Footer.OnClick := @OpenBrand;
  PlaceButton(WizardForm.NextButton, 452, 48);
  WizardForm.NextButton.Font.Style := [fsBold];
  WizardForm.NextButton.StyleElements := [];
  WizardForm.NextButton.Font.Color := clBlack;
  PlaceButton(WizardForm.CancelButton, 452, 48);
end;

procedure CurPageChanged(CurPageID: Integer);
var Value: String; I: Integer; IsWelcome, IsInstalling, IsFinished: Boolean;
begin
  IsWelcome := CurPageID = wpWelcome;
  IsInstalling := CurPageID = wpInstalling;
  IsFinished := CurPageID = wpFinished;
  Surface.Visible := IsWelcome or IsInstalling or IsFinished;
  WizardForm.OuterNotebook.Visible := not Surface.Visible;
  WizardForm.Bevel.Visible := False;
  if not Surface.Visible then begin
    { Native validation/error pages retain working navigation and cancellation. }
    WizardForm.NextButton.Parent := WizardForm;
    WizardForm.CancelButton.Parent := WizardForm;
    WizardForm.NextButton.SetBounds(ScaleX(190), ScaleY(550), ScaleX(114), ScaleY(32));
    WizardForm.CancelButton.SetBounds(ScaleX(316), ScaleY(550), ScaleX(116), ScaleY(32));
    WizardForm.OuterNotebook.SetBounds(0, 0, ScaleX(460), ScaleY(530));
    Exit;
  end;
  PlaceButton(WizardForm.NextButton, 452, 48);
  PlaceButton(WizardForm.CancelButton, 452, 48);
  Surface.BringToFront;
  WizardForm.BackButton.Visible := False;
  WizardForm.NextButton.Visible := not IsInstalling;
  WizardForm.CancelButton.Visible := IsInstalling;
  CompleteBadge.Visible := IsFinished;
  Features.Visible := IsWelcome;
  OptionsButton.Visible := IsWelcome;
  LicenseButton.Visible := IsWelcome;
  for I := 0 to Surface.ControlCount - 1 do
    if Surface.Controls[I].Tag = 1 then Surface.Controls[I].Visible := IsWelcome;
  Percentage.Visible := IsInstalling;
  WizardForm.ProgressGauge.Visible := False;
  ProgressTrack.Visible := IsInstalling;
  StartupCheck.Visible := IsFinished;
  TrayPanel.Visible := IsFinished;
  TrayHint.Visible := IsFinished;
  CloseButton.Visible := IsFinished;
  if IsWelcome then begin
    Heading.Caption := T('Установить KiYo', 'Install KiYo');
    Subtitle.Caption := T('Печатайте, не отвлекаясь' + #13#10 + 'на раскладку.', 'Keep typing.' + #13#10 + 'KiYo handles the keyboard layout.');
    WizardForm.NextButton.Caption := T('Установить', 'Install');
  end else if IsInstalling then begin
    Heading.Caption := T('Устанавливаем KiYo', 'Installing KiYo');
    Subtitle.Caption := T('Это займёт немного времени', 'This will only take a moment');
  end else if IsFinished then begin
    Heading.Caption := T('KiYo готов к работе', 'KiYo is ready');
    Subtitle.Caption := T('Значок появится рядом с часами.', 'Look for KiYo beside the clock.');
    WizardForm.NextButton.Caption := T('Запустить KiYo', 'Launch KiYo');
    StartupCheck.Checked := RegQueryStringValue(HKCU, RunKey, 'KiYo', Value) and (Value = AppCommand);
  end;
end;

procedure CurInstallProgressChanged(CurProgress, MaxProgress: Integer);
var Filled, Radius: Integer;
begin
  if MaxProgress <= 0 then Exit;
  Percentage.Caption := IntToStr(Round(100.0 * CurProgress / MaxProgress)) + '%';
  Radius := ProgressTrack.Height;
  Filled := Round(1.0 * ProgressTrack.Width * CurProgress / MaxProgress);
  with ProgressTrack.Bitmap.Canvas do begin
    Brush.Color := Background;
    Pen.Color := Background;
    Rectangle(0, 0, ProgressTrack.Width, Radius);
    Brush.Color := $35322F;
    Pen.Color := $35322F;
    RoundRect(0, 0, ProgressTrack.Width, Radius, Radius, Radius);
    if Filled > 0 then begin
      Brush.Color := $7FC126;
      Pen.Color := $7FC126;
      RoundRect(0, 0, Filled, Radius, Radius, Radius);
    end;
  end;
  ProgressTrack.Repaint;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var Value: String;
begin
  Result := True;
  if (CurPageID = wpFinished) and not WizardSilent then begin
    if StartupCheck.Checked then
      Result := RegWriteStringValue(HKCU, RunKey, 'KiYo', AppCommand)
    else if RegQueryStringValue(HKCU, RunKey, 'KiYo', Value) and (Value = AppCommand) then
      Result := RegDeleteValue(HKCU, RunKey, 'KiYo');
    if not Result then MsgBox(T('Не удалось сохранить автозапуск. Попробуйте ещё раз.',
      'Could not save the launch-at-login setting. Please try again.'), mbError, MB_OK);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var Value: String;
begin
  if CurUninstallStep = usUninstall then
    if RegQueryStringValue(HKCU, RunKey, 'KiYo', Value) and (Value = AppCommand) then
      RegDeleteValue(HKCU, RunKey, 'KiYo');
  { Preferences and exceptions belong to the user; do not delete them. }
end;
