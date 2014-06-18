unit AlxCommon;

interface

uses
  SysUtils;

type
  TDirName = type String;

  TAlxSpecFileRec = record
    FileNo: Integer;
    FileBegin: Int64;
    FileSize: Int64;
  end;

  TAlxSpecFileRec64 = record
    FileNo: Int64;
    FileBegin: Int64;
    FileSize: Int64;
  end;

  TAlxSpecFileRecStr = record
    FileName: String;
    FileNo: Int64;
    FileBegin: Int64;
    FileSize: Int64;
  end;

implementation


end.
