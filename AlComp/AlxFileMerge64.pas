unit AlxFileMerge64;

interface

uses
  SysUtils, Classes, AlxCommon, Math;

Const
  Alx64 = 945310785;

type
  TAlxFileMerge64 = class(TObject)
  private
    FFileName: String; //Имя файла соединенного
    FFileCount: Int64; //Кол-во файлов в файле
    FArrCount: Int64; //Кол-во заполненых элементов в массиве
    CurrFile: TAlxSpecFileRec64;
    FItemIndex: Int64;
    FFileList: Array of TAlxSpecFileRec64;
    ArrayStep: Integer;
    procedure SetFileName(const FName: String);
    procedure SetItemIndex(ind: Int64);
  public
    Constructor Create; overload;
    Constructor Create(const FName: String); overload;
    Destructor Destroy; override;
    procedure ConvertFrom32(const FName: String);
    function NewFile(const FName: String):Boolean; overload;
    function NewFile(const FName, FSource: String):Boolean; overload;
    procedure Add(const FSource: String);
    procedure AddFromDir(DirDest: String);
    procedure Delete; overload;
    procedure Delete(FNumber: Int64); overload;
    function ExtractFile(FNumber: Int64; DirDest: String):Boolean; overload;
    function ExtractFile(DirDest: String):Boolean; overload;
    procedure ExtractAll(DirDest: String);
    property FileCount: Int64 read FFileCount;
    property Currently: TAlxSpecFileRec64 read CurrFile;
    property FileName: String read FFileName write SetFileName;
    property ItemIndex: Int64 read FItemIndex write SetItemIndex;
  end;


implementation

constructor TAlxFileMerge64.Create;
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
  ArrayStep := 64;
end;

constructor TAlxFileMerge64.Create(const FName: String);
var
  fs: TFileStream;
  m, i: Int64;
  f: Extended;
  temp: Integer;
begin
  inherited Create;
  FFileName := FName;
  CurrFile.FileNo := 0;
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;
  ArrayStep := 64;
  if FileExists(FName)
  then begin
    fs := TFileStream.Create(FName,fmOpenRead);
    fs.Read(temp,SizeOf(Integer));
    if temp <> Alx64
    then begin
      fs.Free;
      FFileName := '';
      FFileCount := 0;
      FItemIndex := -1;
      FFileList := nil;
      Raise Exception.Create('Неверный тип файла!');
    end;
    fs.Read(FFileCount,SizeOf(Int64));
    f := FFileCount;
    m := Ceil(f/ArrayStep);
    SetLength(FFileList,ArrayStep*m);
    FArrCount := ArrayStep*m;
    i := 0;
    While i <= FFileCount-1
    do begin
      fs.Read(FFileList[i].FileNo,SizeOf(Int64));
      fs.Read(FFileList[i].FileSize,SizeOf(Int64));
      FFileList[i].FileBegin := fs.Position;
      fs.Seek(FFileList[i].FileSize,soFromCurrent);
      inc(i);
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

function TAlxFileMerge64.NewFile(const FName: String):Boolean;
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

function TAlxFileMerge64.NewFile(const FName, FSource: String):Boolean;
var
  fs, fd: TFileStream;
  fn: Int64;
  temp: Integer;
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

  ForceDirectories(ExtractFileDir(FName));
  fs := TFileStream.Create(FName,fmCreate);
  inc(FFileCount);
  Fext := ExtractFileExt(FSource);
  Fnm := ExtractFileName(FSource);
  System.Delete(Fnm,Pos(Fext,Fnm),Length(Fext));
  FFileList[FFileCount-1].FileNo := StrToInt(Fnm);
  FFileList[FFileCount-1].FileSize := fd.Size;
  temp := Alx64;
  fs.Write(temp,SizeOf(Alx64));
  fs.Write(FFileCount,SizeOf(Int64));
  fs.Write(FFileList[FFileCount-1].FileNo,SizeOf(Int64));
  fs.Write(FFileList[FFileCount-1].FileSize,SizeOf(Int64));
  FFileList[FFileCount-1].FileBegin := fs.Position;
  fs.CopyFrom(fd,fd.size);
  fd.Free;
  fs.Free;

  FItemIndex := 0;
  CurrFile := FFileList[FFileCount-1];

  Result := True;
end;

procedure TAlxFileMerge64.SetFileName(const FName: String);
var
  fs: TFileStream;
  m, i: Int64;
  temp: Integer;
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
    fs.Read(temp,SizeOf(Integer));
    if temp <> Alx64
    then begin
      fs.Free;
      FFileName := '';
      FFileCount := 0;
      FItemIndex := -1;
      FFileList := nil;
      Raise Exception.Create('Неверный тип файла!');
    end;
    fs.Read(FFileCount,SizeOf(Int64));
    f := FFileCount;
    m := Ceil(f/ArrayStep);
    SetLength(FFileList,ArrayStep*m);
    FArrCount := ArrayStep*m;
    i := 0;
    While i <= FFileCount-1
    do begin
      fs.Read(FFileList[i].FileNo,SizeOf(Int64));
      fs.Read(FFileList[i].FileSize,SizeOf(Int64));
      FFileList[i].FileBegin := fs.Position;
      fs.Seek(FFileList[i].FileSize,soFromCurrent);
      inc(i);
    end;
    fs.Free;
    FItemIndex := 0;
    CurrFile := FFileList[0];
  end
  else begin
    //ForceDirectories(ExtractFileDir(FName));
    FFileCount := 0;
    FItemIndex := -1;
    SetLength(FFileList,ArrayStep);
    FArrCount := ArrayStep;
  end;
end;

procedure TAlxFileMerge64.Add(const FSource: String);
var
  fs, fd: TFileStream;
  fn: Int64;
  temp: Integer;
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
  then begin
    ForceDirectories(ExtractFileDir(FFileName));
    fs := TFileStream.Create(FFileName,fmCreate);
  end
  else fs := TFileStream.Create(FFileName,fmOpenReadWrite);

  Fext := ExtractFileExt(FSource);
  Fnm := ExtractFileName(FSource);
  System.Delete(Fnm,Pos(Fext,Fnm),Length(Fext));
  FFileList[FFileCount].FileNo := StrToInt(Fnm);
  FFileList[FFileCount].FileSize := fd.Size;

  fn := FFileCount+1;
  temp := Alx64;
  fs.Write(temp,SizeOf(Alx64));
  fs.Write(fn,SizeOf(Int64));
  If FFileCount > 0
  then fs.Seek(FFileList[FFileCount-1].FileBegin+FFileList[FFileCount-1].FileSize,soFromBeginning);
  fs.Write(FFileList[FFileCount].FileNo,SizeOf(Int64));
  fs.Write(FFileList[FFileCount].FileSize,SizeOf(Int64));
  FFileList[FFileCount].FileBegin := fs.Position;
  fs.CopyFrom(fd,fd.size);
  fd.Free;
  fs.Free;

  inc(FFileCount);
  FItemIndex := FFileCount-1;
  CurrFile := FFileList[FFileCount-1];
end;

procedure TAlxFileMerge64.SetItemIndex(ind: Int64);
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

Function TAlxFileMerge64.ExtractFile(FNumber: Int64; DirDest: String):Boolean;
var
  i: Int64;
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
    i := 0;
    While i <= FFileCount-1
    do begin
      if FFileList[i].FileNo = FNumber
      then begin
        CurrFile := FFileList[i];
        FItemIndex := i;
        Result := True;
        Break;
      end;
      inc(i);
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

  Result := True;
end;

Function TAlxFileMerge64.ExtractFile(DirDest: String):Boolean;
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

  Result := True;
end;

Destructor TAlxFileMerge64.Destroy;
begin
  if FFileList <> nil
  then FFileList := nil;
  inherited;
end;

procedure TAlxFileMerge64.ExtractAll(DirDest: String);
var
  i: Int64;
  fs, fd: TFileStream;
begin
  if FFileCount = 0
  then exit;

  if DirDest = ''
  then exit;

  if DirDest[Length(DirDest)] <> '\'
  then DirDest := DirDest + '\';

  ForceDirectories(DirDest);

  try
    fs := TFileStream.Create(FFileName,fmOpenRead);

    i := 0;
    While i <= FFileCount-1
    do begin
      try
        fd := TFileStream.Create(DirDest+IntToStr(FFileList[i].FileNo)+'.zip',fmCreate);
        fs.Seek(FFileList[i].FileBegin,soFromBeginning);
        fd.CopyFrom(fs,FFileList[i].FileSize);
        inc(i);
      finally
        fd.Free;
      end;
    end;
  finally
    fs.Free;
  end;
end;

procedure TAlxFileMerge64.AddFromDir(DirDest: String);
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

procedure TAlxFileMerge64.Delete;
var
  i, FCountTemp: Int64;
  temp: Integer;
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

  temp := Alx64;
  fd.Write(temp,SizeOf(Alx64));
  fd.Write(FCountTemp,SizeOf(Int64));

  i := 0;
  While i <= FFileCount-1
  do begin
    if i = FItemIndex
    then begin
      inc(i);
      continue;
    end;
    fs.Seek(FFileList[i].FileBegin,soFromBeginning);
    fd.Write(FFileList[i].FileNo,SizeOf(Int64));
    fd.Write(FFileList[i].FileSize,SizeOf(Int64));
    FFileList[i].FileBegin := fd.Position;
    fd.CopyFrom(fs,FFileList[i].FileSize);
    inc(i);
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
    i := FItemIndex+1;
    While i <= FFileCount-1
    do begin
      FFileList[i-1] := FFileList[i];
      inc(i);
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

procedure TAlxFileMerge64.Delete(FNumber: Int64);
var
  i: Int64;
  res: Boolean;
begin
  Res := False;
  if CurrFile.FileNo <> FNumber
  then begin
    i := 0;
    While i <= FFileCount-1
    do begin
      if FFileList[i].FileNo = FNumber
      then begin
        SetItemIndex(i);
        Res := True;
        Break;
      end;
      inc(i);
    end;
  end
  else Res := True;

  if Res
  then Delete;
end;

procedure TAlxFileMerge64.ConvertFrom32(const FName: String);
var
  Asfr32: TAlxSpecFileRec;
  FCount32, temp, i: Integer;
  FCount64, FNum64: Int64;
  Dir, FlName: String;
  D, M, Y, Ch, Mi, S, Ss: Word;
  fs, fd: TFileStream;
begin
  if not FileExists(FName)
  then exit;

  Dir := ExtractFilePath(FName);

  if Dir[Length(Dir)] <> '\'
  then Dir := Dir + '\';

  DecodeDate(now(),Y,M,D);
  DecodeTime(now(),Ch,Mi,S,Ss);
  FlName := IntToStr(Y)+IntToStr(M)+IntToStr(D)+IntToStr(Ch)+IntToStr(Mi)+IntToStr(S)+IntToStr(Ss)+'.tmp';

  fs := TFileStream.Create(FName,fmOpenRead);
  fd := TFileStream.Create(Dir+FlName,fmCreate);

  temp := Alx64;
  fs.Read(FCount32,SizeOf(Integer));
  FCount64 := FCount32;
  fd.Write(temp,SizeOf(Alx64));
  fd.Write(FCount64,SizeOf(Int64));

  for i := 0 to FCount32-1
  do begin
    fs.Read(Asfr32.FileNo,SizeOf(Integer));
    fs.Read(Asfr32.FileSize,SizeOf(Int64));
    FNum64 := Asfr32.FileNo;
    fd.Write(FNum64,SizeOf(Int64));
    fd.Write(Asfr32.FileSize,SizeOf(Int64));
    fd.CopyFrom(fs,Asfr32.FileSize);
  end;
  fs.Free;
  fd.Free;

  DeleteFile(FName);
  RenameFile(Dir+FlName,FName);
  SetFileName(FName);
end;

end.
 