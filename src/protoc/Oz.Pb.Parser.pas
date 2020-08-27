
// Copyright (c) 2020 Tomsk, Marat Shaimardanov
// Protocol buffer Generator for Delphi

unit Oz.Pb.Parser;

interface

uses
  System.Classes, System.SysUtils, System.Character, System.IOUtils, System.Math,
  Oz.Cocor.Utils, Oz.Cocor.Lib, Oz.Pb.Scanner, Oz.Pb.Options, Oz.Pb.Tab, Oz.Pb.Gen;

type

{$Region 'TpbParser'}

  TpbParser= class(TBaseParser)
  const
    ErrorMessages: array [1..5] of string = (
      {1} 'multiple declaration',
      {2} 'undefined ident',
      {3} 'not found this module',
      {4} 'message type not found',
      {5} 'message type expected'
      );
    _EOFSym = 0;
    _identSym = 1;
    _decimalLitSym = 2;
    _octalLitSym = 3;
    _hexLitSym = 4;
    _realSym = 5;
    _stringSym = 6;
    _badStringSym = 7;
    _charSym = 8;
  private
    procedure SemError(n: Integer);
    procedure _Pb;
    procedure _Syntax;
    procedure _Import;
    procedure _Package;
    procedure _Option;
    procedure _Message;
    procedure _Enum;
    procedure _Service;
    procedure _EmptyStatement;
    procedure _Ident(var id: string);
    procedure _Field(var typ: PType);
    procedure _Reserved;
    procedure _strLit;
    procedure _FullIdent(var id: string);
    procedure _OptionName(var s: string);
    procedure _Constant(var c: TConst);
    procedure _Rpc;
    procedure _UserType(var typ: TQualIdent);
    procedure _intLit(var n: Integer);
    procedure _floatLit(var n: Double);
    procedure _boolLit;
    procedure _FieldType(var typ: PType);
    procedure _FieldDecl(ftyp: PType; rule: TFieldRule);
    procedure _Type(var typ: PType);
    procedure _MapType(var typ: PType);
    procedure _OneOfType(var typ: PType);
    procedure _FieldNumber(var tag: Integer);
    procedure _FieldOption;
    procedure _KeyType(var ft: PType);
    procedure _OneOfField(typ: PType);
    procedure _Ranges(Reserved: TIntSet);
    procedure _FieldNames(Fields: TStringList);
    procedure _Range(var lo, hi: Integer);
    procedure _EnumField;
    procedure _EnumValueOption;
  protected
    function Starts(s, kind: Integer): Boolean; override;
    procedure Get; override;
  public
    options: TOptions;
    tab: TpbTable;
    listing: TStrings;
    gen: TGen;
    constructor Create(scanner: TBaseScanner; listing: TStrings);
    destructor Destroy; override;
    function ErrorMsg(nr: Integer): string; override;
    procedure Parse; override;
  end;

{$EndRegion}

{$Region 'TCocoPartHelper'}

  TCocoPartHelper = class helper for TCocoPart
  private
    function GetParser: TpbParser;
    function GetScanner: TpbScanner;
    function GetOptions: TOptions;
    function GetTab: TpbTable;
    function GetErrors: TErrors;
    function GetGen: TGen;
  public
    property parser: TpbParser read GetParser;
    property scanner: TpbScanner read GetScanner;
    property options: TOptions read GetOptions;
    property tab: TpbTable read GetTab;
    property errors: TErrors read GetErrors;
    property gen: TGen read GetGen;
 end;

{$EndRegion}

implementation

{$Region 'TpbParser'}

constructor TpbParser.Create(scanner: TBaseScanner; listing: TStrings);
begin
  inherited Create(scanner, listing);
  options := GetOptions;
  tab := TpbTable.Create(Self);
  gen := TGen.Create(Self);
end;

destructor TpbParser.Destroy;
begin
  tab.Free;
  inherited;
end;

procedure TpbParser.SemError(n: Integer);
begin
  SemErr(ErrorMessages[n]);
end;

procedure TpbParser.Get;
begin
  repeat
    t := la;
    la := scanner.Scan;
    if la.kind <= scanner.MaxToken then
    begin
      Inc(errDist);
      break;
    end;

    la := t;
  until False;
end;

procedure TpbParser._Pb;
begin
  tab.OpenScope;
  _Syntax;
  while StartOf(1) do
  begin
    case la.kind of
      15:
      begin
        _Import;
      end;
      18:
      begin
        _Package;
      end;
      19:
      begin
        _Option;
      end;
      9:
      begin
        _Message;
      end;
      61:
      begin
        _Enum;
      end;
      23:
      begin
        _Service;
      end;
      14:
      begin
        _EmptyStatement;
      end;
      end;
  end;
  tab.CloseScope;
end;

procedure TpbParser._Syntax;
begin
  Expect(12);
  Expect(13);
  _strLit;
  tab.Module.Syntax := TSyntaxVersion.Proto2;
  if t.val = '"proto3"' then
    tab.Module.Syntax := TSyntaxVersion.Proto3
  else if t.val <> '"proto2"' then
    SemErr('invalid syntax version');
  Expect(14);
end;

procedure TpbParser._Import;
var weak: Boolean;
begin
  weak := False;
  Expect(15);
  if (la.kind = 16) or (la.kind = 17) then
  begin
    if la.kind = 16 then
    begin
      Get;
      weak := True;
    end
    else
    begin
      Get;
    end;
  end;
  _strLit;

  Expect(14);
end;

procedure TpbParser._Package;
var
  id: string;
  obj: PObj;
begin
  Expect(18);
  _FullIdent(id);
  Tab.NewObj(obj, id, TMode.mPackage);
  Expect(14);
end;

procedure TpbParser._Option;
var
  id: string;
  Cv: TConst;
begin
  Expect(19);
  _OptionName(id);
  Expect(13);
  _Constant(Cv);
  tab.AddOption(id, Cv);
  Expect(14);
end;

procedure TpbParser._Message;
var
  id: string;
  obj: PObj;
  typ: PType;
begin
  Expect(9);
  _Ident(id);
  tab.NewObj(obj, id, TMode.mType);
  tab.OpenScope;
  New(typ); typ.form := TTypeMode.tmMessage;
  obj.typ := typ;
  Expect(10);
  while StartOf(2) do
  begin
    case la.kind of
      19:
      begin
        _Option;
      end;
      1, 22, 33, 34, 35, 39, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
      begin
        _Field(typ);
      end;
      9:
      begin
        _Message;
      end;
      61:
      begin
        _Enum;
      end;
      58:
      begin
        _Reserved;
      end;
      14:
      begin
        _EmptyStatement;
      end;
      end;
  end;
  Expect(11);
  tab.CloseScope;
end;

procedure TpbParser._Enum;
var
  id: string;
  obj: PObj;
  typ: PType;
begin
  Expect(61);
  _Ident(id);
  tab.NewObj(obj, id, TMode.mType);
  tab.OpenScope;
  New(typ); typ.form := TTypeMode.tmEnum;
  obj.typ := typ;
  Expect(10);
  while (la.kind = 1) or (la.kind = 14) or (la.kind = 19) do
  begin
    if la.kind = 19 then
    begin
      _Option;
    end
    else if la.kind = 1 then
    begin
      _EnumField;
    end
    else
    begin
      _EmptyStatement;
    end;
  end;
  Expect(11);
  tab.CloseScope;
end;

procedure TpbParser._Service;
var
   id: string;
   service: PObj;
begin
  Expect(23);
  _Ident(id);
  tab.NewObj(service, id, TMode.mService);
  tab.OpenScope;
  Expect(10);
  while (la.kind = 14) or (la.kind = 19) or (la.kind = 24) do
  begin
    if la.kind = 19 then
    begin
      _Option;
    end
    else if la.kind = 24 then
    begin
      _Rpc;
    end
    else
    begin
      _EmptyStatement;
    end;
  end;
  Expect(11);
  tab.CloseScope;
end;

procedure TpbParser._EmptyStatement;
begin
  Expect(14);
end;

procedure TpbParser._Ident(var id: string);
begin
  Expect(1);
  id := t.val;
end;

procedure TpbParser._Field(var typ: PType);
var
  rule: TFieldRule; ftyp: PType;
begin
  rule := TFieldRule.Singular;
  if (la.kind = 33) or (la.kind = 34) or (la.kind = 35) then
  begin
    if la.kind = 33 then
    begin
      Get;
      rule := TFieldRule.Repeated;
    end
    else if la.kind = 34 then
    begin
      Get;
      rule := TFieldRule.Optional;
    end
    else
    begin
      Get;
    end;
  end;
  _FieldType(ftyp);
  _FieldDecl(ftyp, rule);
  Expect(14);
end;

procedure TpbParser._Reserved;
var obj: PObj;
begin
  Expect(58);
  obj := tab.topScope;
  if obj.aux = nil then
    obj.aux := TMessageOptions.Create(obj);
  if (la.kind = 2) or (la.kind = 3) or (la.kind = 4) then
  begin
    _Ranges(TMessageOptions(obj.aux).Reserved);
  end
  else if la.kind = 1 then
  begin
    _FieldNames(TMessageOptions(obj.aux).ReservedFields);
  end
  else
    SynErr(63);
  Expect(14);
end;

procedure TpbParser._strLit;
begin
  Expect(6);
end;

procedure TpbParser._FullIdent(var id: string);
begin
  Expect(1);
  id := t.val;
  while la.kind = 22 do
  begin
    Get;
    Expect(1);
    id := id + '.' + t.val;
  end;
end;

procedure TpbParser._OptionName(var s: string);
var id: string;
begin
  if la.kind = 1 then
  begin
    Get;
    id := t.val;
  end
  else if la.kind = 20 then
  begin
    Get;
    _FullIdent(id);
    id := id + '(' + id + ')';
    Expect(21);
  end
  else
    SynErr(64);
  while la.kind = 22 do
  begin
    Get;
    Expect(1);
    id := id + '.' + t.val;
  end;
end;

procedure TpbParser._Constant(var c: TConst);
var
  s: string;
  i, sign: Integer;
  d: Double;
begin
  if la.kind = 1 then
  begin
    _FullIdent(s);
    c.AsIdent(s);
  end
  else if StartOf(3) then
  begin
    sign := 1;
    if (la.kind = 31) or (la.kind = 32) then
    begin
      if la.kind = 31 then
      begin
        Get;
        sign := -sign;
      end
      else
      begin
        Get;
      end;
    end;
    if (la.kind = 2) or (la.kind = 3) or (la.kind = 4) then
    begin
      _intLit(i);
      c.AsInt(i * sign);
    end
    else if (la.kind = 5) or (la.kind = 27) or (la.kind = 28) then
    begin
      _floatLit(d);
      c.AsFloat(d * sign);
    end
    else
      SynErr(65);
  end
  else if la.kind = 6 then
  begin
    _strLit;
    c.AsStr(t.val);
  end
  else if (la.kind = 29) or (la.kind = 30) then
  begin
    _boolLit;
    c.AsBool(t.val);
  end
  else
    SynErr(66);
end;

procedure TpbParser._Rpc;
var
  id: string; typ: TQualIdent; rpc: PObj;
  request, response: PType;
begin
  Expect(24);
  _Ident(id);
  tab.NewObj(rpc, id, TMode.mService);
  tab.OpenScope;
  Expect(20);
  if la.kind = 25 then
  begin
    Get;
  end;
  _UserType(typ);
  request := tab.FindMessageType(typ);
  Expect(21);
  Expect(26);
  Expect(20);
  if la.kind = 25 then
  begin
    Get;
  end;
  _UserType(typ);
  response := tab.FindMessageType(typ);
  Expect(21);
  rpc.aux := TRpcOptions.Create(rpc, request, response);
  if la.kind = 10 then
  begin
    Get;
    while (la.kind = 14) or (la.kind = 19) do
    begin
      if la.kind = 19 then
      begin
        _Option;
      end
      else
      begin
        _EmptyStatement;
      end;
    end;
    Expect(11);
  end
  else if la.kind = 14 then
  begin
    Get;
  end
  else
    SynErr(67);
  tab.CloseScope;
end;

procedure TpbParser._UserType(var typ: TQualIdent);
begin
  typ := Default(TQualIdent);
  if la.kind = 22 then
  begin
    Get;
    typ.OutermostScope := True;
  end;
  Expect(1);
  typ.Name := t.val;
  while la.kind = 22 do
  begin
    Get;
    if typ.Package <> '' then
      typ.Package := typ.Package + '.';
    typ.Package := typ.Package + typ.Name;
    Expect(1);
    typ.Name := t.val;
  end;
end;

procedure TpbParser._intLit(var n: Integer);
begin
  if la.kind = 2 then
  begin
    Get;
    n := tab.ParseInt(t.val, 10);
  end
  else if la.kind = 3 then
  begin
    Get;
    n := tab.ParseInt(t.val, 8);
  end
  else if la.kind = 4 then
  begin
    Get;
    n := tab.ParseInt(t.val, 16);
  end
  else
    SynErr(68);
end;

procedure TpbParser._floatLit(var n: Double);
var code: Integer;
begin
  if la.kind = 5 then
  begin
    Get;
    Val(t.val, n, code);
  end
  else if la.kind = 27 then
  begin
    Get;
    n := Infinity;
  end
  else if la.kind = 28 then
  begin
    Get;
    n := NaN;
  end
  else
    SynErr(69);
end;

procedure TpbParser._boolLit;
begin
  if la.kind = 29 then
  begin
    Get;
  end
  else if la.kind = 30 then
  begin
    Get;
  end
  else
    SynErr(70);
end;

procedure TpbParser._FieldType(var typ: PType);
begin
  if StartOf(4) then
  begin
    _Type(typ);
  end
  else if la.kind = 39 then
  begin
    _MapType(typ);
  end
  else if la.kind = 42 then
  begin
    _OneOfType(typ);
  end
  else
    SynErr(71);
end;

procedure TpbParser._FieldDecl(ftyp: PType; rule: TFieldRule);
var
  obj: PObj;
  id: string;
  tag: Integer;
begin
  _Ident(id);
  tab.NewObj(obj, id, TMode.mField);
  obj.typ := ftyp;
  Expect(13);
  _FieldNumber(tag);
  obj.aux := TFieldOptions.Create(obj, tag, rule);
  if la.kind = 36 then
  begin
    Get;
    _FieldOption;
    while la.kind = 37 do
    begin
      Get;
      _FieldOption;
    end;
    Expect(38);
  end;
end;

procedure TpbParser._Type(var typ: PType);
var ut: TQualIdent;
begin
  if la.kind = 43 then
  begin
    Get;
    typ := tab.GetBasisType(TTypeMode.tmDouble);
  end
  else if la.kind = 44 then
  begin
    Get;
    typ := tab.GetBasisType(TTypeMode.tmFloat);
  end
  else if la.kind = 45 then
  begin
    Get;
    typ := tab.GetBasisType(TTypeMode.tmBytes);
  end
  else if StartOf(5) then
  begin
    _KeyType(typ);
  end
  else if (la.kind = 1) or (la.kind = 22) then
  begin
    _UserType(ut);
    typ := tab.FindType(ut);
  end
  else
    SynErr(72);
end;

procedure TpbParser._MapType(var typ: PType);
var
 id: string;
 obj, x: PObj;
 key, value: PType;
begin
  Expect(39);
  if la.kind = 1 then
  begin
    _Ident(id);
  end;
  Expect(40);
  _KeyType(key);
  Expect(37);
  _Type(value);
  Expect(41);
  if id = '' then
    id := Format('%s_%s', [key, value]);
  tab.NewObj(obj, id, TMode.mType);
  tab.OpenScope;
  New(typ); typ.form := TTypeMode.tmMap;
  obj.typ := typ;
  tab.NewObj(x, 'key', TMode.mType); x.typ := key;
  tab.NewObj(x, 'value', TMode.mType); x.typ := value;
  tab.CloseScope;
end;

procedure TpbParser._OneOfType(var typ: PType);
var
  id: string;
  obj: PObj;
begin
  Expect(42);
  _Ident(id);
  tab.NewObj(obj, id, TMode.mType);
  tab.OpenScope;
  New(typ); typ.form := TTypeMode.tmUnion;
  obj.typ := typ;
  Expect(10);
  while StartOf(6) do
  begin
    if la.kind = 19 then
    begin
      _Option;
    end
    else if StartOf(4) then
    begin
      _OneOfField(typ);
    end
    else
    begin
      _EmptyStatement;
    end;
  end;
  Expect(11);
  tab.CloseScope;
end;

procedure TpbParser._FieldNumber(var tag: Integer);
begin
  _intLit(tag);
end;

procedure TpbParser._FieldOption;
var
   id: string;
   Cv: TConst;
begin
  _OptionName(id);
  Expect(13);
  _Constant(Cv);
  tab.AddOption(id, Cv);
end;

procedure TpbParser._KeyType(var ft: PType);
begin
  case la.kind of
    46:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmInt32);
    end;
    47:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmInt64);
    end;
    48:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmUint32);
    end;
    49:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmUint64);
    end;
    50:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmSint32);
    end;
    51:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmSint64);
    end;
    52:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmFixed32);
    end;
    53:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmFixed64);
    end;
    54:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmSfixed32);
    end;
    55:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmSfixed64);
    end;
    56:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmBool);
    end;
    57:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmString);
    end;
    else
      SynErr(73);
  end;
end;

procedure TpbParser._OneOfField(typ: PType);
var ftyp: PType;
begin
  _Type(ftyp);
  _FieldDecl(ftyp, TFieldRule.Singular);
end;

procedure TpbParser._Ranges(Reserved: TIntSet);
var lo, hi: Integer;
begin
  _Range(lo, hi);
  Reserved.AddRange(lo, hi);
  while la.kind = 37 do
  begin
    Get;
    _Range(lo, hi);
    Reserved.AddRange(lo, hi);
  end;
end;

procedure TpbParser._FieldNames(Fields: TStringList);
var id: string;
begin
  _Ident(id);
  Fields.Add(id);
  while la.kind = 37 do
  begin
    Get;
    _Ident(id);
    Fields.Add(id);
  end;
end;

procedure TpbParser._Range(var lo, hi: Integer);
begin
  _intLit(lo);
  if la.kind = 59 then
  begin
    Get;
    if (la.kind = 2) or (la.kind = 3) or (la.kind = 4) then
    begin
      _intLit(hi);
    end
    else if la.kind = 60 then
    begin
      Get;
      hi := 65535;
    end
    else
      SynErr(74);
  end;
end;

procedure TpbParser._EnumField;
var
  id: string;
  n: Integer;
  ev: PObj;
begin
  _Ident(id);
  tab.NewObj(ev, id, TMode.mConst);
  Expect(13);
  if la.kind = 31 then
  begin
    Get;
  end;
  _intLit(n);
  ev.val := n;
  if la.kind = 36 then
  begin
    Get;
    _EnumValueOption;
    while la.kind = 37 do
    begin
      Get;
      _EnumValueOption;
    end;
    Expect(38);
  end;
  Expect(14);
end;

procedure TpbParser._EnumValueOption;
var
  id: string;
  Cv: TConst;
begin
  _OptionName(id);
  Expect(13);
  _Constant(Cv);
  tab.AddOption(id, Cv);
end;

procedure TpbParser.Parse;
begin
  la := scanner.NewToken;
  la.val := '';
  Get;
  _Pb;
  Expect(0);
end;

function TpbParser.Starts(s, kind: Integer): Boolean;
const
  x = false;
  T = true;
  sets: array [0..6] of array [0..63] of Boolean = (
    (T,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x),
    (x,x,x,x, x,x,x,x, x,T,x,x, x,x,T,T, x,x,T,T, x,x,x,T, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,T,x,x),
    (x,T,x,x, x,x,x,x, x,T,x,x, x,x,T,x, x,x,x,T, x,x,T,x, x,x,x,x, x,x,x,x, x,T,T,T, x,x,x,T, x,x,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,x, x,T,x,x),
    (x,x,T,T, T,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,T, T,x,x,T, T,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x),
    (x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,x,x, x,x,x,x),
    (x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,T,T, T,T,T,T, T,T,T,T, T,T,x,x, x,x,x,x),
    (x,T,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x,x,T, x,x,T,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,x,x, x,x,x,x));
begin
  Result := sets[s, kind];
end;

function TpbParser.ErrorMsg(nr: Integer): string;
const
  MaxErr = 74;
  Errors: array [0 .. MaxErr] of string = (
    {0} 'EOF expected',
    {1} 'ident expected',
    {2} 'decimalLit expected',
    {3} 'octalLit expected',
    {4} 'hexLit expected',
    {5} 'real expected',
    {6} 'string expected',
    {7} 'badString expected',
    {8} 'char expected',
    {9} '"message" expected',
    {10} '"{" expected',
    {11} '"}" expected',
    {12} '"syntax" expected',
    {13} '"=" expected',
    {14} '";" expected',
    {15} '"import" expected',
    {16} '"weak" expected',
    {17} '"public" expected',
    {18} '"package" expected',
    {19} '"option" expected',
    {20} '"(" expected',
    {21} '")" expected',
    {22} '"." expected',
    {23} '"service" expected',
    {24} '"rpc" expected',
    {25} '"stream" expected',
    {26} '"returns" expected',
    {27} '"inf" expected',
    {28} '"nan" expected',
    {29} '"true" expected',
    {30} '"false" expected',
    {31} '"-" expected',
    {32} '"+" expected',
    {33} '"repeated" expected',
    {34} '"optional" expected',
    {35} '"required" expected',
    {36} '"[" expected',
    {37} '"," expected',
    {38} '"]" expected',
    {39} '"map" expected',
    {40} '"<" expected',
    {41} '">" expected',
    {42} '"oneof" expected',
    {43} '"double" expected',
    {44} '"float" expected',
    {45} '"bytes" expected',
    {46} '"int32" expected',
    {47} '"int64" expected',
    {48} '"uint32" expected',
    {49} '"uint64" expected',
    {50} '"sint32" expected',
    {51} '"sint64" expected',
    {52} '"fixed32" expected',
    {53} '"fixed64" expected',
    {54} '"sfixed32" expected',
    {55} '"sfixed64" expected',
    {56} '"bool" expected',
    {57} '"string" expected',
    {58} '"reserved" expected',
    {59} '"to" expected',
    {60} '"max" expected',
    {61} '"enum" expected',
    {62} '??? expected',
    {63} 'invalid Reserved',
    {64} 'invalid OptionName',
    {65} 'invalid Constant',
    {66} 'invalid Constant',
    {67} 'invalid Rpc',
    {68} 'invalid intLit',
    {69} 'invalid floatLit',
    {70} 'invalid boolLit',
    {71} 'invalid FieldType',
    {72} 'invalid Type',
    {73} 'invalid KeyType',
    {74} 'invalid Range');
begin
  if nr <= MaxErr then
    Result := Errors[nr]
  else
    Result := 'error ' + IntToStr(nr);
end;

{$EndRegion}

{$Region 'TCocoPartHelper'}

function TCocoPartHelper.GetParser: TpbParser;
begin
  Result := FParser as TpbParser;
end;

function TCocoPartHelper.GetScanner: TpbScanner;
begin
  Result := parser.scanner as TpbScanner;
end;

function TCocoPartHelper.GetOptions: TOptions;
begin
  Result := parser.options;
end;

function TCocoPartHelper.GetTab: TpbTable;
begin
  Result := parser.tab;
end;

function TCocoPartHelper.GetErrors: TErrors;
begin
  Result := parser.errors;
end;

function TCocoPartHelper.GetGen: TGen;
begin
  Result := parser.gen;
end;

{$EndRegion}

end.

