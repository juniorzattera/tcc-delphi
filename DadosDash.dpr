program DadosDash;

uses
  Vcl.Forms,
  InterfaceSocket in 'InterfaceSocket.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
