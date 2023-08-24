unit InterfaceSocket;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, System.Win.ScktComp,
  Data.DB, Data.SqlExpr, Data.DBXMySQL, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef, FireDAC.VCLUI.Wait, FireDAC.Comp.Client,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.Comp.DataSet, Vcl.Grids, Vcl.DBGrids, Vcl.ExtCtrls, Vcl.DBCtrls,
  Vcl.Buttons, Vcl.Imaging.pngimage, FireDAC.VCLUI.Error, FireDAC.Comp.UI;

type
  TForm1 = class(TForm)
    ServerSocket1: TServerSocket;
    Memo1: TMemo;
    FDConnection1: TFDConnection;
    Timer1: TTimer;
    FDGUIxErrorDialog1: TFDGUIxErrorDialog;
    Label1: TLabel;
    Panel1: TPanel;
    SpeedButton1: TSpeedButton;
    procedure ServerSocket1ClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServerSocket1ClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServerSocket1ClientError(Sender: TObject;
      Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
      var ErrorCode: Integer);
    procedure ServerSocket1ClientDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure Timer1Timer(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    { Private declarations }
    procedure atualizarlog(log : String);
    procedure executarSql(sql, sucesso, falha : String; responder : Boolean);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  contador: integer;

implementation

{$R *.dfm}

function converterBytes(const A, B: byte): String;
var
  resultado: smallint;
begin
  resultado := (Smallint(A) shl 8) or B;
  result := inttostr(resultado);
end;

function converter4Bytes(const A, B, C, D: byte): String;
var
  bytes: array[0..3] of Byte;
  num : longWord;
begin
    bytes[0] := A;
    bytes[1] := B;
    bytes[2] := C;
    bytes[3] := D;
    num := PLONGWORD(@bytes)^;
    result := inttostr(num);
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  atualizarlog('Aplica��o encerrada.');
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
    CanClose := False;
    if MessageDlg('Confirmar encerramento do programa?', mtConfirmation, mbYesNo, 0) = mrYes then
    begin
        if MessageDlg('Dados deixar�o de ser registrados enquanto a aplica��o estiver fechada.' + #13 + #10 + 'Voc� realmente tem certeza?', mtConfirmation, mbYesNo, 0) = mrYes then
        begin
            CanClose := True;
        end;
    end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
    ServerSocket1.Open;
    SpeedButton1.Caption := 'Servidor Iniciado';
    panel1.Color := clgreen;
    timer1.Enabled := false;
    fdconnection1.Connected := true;
    atualizarlog('Aplica��o iniciada');
    atualizarlog('Servidor Iniciado na porta '+inttostr(ServerSocket1.Port));

    if (fdconnection1.Connected) then
    begin
      atualizarlog('Conex�o MySQL aberta.');
    end;

end;

procedure TForm1.ServerSocket1ClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  atualizarlog('Cliente Conectado');
  timer1.Enabled := false;
  timer1.Enabled := true;
end;

procedure TForm1.ServerSocket1ClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
   atualizarlog('Cliente desconectado.');
   timer1.Enabled := false;
end;

procedure TForm1.ServerSocket1ClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
   atualizarlog('Erro de socket');
end;

procedure TForm1.ServerSocket1ClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
  size : Integer;
  i : Integer;
  bytes : array[0..54] of Byte;
  AnoMes, DiaHora, MinSeg : Integer;
  sql, data, codigo : String;
  //Contador Escaldagem = cont_esc
  //Contador Eviscera��o = cont_evc
  //Contador SIF = cont_sif
  //Contador Noria Automatica = cont_aut
  //Contador Noria Manual 1 = cont_man1
  //Contador Noria Manual 2 = cont_man2
  //Velocidade Noria Escaldagem e Eviscera��o = vel_esc_evc
  //Velocidade Noria SIF = vel_sif
  //Velocidade Noria Automatica= vel_aut
  //Velocidade Noria Manual 1= vel_man1
  //Velocidade Noria Manual 2= vel_man2
  cont_esc, cont_evc, cont_sif, cont_aut,
  cont_man1, cont_man2, vel_esc_evc, vel_sif,
  vel_aut, vel_man1, vel_man2 : String;
begin

  size := Socket.ReceiveLength;
  Socket.ReceiveBuf(bytes[0], size);
  AnoMes :=  strtoint(converterBytes(bytes[1],bytes[0]));
  DiaHora :=  strtoint(converterBytes(bytes[3],bytes[2]));
  MinSeg :=  strtoint(converterBytes(bytes[5],bytes[4]));
  data := Format('%.*d',[2, trunc(AnoMes/100)])+'-'
        +Format('%.*d',[2, trunc(AnoMes mod 100)])+'-'
        +Format('%.*d',[2, trunc(DiaHora/100)])+' '
        +Format('%.*d',[2, trunc(DiaHora mod 100)])+':'
        +Format('%.*d',[2, trunc(MinSeg/100)])+':'
        +Format('%.*d',[2, trunc(MinSeg mod 100)]);
  codigo :=  converterBytes(bytes[7],bytes[6]);

  if(codigo = '1') then
  begin
    cont_esc := converter4Bytes(bytes[8],bytes[9],bytes[10],bytes[11]);
    cont_evc := converter4Bytes(bytes[12],bytes[13],bytes[14],bytes[15]);
    cont_sif := converter4Bytes(bytes[16],bytes[17],bytes[18],bytes[19]);
    cont_aut := converter4Bytes(bytes[20],bytes[21],bytes[22],bytes[23]);
    cont_man1 := converter4Bytes(bytes[24],bytes[25],bytes[26],bytes[27]);
    cont_man2 := converter4Bytes(bytes[28],bytes[29],bytes[30],bytes[31]);
    vel_esc_evc := converter4Bytes(bytes[32],bytes[33],bytes[34],bytes[35]);
    vel_sif := converter4Bytes(bytes[36],bytes[37],bytes[38],bytes[39]);
    vel_aut := converter4Bytes(bytes[40],bytes[41],bytes[42],bytes[43]);
    vel_man1 := converter4Bytes(bytes[44],bytes[45],bytes[46],bytes[47]);
    vel_man2 := converter4Bytes(bytes[48],bytes[49],bytes[50],bytes[51]);

    if (fdconnection1.Connected = false) then
    begin
      fdconnection1.Connected := true;
      atualizarlog('Conex�o MySQL aberta.');
    end;

    sql := 'INSERT INTO contadores_norias(datahora, cont_esc, cont_evc, cont_sif, '+
    'cont_aut, cont_man1, cont_man2) ' +
          'VALUES ("' + data + '",' +
          cont_esc + ', ' + cont_evc +', ' + cont_sif + ', ' +
          cont_aut + ', ' + cont_man1 +', ' + cont_man2 +  ')';
    executarSql(sql,'01','00', false);

    sql := 'INSERT INTO velocidades_norias(datahora, vel_esc_evc, vel_sif, vel_aut, '+
    'vel_man1, vel_man2) ' +
          'VALUES ("' + data + '",' +
          vel_esc_evc + ', ' + vel_sif +', ' + vel_aut + ', ' +
          vel_man1 + ', ' + vel_man2 + ')';
    executarSql(sql,'01','00', false);

  end;

  timer1.Enabled := false;
  timer1.Enabled := true;

end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
  if(SpeedButton1.Caption = 'Servidor Parado') then
  begin
    ServerSocket1.Open;
    SpeedButton1.Caption := 'Servidor Iniciado';
    panel1.Color := clgreen;
    atualizarlog('Servidor Iniciado na porta '+inttostr(ServerSocket1.Port));
  end
  else
  begin
    ServerSocket1.Close;
    SpeedButton1.Caption := 'Servidor Parado';
    panel1.Color := clred;
    timer1.Enabled := false;
    atualizarlog('Servidor Socket parado.');

    if (fdconnection1.Connected) then
    begin
      fdconnection1.Connected := false;
      atualizarlog('Conex�o MySQL finalizada.');
    end;

  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  x, conexoes: integer;
begin

  fdconnection1.Connected := false;
  atualizarlog('Timeout, encerrando conex�es MySQL...');

  conexoes := ServerSocket1.Socket.ActiveConnections;
  if (ServerSocket1.Active and (conexoes > 0)) then
  begin
    for x := 0 to (conexoes-1) do
    begin
      ServerSocket1.Socket.Connections[x].close;
    end;
     atualizarlog('Timeout, encerrando conex�es socket...');
  end;
end;

procedure tform1.atualizarlog(log : String);
var
  arquivo: TextFile;
  linha : String;
  nomearquivo : String;
begin
    linha := datetostr(Now) + ' ' + timetostr(Now)+ ': ' + log;
    nomearquivo :=  'log_'+formatdatetime('dd-mm-yyyy', Now)+'.txt';

    AssignFile(arquivo, nomearquivo);
    if FileExists(nomearquivo) then
      Append(arquivo)
    else
    begin
      Rewrite(arquivo);
      Memo1.clear;
    end;
    Memo1.lines.Add(linha);
    writeln(arquivo,linha);
    CloseFile(arquivo);

end;

procedure tform1.executarSql(sql, sucesso, falha : String; responder : boolean);
var
  i : Integer;
begin
    atualizarlog(sql);
    if (fdconnection1.Connected = false) then
    begin
      fdconnection1.Connected := true;
      atualizarlog('Conex�o MySQL aberta.');
    end;

    if((FDConnection1.execsql(sql)) > 0) then
    begin
      if (responder) then
      begin
        for i:=0 to ServerSocket1.Socket.ActiveConnections-1 do
          ServerSocket1.Socket.Connections[i].SendText(sucesso);
      end;
    end
    else
    begin
      if(responder) then
      begin
        for i:=0 to ServerSocket1.Socket.ActiveConnections-1 do
          ServerSocket1.Socket.Connections[i].SendText(falha);
        atualizarlog('Erro gravando no banco!');
      end;
    end;

end;

end.