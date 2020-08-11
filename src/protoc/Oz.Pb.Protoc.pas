unit Oz.Pb.Protoc;



interface

uses
  System.Classes, System.SysUtils, System.IOUtils,
  Oz.Cocor.Lib, Oz.Pb.Options, Oz.Pb.Scanner, Oz.Pb.Parser, Oz.Pb.Tab, Oz.Pb.Gen;

procedure Run;

implementation

procedure Run;
var
  options: TOptions;
  str: TStringList;
  parser: TpbParser;
  sr: TSearchRec;
  src, filename: string;
begin
  options := GetOptions;
  Writeln(options.GetVersion);
  options.ParseCommandLine;
  if (ParamCount = 0) or (options.SrcName = '') then
    options.Help
  else
  begin
    try
      options.srcDir := TPath.GetDirectoryName(options.SrcName);
      str := TStringList.Create;
      try
        str.LoadFromFile(options.SrcName);
        src := str.Text;
      finally
        str.Free;
      end;
      str := TStringList.Create;
      parser := TpbParser.Create(TpbScanner.Create(src), str);
      try
        parser.Parse;
        FindClose(sr);
        Writeln(parser.errors.count, ' errors detected');
        parser.PrintErrors;
        filename := TPath.Combine(options.srcDir, 'errors.lst');
        str.SaveToFile(filename);
      finally
        str.Free;
        parser.Free;
      end;
    except
      on e: FatalError do
        Writeln('-- ', e.Message);
    end;
  end;
end;

end.
