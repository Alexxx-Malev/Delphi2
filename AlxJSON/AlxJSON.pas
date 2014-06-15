unit AlxJSON;

interface

uses
  Classes, Contnrs, SysUtils;

type
  TAlxJSONElementType = (jetUnknown, jetObject, jetArray, jetValue); //тип JSON элемента
  TAlxJSON_R_State = (jsNone, jsObj, jsArr, jsStr, jsVal, jsKey, jsNStr);

type
  TNamedObjectList = class(TObjectList)
  public
    Key: String;
    Constructor Create(AOwnsObjects: Boolean); overload;
    Constructor Create(AOwnsObjects: Boolean; AKey: String); overload;
  end;

type
  TAlxJSONObject = class;

  TStackEvent = procedure(Sender: TObject; Str: String) of object;

  TAlxJSONObjTemplate = class //Класс шаблон для объект, массив или значения JSON
  private
    FObjType: TAlxJSONElementType;
    FOwner: TAlxJSONObjTemplate;
    FName: String;
  public
    Constructor Create; overload;
    Constructor Create(AName: String); overload;
    Destructor Destroy; override;
    function GetJSONText: String; virtual; abstract;

    property ObjType: TAlxJSONElementType read FObjType write FObjType;
    property Name: String read FName Write FName;
    property Owner: TAlxJSONObjTemplate read FOwner write FOwner;
  end;

  TAlxJSONValue = class(TAlxJSONObjTemplate) //Значение JSON
  private
    FObject: TAlxJSONObject;
    FValue: String;
    FIsString: Boolean;
  public
    Constructor Create; overload;
    Constructor Create(AName: String); overload;
    Destructor Destroy; override;
    function GetJSONText: String; override;
    procedure SetValue(AValue: String);
    procedure SetObject(AObject: TAlxJSONObject);
    function  GetIsVObject: Boolean;

    property Value: String read FValue write SetValue;
    property VObject: TAlxJSONObject read FObject write SetObject;
    property IsVObject: Boolean read GetIsVObject;
    property IsString: Boolean read FIsString write FIsString;
  end;

  TAlxJSONObject = class(TAlxJSONObjTemplate) //Объект или массив JSON
  private
    FObjects: TObjectList;
    FOnDoLog: TStackEvent;
  public
    Constructor Create; overload;
    Constructor Create(AName: String); overload;
    Constructor Create(AName: String; AObjType: TAlxJSONElementType); overload;
    Constructor Create(AObjType: TAlxJSONElementType); overload;
    Destructor Destroy; override;
    procedure Clear;
    function GetJSONText: String; override;
    function GetCount: Integer;
    function AddObject: TAlxJSONObject;
    function AddArray: TAlxJSONObject;
    function AddValue: TAlxJSONValue;
    procedure SetJSONText(Str: String);

    property Count: integer read GetCount;
    property OnDoLog: TStackEvent read FOnDoLog write FOnDoLog;
  end;

  TAlxJSONRecStack = record
    State: TAlxJSON_R_State;
    Obj: TAlxJSONObjTemplate;
    Val: String;
  end;

  TAlxStackJSON = class
  private
    FCount: Integer;
    FArr: array of TAlxJSONRecStack;
    FCapacity: integer;
    FIncArr: Integer; //на сколько наращивать массив;
    FOnStack: TStackEvent;
  public
    Constructor Create;
    Destructor Destroy; override;
    procedure Clear;
    function Pop: TAlxJSONRecStack;
    function GetUp: TAlxJSONRecStack;
    procedure Push(Item: TAlxJSONRecStack);

    property Count: integer read FCount;
    property IncArr: Integer read FIncArr write FIncArr;
    property OnStack: TStackEvent read FOnStack write FOnStack;
  end;

function StateToStr(State: TAlxJSON_R_State): String;

implementation

function StateToStr(State: TAlxJSON_R_State): String;
begin
  case State of
    jsNone: Result := 'jsNone';
    jsObj: Result := 'jsObj';
    jsArr: Result := 'jsArr';
    jsStr: Result := 'jsStr';
    jsVal: Result := 'jsVal';
    jsKey: Result := 'jsKey';
    jsNStr: Result := 'jsNStr';
  end;
end;

{ TAlxJSONObjTemplate }

constructor TAlxJSONObjTemplate.Create;
begin
  Inherited;

  FObjType := jetUnknown;
  FName := '';
  FOwner := nil;
end;

constructor TAlxJSONObjTemplate.Create(AName: String);
begin
  Create;
  
  FName := AName;
end;

destructor TAlxJSONObjTemplate.Destroy;
begin

  inherited;
end;


{ TAlxJSONObject }

constructor TAlxJSONObject.Create;
begin
  inherited Create;
  ObjType := jetObject;
  FObjects := TObjectList.Create(True);
end;

constructor TAlxJSONObject.Create(AName: String);
begin
  inherited Create(AName);
  ObjType := jetObject;
  FObjects := TObjectList.Create(True);
end;

constructor TAlxJSONObject.Create(AName: String; AObjType: TAlxJSONElementType);
begin
  inherited Create(AName);
  ObjType := AObjType;
  FObjects := TObjectList.Create(True);
end;

function TAlxJSONObject.AddArray: TAlxJSONObject;
begin
  Result := TAlxJSONObject.Create(jetArray);
  FObjects.Add(Result);
end;

function TAlxJSONObject.AddObject: TAlxJSONObject;
begin
  Result := TAlxJSONObject.Create(jetObject);
  FObjects.Add(Result);
end;

function TAlxJSONObject.AddValue: TAlxJSONValue;
begin
  Result := TAlxJSONValue.Create;
  FObjects.Add(Result);
end;

procedure TAlxJSONObject.Clear;
begin
  FObjects.Clear;
end;

constructor TAlxJSONObject.Create(AObjType: TAlxJSONElementType);
begin
  inherited Create;
  ObjType := AObjType;
  FObjects := TObjectList.Create(True);
end;

destructor TAlxJSONObject.Destroy;
begin
  if Assigned(FObjects)
  then FObjects.Free;

  inherited;
end;

function TAlxJSONObject.GetCount: Integer;
begin
  Result := FObjects.Count;
end;

function TAlxJSONObject.GetJSONText: String;
var
  i: integer;
begin
  if ObjType = jetObject
  then Result := '{';

  if ObjType = jetArray
  then Result := '[';

  if Assigned(FObjects)
  then begin
    for I := 0 to FObjects.Count - 1
    do begin
      //Result := Result + '[' + intToStr(i) + '] ' +  TAlxJSONObjTemplate(FObjects[i]).GetJSONText + #13#10;
      if i > 0
      then Result := Result + ',';

      if ObjType = jetObject
      then Result := Result + '"' + TAlxJSONObjTemplate(FObjects[i]).Name + '":' + TAlxJSONObjTemplate(FObjects[i]).GetJSONText;

      if ObjType = jetArray
      then Result := Result + TAlxJSONObjTemplate(FObjects[i]).GetJSONText;

    end;
  end;

  if ObjType = jetObject
  then Result := Result + '}';

  if ObjType = jetArray
  then Result := Result + ']';
end;

procedure TAlxJSONObject.SetJSONText(Str: String);
var
  SState: TAlxJSONRecStack;
  Stack: TAlxStackJSON;
  i, SPos, EPos, TPos: Integer;
  spChar: set of Char;
begin
  Stack := nil;

  str := trim(str);

  if (str = '') or (Length(str) < 2)
  then begin
    raise Exception.Create('TAlxJSONObject.SetJSONText: Empty String');
    exit;
  end;

  if (str[1] <> '[') and (str[1] <> '{')
  then begin
    raise Exception.Create('TAlxJSONObject.SetJSONText: Incorrect start symbol (' + str[1] + ')');
    exit;
  end
  else begin
    if str[1] = '['
    then if str[Length(str)] <> ']'
         then begin
           raise Exception.Create('TAlxJSONObject.SetJSONText: Incorrect start symbol = ([); end symbol = (' + str[Length(str)] + ')');
           exit;
         end
         else ObjType := jetArray;

    if str[1] = '{'
    then if str[Length(str)] <> '}'
         then begin
           raise Exception.Create('TAlxJSONObject.SetJSONText: Incorrect start symbol = ({); end symbol = (' + str[Length(str)] + ')');
           exit;
         end
         else ObjType := jetObject;
  end;

  if Str = '[]'
  then exit;

  if Str = '{}'
  then exit;
  
  i := 1;
  SPos := -1;
  EPos := 1;
  TPos := 1;

  if ObjType = jetArray
  then SState.State := jsArr
  else SState.State := jsObj;

  SState.Obj := self;

  spChar := ['[',']','{','}',':','"',','];

  try
    Stack := TAlxStackJSON.Create;
    //Stack.OnStack := OnDoLog;

    for i := 2 to Length(Str) - 1
    do begin
      //if Assigned(FOnDoLog)
      //then FOnDoLog(Self, IntTostr(i) + ': ' + str[i]);

      if (str[i] in spChar) //and (SState.State <> jsKey) and (SState.State <> jsStr)
      then begin
        if (Str[i] = '[') and (SState.State <> jsStr)
        then begin
          if SState.State <> jsKey
          then Stack.Push(SState);

          SState.Obj := TAlxJSONObject(SState.Obj).AddArray;

          if SState.State = jsKey
          then begin
            SState.Obj.Name := SState.Val;
            SState.Val := '';
          end;

          SState.State := jsArr;
        end;

        if (Str[i] = '{') and  (SState.State <> jsStr)
        then begin
          if SState.State <> jsKey
          then Stack.Push(SState);

          SState.Obj := TAlxJSONObject(SState.Obj).AddObject;

          if SState.State = jsKey
          then begin
            SState.Obj.Name := SState.Val;
            SState.Val := '';
          end;

          SState.State := jsObj;
        end;

        if (Str[i] = ']') and (SState.State <> jsStr)
        then begin
          if not(SState.State in [jsArr, jsVal])
          then begin
            raise Exception.Create('TAlxJSONObject.SetJSONText: Incorrect JSON string (' + str[i] + ') symbol no. ' + IntToStr(i));
            exit;
          end;

          if (SState.State = jsVal) and (SPos <> -1)
          then begin
            SState.Val := Copy(Str, SPos, i - sPos);

            if SState.State = jsVal
            then TAlxJSONValue(SState.Obj).Value := SState.Val;

            SPos := -1;
            SState := Stack.Pop;
          end;

          SState := Stack.Pop;
        end;

        if (Str[i] = '}') and (SState.State <> jsStr)
        then begin
          if not(SState.State in [jsObj, jsKey, jsVal])
          then begin
            raise Exception.Create('TAlxJSONObject.SetJSONText: Incorrect JSON string (' + str[i] + ') symbol no. ' + IntToStr(i));
            exit;
          end;

          if (SState.State = jsVal) and (SPos <> -1)
          then begin
            SState.Val := Copy(Str, SPos, i - sPos);

            if SState.State = jsVal
            then TAlxJSONValue(SState.Obj).Value := SState.Val;

            SPos := -1;
            SState := Stack.Pop;
          end;

          SState := Stack.Pop;
        end;

        if (Str[i] = ':') and (SState.State <> jsStr)
        then begin
          if (SState.State <> jsKey)
          then begin
            raise Exception.Create('TAlxJSONObject.SetJSONText: Incorrect JSON string (' + str[i] + ') symbol no. ' + IntToStr(i));
            exit;
          end;
        end;

        if (Str[i] = '"') and (Str[i-1] <> '\')
        then begin
          if SPos = -1 //Если это первая кавычка
          then begin
            if SState.State = jsObj
            then begin
              Stack.Push(SState);
              SState.State := jsKey;
            end
            else begin
              if SState.State in [jsArr, jsKey]
              then begin
                if SState.State = jsArr
                then Stack.Push(SState);

                SState.Obj := TAlxJSONObject(SState.Obj).AddValue;

                //FOnDoLog(self, 'SState.Val : ' + SState.Val);

                if SState.State = jsKey
                then begin
                  SState.Obj.Name := SState.Val;
                  SState.Val := '';
                end;

                SState.State := jsVal;
                TAlxJSONValue(SState.Obj).IsString := True;
              end;
            end;

            Stack.Push(SState);
            SState.State := jsStr;
            SPos := i;
          end
          else begin
            SState := Stack.Pop;
            SState.Val := Copy(Str, SPos + 1, i - sPos - 1);

            if SState.State = jsVal
            then begin
              TAlxJSONValue(SState.Obj).Value := SState.Val;
              SState := Stack.Pop;
            end;

            SPos := -1;
          end;
        end;

        if (Str[i] = ',') and (SState.State <> jsStr)
        then begin
          if (SState.State in [jsKey])
          then begin
            raise Exception.Create('TAlxJSONObject.SetJSONText: Incorrect JSON string (' + str[i] + ') symbol no. ' + IntToStr(i));
            exit;
          end;

          if (SState.State = jsVal) and (SPos <> -1)
          then begin
            SState.Val := Copy(Str, SPos, i - sPos);

            if SState.State = jsVal
            then TAlxJSONValue(SState.Obj).Value := SState.Val;

            SPos := -1;
            SState := Stack.Pop;
          end;
        end;
      end
      else begin
        if SState.State = jsStr
        then Continue;

        if (Str[i] = ' ') or (Str[i] = #13) or (Str[i] = #10)
        then begin
          if SState.State <> jsVal
          then Continue
          else begin
            SState.Val := Copy(Str, SPos, i - sPos);
            TAlxJSONValue(SState.Obj).Value := SState.Val;
            SPos := -1;
            SState := Stack.Pop;
          end;
        end
        else begin
          if SPos = -1 //Если это первая кавычка
          then begin
            if SState.State in [jsArr, jsKey]
            then begin
              if SState.State = jsArr
              then Stack.Push(SState);

              SState.Obj := TAlxJSONObject(SState.Obj).AddValue;

              if SState.State = jsKey
              then begin
                SState.Obj.Name := SState.Val;
                SState.Val := '';
              end;

              SState.State := jsVal;
              TAlxJSONValue(SState.Obj).IsString := False;
            end;

            SPos := i;
          end;
        end;
      end;
    end;

    if (SState.State = jsVal) and (SPos <> -1)
    then begin
      SState.Val := Copy(Str, SPos, i - sPos);
      TAlxJSONValue(SState.Obj).Value := SState.Val;
      SPos := -1;
      SState := Stack.Pop;
    end;
  finally
    Stack.Free;
  end;
end;

{ TNamedObjectList }

constructor TNamedObjectList.Create(AOwnsObjects: Boolean);
begin
  inherited Create(AOwnsObjects);
  Key := '';
end;

constructor TNamedObjectList.Create(AOwnsObjects: Boolean; AKey: String);
begin
  inherited Create(AOwnsObjects);
  Key := AKey;
end;

{ TAlxJSONValue }

constructor TAlxJSONValue.Create;
begin
  inherited Create;
  ObjType := jetValue;
  FObject := nil;
  FValue := '';
  FIsString := True;
end;

constructor TAlxJSONValue.Create(AName: String);
begin
  inherited Create(AName);
  ObjType := jetValue;
  FObject := nil;
  FValue := '';
  FIsString := True;
end;

destructor TAlxJSONValue.Destroy;
begin
  if Assigned(FObject)
  then FObject.Free;
  
  inherited;
end;

function TAlxJSONValue.GetIsVObject: Boolean;
begin
  Result := Assigned(FObject);
end;

function TAlxJSONValue.GetJSONText: String;
begin
  if Assigned(FObject)
  then begin
    Result := FObject.GetJSONText;
    exit;
  end;

  if FIsString
  then Result := '"' + FValue + '"'
  else Result := FValue;
end;

procedure TAlxJSONValue.SetObject(AObject: TAlxJSONObject);
begin
  if Assigned(AObject)
  then FValue := '';

  if AObject <> FObject
  then begin
    FreeAndNil(FObject);
    FObject := AObject;
  end;
end;

procedure TAlxJSONValue.SetValue(AValue: String);
begin
  if AValue <> ''
  then if Assigned(FObject)
       then FreeAndNil(FObject);
       
  FValue := AValue;
end;

{ TAlxStackJSON }

procedure TAlxStackJSON.Clear;
begin
  FCount := 0;
  FCapacity := FIncArr;
  SetLength(FArr, FCapacity);
end;

constructor TAlxStackJSON.Create;
begin
  FCount := 0;
  FCapacity := 16;
  FIncArr := 16;
  SetLength(FArr, FCapacity);
end;

destructor TAlxStackJSON.Destroy;
begin
  SetLength(FArr, 0);

  inherited;
end;

function TAlxStackJSON.GetUp: TAlxJSONRecStack;
begin
  if FCount = 0
  then raise Exception.Create('TAlxStackJSON: Stack Count = 0!');

  Result := FArr[FCount];
end;

function TAlxStackJSON.Pop: TAlxJSONRecStack;
begin
  if FCount = 0
  then raise Exception.Create('TAlxStackJSON: Stack Count = 0!');

  dec(FCount);
  Result := FArr[FCount];

  if Assigned(FOnStack)
  then FOnStack(Self, 'pop: ' + StateToStr(FArr[FCount].State));

end;

procedure TAlxStackJSON.Push(Item: TAlxJSONRecStack);
begin
  if FCount = FCapacity
  then begin
    FCapacity := FCapacity + FIncArr;
    SetLength(FArr, FCapacity);
  end;

  FArr[FCount] := Item;

  if Assigned(FOnStack)
  then FOnStack(Self, 'push: ' + StateToStr(FArr[FCount].State));

  Inc(FCount);
end;

end.
