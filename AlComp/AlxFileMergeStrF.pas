unit AlxFileMergeStrF;

interface

uses
  SysUtils, Classes, AlxCommon, Math;

Const
  AlxStr = $53584C41;

type
  TAlxFileMergeStr = class(TObject)
  private
    FFileName: String;                      //Имя файла соединенного
    FFileCount: Integer;                    //Кол-во файлов в файле
    FArrCount: Integer;                     //Кол-во заполненых элементов в массиве
    CurrFile: TAlxSpecFileRecStr;           //Структура текущего файла
    FItemIndex: Integer;                    //Текущий индекс
    FIsAutoDelEmpty: Boolean;                //Флаг автоматического удаления пустого файла
    FFileList: Array of TAlxSpecFileRecStr; //Массив структур описывающих вложенные файлы
    ArrayStep: Integer;                     //Шаг наращивания массива
    procedure SetFileName(const FName: String);
    procedure SetItemIndex(ind: Integer);
    procedure ReadFlie(var fs: TFileStream; Index: Integer);    //Чтение информации о файле из объединенного файла
    procedure WriteFlie(var fs: TFileStream; var fd: TFileStream);
  public
    Constructor Create; overload;
    Constructor Create(IsAutoDel: Boolean); overload;
    Constructor Create(const FName: String; IsAutoDel: Boolean = False); overload;
    Destructor Destroy; override;
    function NewFile(const FName: String):Boolean; overload;          //Создание нового файла
    function NewFile(const FName, FSource: String):Boolean; overload; //Создание нового файла + включить файл
    procedure Add(const FSource: String; DirName: String = '');       //Добавить файл в файл
    procedure AddFromDir(DirDest: String; DirName: String = '');      //Добавить все файлы из дирректории
    procedure Delete; overload;                 //Удалить текущий файл из файла
    procedure Delete(FName: String); overload;  //Удалить файл (по имени) из файла
    function ExtractFile(FName: String; DirDest: String):Boolean; overload;
    function ExtractFile(DirDest: String):Boolean; overload;
    procedure ExtractAll(DirDest: String);
    property FileCount: Integer read FFileCount;
    property Currently: TAlxSpecFileRecStr read CurrFile;
    property FileName: String read FFileName write SetFileName;
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    property IsAutoDelEmpty: Boolean read FIsAutoDelEmpty write FIsAutoDelEmpty;
  end;


implementation

uses AlxFileMergeStr;

constructor TAlxFileMergeStr.Create;
begin
  inherited Create;
  FFileCount := 0;
  FArrCount := 0;
  FFileName := '';
  FFileList := nil;
  FItemIndex := -1;
  FIsAutoDelEmpty := False;
  CurrFile.FileName := '';
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;
  ArrayStep := 64;
end;

constructor TAlxFileMergeStr.Create(IsAutoDel: Boolean);
begin
  inherited Create;
  FFileCount := 0;
  FArrCount := 0;
  FFileName := '';
  FFileList := nil;
  FItemIndex := -1;
  FIsAutoDelEmpty := IsAutoDel;
  CurrFile.FileName := '';
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;
  ArrayStep := 64;
end;

constructor TAlxFileMergeStr.Create(const FName: String; IsAutoDel: Boolean = False);
var
  fs: TFileStream;
  m, i: Integer;
  f: Extended;
  temp: Integer; //ln - длина строки;
  ln: Integer;
  pc: PChar;
begin
  inherited Create;
  FFileName := FName;
  CurrFile.FileName := '';
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;
  FIsAutoDelEmpty := IsAutoDel;
  ArrayStep := 64;
  pc := nil;

  if FileExists(FName)
  then begin
    fs := TFileStream.Create(FName,fmOpenRead);

    if fs.Size = 0
    then begin
      fs.Free;
      if FIsAutoDelEmpty
      then DeleteFile(FName);  //Файл можно не удалять (строку можно закоментировать)
      FFileCount := 0;
      FItemIndex := -1;
      SetLength(FFileList,ArrayStep); //Выделяем массив для дальнейшей работы
      FArrCount := ArrayStep;
      exit;
    end;

    fs.Read(temp,SizeOf(Integer));
    if temp <> AlxStr
    then begin
      fs.Free;
      FFileName := '';
      FFileCount := 0;
      FItemIndex := -1;
      FFileList := nil;
      Raise Exception.Create('Неверный тип файла!');
    end;

    fs.Read(FFileCount,SizeOf(Integer)); //читаем кол-во файлов в файле
    f := FFileCount;
    m := Ceil(f/ArrayStep);
    SetLength(FFileList,ArrayStep*m); //выделяем массив
    FArrCount := ArrayStep*m;
    i := 0;
    While i <= FFileCount-1
    do begin
      ReadFlie(fs,i);

      {ln := fs.Read(ln,SizeOf(Integer)); //читаем длину строки имени файла
      ReallocMem(pc,ln+1);
      fs.Read(pc^,ln);
      (pc+ln)^ := #0;
      FFileList[i].FileName := StrPas(pc);
      fs.Read(FFileList[i].FileSize,SizeOf(Int64)); //читаем размер файла
      FFileList[i].FileBegin := fs.Position;
      fs.Seek(FFileList[i].FileSize,soFromCurrent); //переходим к следующему файлу
      ReallocMem(pc,0);}

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

procedure TAlxFileMergeStr.ReadFlie(var fs: TFileStream; Index: Integer);
var
  ln: Integer; //ln - длина строки;
  pc: PChar;
begin
  pc := nil;
  fs.Read(ln,SizeOf(Integer)); //читаем длину строки имени файла
  ReallocMem(pc,ln+1);
  fs.Read(pc^,ln);
  (pc+ln)^ := #0;
  FFileList[Index].FileName := StrPas(pc);
  fs.Read(FFileList[Index].FileSize,SizeOf(Int64)); //читаем размер файла
  FFileList[Index].FileBegin := fs.Position;
  fs.Seek(FFileList[Index].FileSize,soFromCurrent); //переходим к следующему файлу
  ReallocMem(pc,0);
end;

procedure TAlxFileMergeStr.WriteFlie(var fs: TFileStream; var fd: TFileStream);
var
  ln: Integer;
begin
  ln := Length(FFileList[FFileCount-1].FileName);
  fs.Write(ln,SizeOf(ln));  //записываем длину строки имени файла

  fs.Write(PChar(FFileList[FFileCount-1].FileName)^,ln); //записываем имя файла
  fs.Write(FFileList[FFileCount-1].FileSize,SizeOf(Int64)); //записываем размер файла
  FFileList[FFileCount-1].FileBegin := fs.Position; //заполняем массив записей о файле (позиция начала файла)
  fs.CopyFrom(fd,fd.size); //далее копируем файл
end;


function TAlxFileMergeStr.NewFile(const FName: String):Boolean;
begin
  Result := False;

  //---Надо подумать
  if FileExists(FName)
  then begin
    //DeleteFile(FName);
    {fs.Create(FName,fmCreate);
    fs.Free;}

    FFileName := '';
    CurrFile.FileName := '';
    CurrFile.FileBegin := 0;
    CurrFile.FileSize := 0;

    FFileList := nil;
    FFileCount := 0;
    FItemIndex := -1;
    SetLength(FFileList,ArrayStep);
    FArrCount := ArrayStep;

    exit;
  end;

  FFileName := FName;
  CurrFile.FileName := '';
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;

  FFileList := nil;
  FFileCount := 0;
  FItemIndex := -1;
  SetLength(FFileList,ArrayStep);
  FArrCount := ArrayStep;

  Result := True;
end;

function TAlxFileMergeStr.NewFile(const FName, FSource: String):Boolean;
var
  fs, fd: TFileStream;
  fn: Int64;
  temp, ln: Integer;
  Fext, Fnm: String;
begin
  Result := False;

  //---Надо подумать
  if FileExists(FName)
  then begin
    //DeleteFile(FName);
    {fs.Create(FName,fmCreate);
    fs.Free;}

    FFileName := '';
    CurrFile.FileName := '';
    CurrFile.FileBegin := 0;
    CurrFile.FileSize := 0;

    FFileList := nil;
    FFileCount := 0;
    FItemIndex := -1;
    SetLength(FFileList,ArrayStep);
    FArrCount := ArrayStep;

    exit;
  end;

  FFileName := FName;
  CurrFile.FileName := '';
  CurrFile.FileBegin := 0;
  CurrFile.FileSize := 0;

  FFileList := nil;
  FFileCount := 0;
  FItemIndex := -1;
  SetLength(FFileList,ArrayStep);
  FArrCount := ArrayStep;

  try
    fd := TFileStream.Create(FSource,fmOpenRead);
  except
    fd.Free;
    Raise Exception.Create('Невозможно открыть файл источник!');
    exit;
  end;

  ForceDirectories(ExtractFileDir(FName));
  try
    fs := TFileStream.Create(FName,fmCreate);
  except
    fd.Free;
    fs.Free;
    Raise Exception.Create('Невозможно создать файл назначения!');
    exit;
  end;

  inc(FFileCount);
  FFileList[FFileCount-1].FileName := ExtractFileName(FSource);
  FFileList[FFileCount-1].FileSize := fd.Size; //заполняем массив записей о файле (имя + размер)

  temp := AlxStr;
  fs.Write(temp,SizeOf(AlxStr));
  fs.Write(FFileCount,SizeOf(Integer)); //записываем заголовок (префикс + кол-во файлов в файле)

  WriteFlie(fs,fd);
  fd.Free;
  fs.Free;

  FItemIndex := 0;
  CurrFile := FFileList[FFileCount-1];

  Result := True;
end;

procedure TAlxFileMergeStr.SetFileName(const FName: String);
var
  fs: TFileStream;
  m, i, ln: Integer;
  pc: PChar;
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
    if temp <> AlxStr
    then begin
      fs.Free;
      FFileName := '';
      FFileCount := 0;
      FItemIndex := -1;
      FFileList := nil;
      Raise Exception.Create('Неверный тип файла!');
    end;
    fs.Read(FFileCount,SizeOf(Integer));
    f := FFileCount;
    m := Ceil(f/ArrayStep);
    SetLength(FFileList,ArrayStep*m);
    FArrCount := ArrayStep*m;

    i := 0;
    While i <= FFileCount-1
    do begin
      ReadFlie(fs,i);
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

procedure TAlxFileMergeStr.Add(const FSource: String; DirName: String = '');
var
  fs, fd: TFileStream;
  fn, ln: Integer;
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

  if (DirName <> '') AND (DirName[Length(DirName)] <> '\')
  then DirName := DirName + '\';

  FFileList[FFileCount].FileName := DirName + ExtractFileName(FSource);
  FFileList[FFileCount].FileSize := fd.Size;

  fn := FFileCount+1;
  temp := AlxStr;
  fs.Write(temp,SizeOf(AlxStr));
  fs.Write(fn,SizeOf(Integer));

  If FFileCount > 0
  then fs.Seek(FFileList[FFileCount-1].FileBegin+FFileList[FFileCount-1].FileSize,soFromBeginning);

  inc(FFileCount);
  WriteFlie(fs,fd);

  fd.Free;
  fs.Free;


  FItemIndex := FFileCount-1;
  CurrFile := FFileList[FFileCount-1];
end;

procedure TAlxFileMergeStr.SetItemIndex(ind: Integer);
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

Function TAlxFileMergeStr.ExtractFile(FName: String; DirDest: String):Boolean;
var
  i: Integer;
  fs, fd: TFileStream;
begin
  if DirDest = ''
  then begin
    Result := False;
    exit;
  end;

  if CurrFile.FileName <> FName
  then begin
    Result := False;
    i := 0;
    While i <= FFileCount-1
    do begin
      if FFileList[i].FileName = FName
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
      ForceDirectories(ExtractFileDir(DirDest+CurrFile.FileName));
      fs := TFileStream.Create(FFileName,fmOpenRead);
      fd := TFileStream.Create(DirDest+CurrFile.FileName,fmCreate);
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

Function TAlxFileMergeStr.ExtractFile(DirDest: String):Boolean;
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
      ForceDirectories(ExtractFileDir(DirDest+CurrFile.FileName));
      fs := TFileStream.Create(FFileName,fmOpenRead);
      fd := TFileStream.Create(DirDest+CurrFile.FileName,fmCreate);
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

Destructor TAlxFileMergeStr.Destroy;
begin
  if FFileList <> nil
  then FFileList := nil;
  inherited;
end;

procedure TAlxFileMergeStr.ExtractAll(DirDest: String);
var
  i: Integer;
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
        ForceDirectories(ExtractFileDir(DirDest+FFileList[i].FileName));
        fd := TFileStream.Create(DirDest+FFileList[i].FileName,fmCreate);
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

procedure TAlxFileMergeStr.AddFromDir(DirDest: String; DirName: String = '');
var
  sr: TSearchRec;
begin
  if DirDest = ''
  then exit;

  if DirDest[Length(DirDest)] <> '\'
  then DirDest := DirDest + '\';

  if (DirName <> '') AND (DirName[Length(DirName)] <> '\') 
  then DirName := DirName + '\';

  if FindFirst(DirDest+'*.*', faAnyFile, sr) = 0
  then begin
    repeat
      if (sr.Attr AND faDirectory) = 0
      then Add(DirDest+sr.Name, DirName);
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
end;

procedure TAlxFileMergeStr.Delete;
var
  i, FCountTemp, ln: Integer;
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
    if FIsAutoDelEmpty
    then DeleteFile(FFileName)
    else begin
      fs := TFileStream.Create(FFileName,fmCreate);
      fs.Free;
    end;
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

  temp := AlxStr;
  fd.Write(temp,SizeOf(AlxStr));
  fd.Write(FCountTemp,SizeOf(Integer));

  i := 0;
  While i <= FFileCount-1
  do begin
    if i = FItemIndex
    then begin
      inc(i);
      continue;
    end;
    fs.Seek(FFileList[i].FileBegin,soFromBeginning);

    WriteFlie(fs,fd);

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

procedure TAlxFileMergeStr.Delete(FName: String);
var
  i: Integer;
  res: Boolean;
begin
  Res := False;
  if CurrFile.FileName <> FName
  then begin
    i := 0;
    While i <= FFileCount-1
    do begin
      if FFileList[i].FileName = FName
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

end.
 