unit AlxFileMerge;

interface

uses
  SysUtils, Classes, AlxCommon, Math;

type
  TAlxFileMerge = class(TObject)
  private
    FFileName: String; //Имя файла соединенного
    FFileCount: Integer; //Кол-во файлов в файле
    FArrCount: Integer; //Кол-во заполненых элементов в массиве
    CurrFile: TAlxSpecFileRec;
    FItemIndex: Integer;
    FFileList: Array of TAlxSpecFileRec;
    ArrayStep: Integer;
    procedure SetFileName(const FName: String);
    procedure SetItemIndex(ind: Integer);
  public
    Constructor Create; overload;
    Constructor Create(const FName: String); overload;
    Destructor Destroy; override;
    function NewFile(const FName: String):Boolean; overload;
    function NewFile(const FName, FSource: String):Boolean; overload;
    procedure Add(const FSource: String);
    procedure AddFromDir(DirDest: String);
    procedure Delete; overload;
    procedure Delete(FNumber: Integer); overload;
    function ExtractFile(FNumber: Integer; DirDest: String):Boolean; overload;
    function ExtractFile(DirDest: String):Boolean; overload;
    procedure ExtractAll(DirDest: String);
    property FileCount: Integer read FFileCount;
    property Currently: TAlxSpecFileRec read CurrFile;
    property FileName: String read FFileName write SetFileName;
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
  end;

implementation

constructor TAlxFileMerge.Create;
begin
  inherited Create;
  FFileCount := 0;
  FArrCount := 0;
  FFileName := '';
  FFileList := nil;
  FItemIndex := -1;
  CurrFile.FileNo := 0;
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;
  ArrayStep := 32;
end;

constructor TAlxFileMerge.Create(const FName: String);
var
  fs: TFileStream;
  m, i: Integer;
  f: Extended;
begin
  inherited Create;
  FFileName := FName;
  CurrFile.FileNo := 0;
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;
  ArrayStep := 32;
  if FileExists(FName)
  then begin
    fs := TFileStream.Create(FName,fmOpenRead);
    fs.Read(FFileCount,4);
    f := FFileCount;
    m := Ceil(f/ArrayStep);
    SetLength(FFileList,ArrayStep*m);
    FArrCount := ArrayStep*m;
    for i := 0 to FFileCount-1
    do begin
      fs.Read(FFileList[i].FileNo,4);
      fs.Read(FFileList[i].FileSize,8);
      FFileList[i].FileBegin := fs.Position;
      fs.Seek(FFileList[i].FileSize,soFromCurrent);
    end;
    fs.Free;
    FItemIndex := 0;
    CurrFile := FFileList[0];
  end
  else begin
    FFileCount := 0;
    FItemIndex := -1;
    SetLength(FFileList,ArrayStep);
    FArrCount := ArrayStep;
  end;
end;

function TAlxFileMerge.NewFile(const FName: String):Boolean;
var
  fs: TFileStream;
begin
  Result := False;
  FFileName := FName;
  CurrFile.FileNo := 0;
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;

  //---Надо подумать
  if FileExists(FName)
  then begin
    DeleteFile(FName);
    {fs.Create(FName,fmCreate);
    fs.Free;}
  end;

  FFileList := nil;
  FFileCount := 0;
  FItemIndex := -1;
  SetLength(FFileList,ArrayStep);
  FArrCount := ArrayStep;

  Result := True;
end;

function TAlxFileMerge.NewFile(const FName, FSource: String):Boolean;
var
  fs, fd: TFileStream;
  fn: Integer;
  Fext, Fnm: String;
begin
  Result := False;
  FFileName := FName;
  CurrFile.FileNo := 0;
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;

  //---Надо подумать

  FFileList := nil;
  FFileCount := 0;
  FItemIndex := -1;
  SetLength(FFileList,ArrayStep);
  FArrCount := ArrayStep;

  try
    fd := TFileStream.Create(FSource,fmOpenRead);
  except
    fd.Free;
    exit;
  end;

  fs := TFileStream.Create(FName,fmCreate);
  inc(FFileCount);
  Fext := ExtractFileExt(FSource);
  Fnm := ExtractFileName(FSource);
  System.Delete(Fnm,Pos(Fext,Fnm),Length(Fext));
  FFileList[FFileCount-1].FileNo := StrToInt(Fnm);
  FFileList[FFileCount-1].FileSize := fd.Size;
  fs.Write(FFileCount,4);
  fs.Write(FFileList[FFileCount-1].FileNo,4);
  fs.Write(FFileList[FFileCount-1].FileSize,8);
  FFileList[FFileCount-1].FileBegin := fs.Position;
  fs.CopyFrom(fd,fd.size);
  fd.Free;
  fs.Free;

  FItemIndex := 0;
  CurrFile := FFileList[FFileCount-1];

  Result := True;
end;

procedure TAlxFileMerge.SetFileName(const FName: String);
var
  fs: TFileStream;
  m, i: Integer;
  f: Extended;
begin
  if FFileName = FName
  then exit;
  
  FFileName := FName;
  CurrFile.FileNo := 0;
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;
  FFileList := nil;
  if FileExists(FName)
  then begin
    fs := TFileStream.Create(FName,fmOpenRead);
    fs.Read(FFileCount,4);
    f := FFileCount;
    m := Ceil(f/ArrayStep);
    SetLength(FFileList,ArrayStep*m);
    FArrCount := ArrayStep*m;
    for i := 0 to FFileCount-1
    do begin
      fs.Read(FFileList[i].FileNo,4);
      fs.Read(FFileList[i].FileSize,8);
      FFileList[i].FileBegin := fs.Position;
      fs.Seek(FFileList[i].FileSize,soFromCurrent);
    end;
    fs.Free;
    FItemIndex := 0;
    CurrFile := FFileList[0];
  end
  else begin
    FFileCount := 0;
    FItemIndex := -1;
    SetLength(FFileList,ArrayStep);
    FArrCount := ArrayStep;
  end;
end;

procedure TAlxFileMerge.Add(const FSource: String);
var
  fs, fd: TFileStream;
  fn: Integer;
  Fext, Fnm: String;
begin
  if FFileName = ''
  then exit;

  if FFileCount = FArrCount
  then begin
    Inc(FArrCount,ArrayStep);
    SetLength(FFileList,FArrCount);
  end;

  try
    fd := TFileStream.Create(FSource,fmOpenRead);
  except
    fd.Free;
    exit;
  end;

  if FFileCount = 0
  then fs := TFileStream.Create(FFileName,fmCreate)
  else fs := TFileStream.Create(FFileName,fmOpenReadWrite);

  Fext := ExtractFileExt(FSource);
  Fnm := ExtractFileName(FSource);
  System.Delete(Fnm,Pos(Fext,Fnm),Length(Fext));
  FFileList[FFileCount].FileNo := StrToInt(Fnm);
  FFileList[FFileCount].FileSize := fd.Size;

  fn := FFileCount+1;
  fs.Write(fn,4);
  If FFileCount > 0
  then fs.Seek(FFileList[FFileCount-1].FileBegin+FFileList[FFileCount-1].FileSize,soFromBeginning);
  fs.Write(FFileList[FFileCount].FileNo,4);
  fs.Write(FFileList[FFileCount].FileSize,8);
  FFileList[FFileCount].FileBegin := fs.Position;
  fs.CopyFrom(fd,fd.size);
  fd.Free;
  fs.Free;

  inc(FFileCount);
  FItemIndex := FFileCount-1;
  CurrFile := FFileList[FFileCount-1];
end;

procedure TAlxFileMerge.SetItemIndex(ind: Integer);
begin
  If ind = FItemIndex
  then exit;

  if ind > FFileCount-1
  then FItemIndex := FFileCount-1
  else FItemIndex := ind;

  If FItemIndex < 0
  then exit
  else CurrFile := FFileList[FItemIndex];
end;

Function TAlxFileMerge.ExtractFile(FNumber: Integer; DirDest: String):Boolean;
var
  i: Integer;
  fs, fd: TFileStream;
begin
  if DirDest = ''
  then begin
    Result := False;
    exit;
  end;

  if CurrFile.FileNo <> FNumber
  then begin
    Result := False;
    For i := 0 to FFileCount-1
    do if FFileList[i].FileNo = FNumber
      then begin
        CurrFile := FFileList[i];
        FItemIndex := i;
        Result := True;
        Break;
      end;
  end
  else Result := True;

  if Result = False
  then Exit;

  if DirDest[Length(DirDest)] <> '\'
  then DirDest := DirDest + '\';

  ForceDirectories(DirDest);

  try
    try
      fs := TFileStream.Create(FFileName,fmOpenRead);
      fd := TFileStream.Create(DirDest+IntToStr(CurrFile.FileNo)+'.zip',fmCreate);
      fs.Seek(CurrFile.FileBegin,soFromBeginning);
      fd.CopyFrom(fs,CurrFile.FileSize);
    finally
      fd.Free;
      fs.Free;
    end;
  except
    Result := False;
  end;
end;

Function TAlxFileMerge.ExtractFile(DirDest: String):Boolean;
var
  fs, fd: TFileStream;
begin
  if DirDest = ''
  then begin
    Result := False;
    exit;
  end;

  if DirDest[Length(DirDest)] <> '\'
  then DirDest := DirDest + '\';

  ForceDirectories(DirDest);

  try
    try
      fs := TFileStream.Create(FFileName,fmOpenRead);
      fd := TFileStream.Create(DirDest+IntToStr(CurrFile.FileNo)+'.zip',fmCreate);
      fs.Seek(CurrFile.FileBegin,soFromBeginning);
      fd.CopyFrom(fs,CurrFile.FileSize);
    finally
      fd.Free;
      fs.Free;
    end;
  except
    Result := False;
  end;
end;

Destructor TAlxFileMerge.Destroy;
begin
  if FFileList <> nil
  then FFileList := nil;
  inherited;
end;

procedure TAlxFileMerge.ExtractAll(DirDest: String);
var
  i: Integer;
  fs, fd: TFileStream;
begin
  if DirDest = ''
  then exit;

  if DirDest[Length(DirDest)] <> '\'
  then DirDest := DirDest + '\';

  ForceDirectories(DirDest);

  try
    fs := TFileStream.Create(FFileName,fmOpenRead);

    For i := 0 to FFileCount-1
    do begin
      try
        fd := TFileStream.Create(DirDest+IntToStr(FFileList[i].FileNo)+'.zip',fmCreate);
        fs.Seek(FFileList[i].FileBegin,soFromBeginning);
        fd.CopyFrom(fs,FFileList[i].FileSize);
      finally
        fd.Free;
     end;
    end;
  finally
    fs.Free;
  end;
end;

procedure TAlxFileMerge.AddFromDir(DirDest: String);
var
  sr: TSearchRec;
begin
  if DirDest = ''
  then exit;

  if DirDest[Length(DirDest)] <> '\'
  then DirDest := DirDest + '\';

  if FindFirst(DirDest+'*.zip', faAnyFile, sr) = 0
  then begin
    repeat
      Add(DirDest+sr.Name);
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
end;

procedure TAlxFileMerge.Delete;
var
  i, FCountTemp: Integer;
  Dir, FlName: String;
  D, M, Y, Ch, Mi, S, Ss: Word;
  fs, fd: TFileStream;
begin
  if FFileCount = 0
  then exit;

  FCountTemp := FFileCount-1;

  if FCountTemp = 0
  then begin
    DeleteFile(FFileName);
    CurrFile.FileNo := 0;
    CurrFile.FileBegin := 0;
    CurrFile.FileSize := 0;
    FFileList := nil;
    FFileCount := 0;
    FItemIndex := -1;
    SetLength(FFileList,ArrayStep);
    FArrCount := ArrayStep;
  end;

  Dir := ExtractFilePath(FFileName);

  if Dir[Length(Dir)] <> '\'
  then Dir := Dir + '\';

  DecodeDate(now(),Y,M,D);
  DecodeTime(now(),Ch,Mi,S,Ss);
  FlName := IntToStr(Y)+IntToStr(M)+IntToStr(D)+IntToStr(Ch)+IntToStr(Mi)+IntToStr(S)+IntToStr(Ss)+'.tmp';

  fs := TFileStream.Create(FFileName,fmOpenRead);
  fd := TFileStream.Create(Dir+FlName,fmCreate);
  fd.Write(FCountTemp,4);

  for i:= 0 to FFileCount-1
  do begin
    if i = FItemIndex
    then continue;
    fs.Seek(FFileList[i].FileBegin,soFromBeginning);
    fd.Write(FFileList[i].FileNo,4);
    fd.Write(FFileList[i].FileSize,8);
    FFileList[i].FileBegin := fd.Position;
    fd.CopyFrom(fs,FFileList[i].FileSize);
  end;
  fs.Free;
  fd.Free;

  DeleteFile(FFileName);
  RenameFile(Dir+FlName,FFileName);

  if FItemIndex = FFileCount-1
  then begin
    Dec(FFileCount);
    if (FArrCount-FFileCount) >= ArrayStep
    then begin
      Dec(FArrCount,ArrayStep);
      SetLength(FFileList,FArrCount);
    end;
  end
  else begin
    for i := FItemIndex+1 to FFileCount-1
    do begin
      FFileList[i-1] := FFileList[i];
    end;
    Dec(FFileCount);
    if (FArrCount-FFileCount) >= ArrayStep
    then begin
      Dec(FArrCount,ArrayStep);
      SetLength(FFileList,FArrCount);
    end;
  end;

  FItemIndex := 0;
  CurrFile := FFileList[FItemIndex];
end;

procedure TAlxFileMerge.Delete(FNumber: Integer);
var
  i: Integer;
  res: Boolean;
begin
  Res := False;
  if CurrFile.FileNo <> FNumber
  then begin
    For i := 0 to FFileCount-1
    do if FFileList[i].FileNo = FNumber
      then begin
        SetItemIndex(i);
        Res := True;
        Break;
      end;
  end
  else Res := True;

  if Res
  then Delete;
end;

end.
