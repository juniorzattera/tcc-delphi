unit InterfaceSocket;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, System.Win.ScktComp,
  Data.DB, Data.SqlExpr, Data.DBXMySQL, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef, FireDAC.VCLUI.Wait, FireDAC.Comp.Client, IdIcmpClient,
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

function VerificarPing(IP: string): string;
var
  ICMPClient: TIdIcmpClient;
begin
  Result := '1'; // Não está pingando

  ICMPClient := TIdIcmpClient.Create(nil);
  try
    ICMPClient.Host := IP;
    try
      ICMPClient.Ping;
      if ICMPClient.ReplyStatus.ReplyStatusType = rsEcho then
        Result := '0'; // Está pingando
    except
    end;
  finally
    ICMPClient.Free;
  end;
end;

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
  num : integer;
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
  atualizarlog('Aplicação encerrada.');
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
    CanClose := False;
    if MessageDlg('Confirmar encerramento do programa?', mtConfirmation, mbYesNo, 0) = mrYes then
    begin
        if MessageDlg('Dados deixarão de ser registrados enquanto a aplicação estiver fechada.' + #13 + #10 + 'Você realmente tem certeza?', mtConfirmation, mbYesNo, 0) = mrYes then
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
    atualizarlog('Aplicação iniciada');
    atualizarlog('Servidor Iniciado na porta '+inttostr(ServerSocket1.Port));

    if (fdconnection1.Connected) then
    begin
      atualizarlog('Conexão MySQL aberta.');
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
  bytes : array[0..80] of Byte;
  AnoMes, DiaHora, MinSeg: Integer;
  sql, data, codigo, IP, ping_camera, perdaMiudos1, totalPacote1, porcentagemPerda1,
  cont_esc, cont_evc, cont_sif, cont_aut,
  cont_man1, cont_man2, cont_chillers, cont_evisceradora,
  vel_esc_evc, vel_sif, vel_aut, vel_man1, vel_man2,
  miudos_antes, miudos_depois, diferenca_miudos,
  cont_pendura, diferenca_pen_esc,
  totalEviscerados, totalViscerasPerdidas, rendimentoTotal : String;

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
    IP := '121.1.17.212';
    ping_camera := VerificarPing(IP);
    cont_pendura := converter4Bytes(bytes[8],bytes[9],bytes[10],bytes[11]);
    diferenca_pen_esc := converter4Bytes(bytes[12],bytes[13],bytes[14],bytes[15]);
    cont_esc := converter4Bytes(bytes[16],bytes[17],bytes[18],bytes[19]);
    cont_evisceradora := converter4Bytes(bytes[20],bytes[21],bytes[22],bytes[23]);
    cont_evc := converter4Bytes(bytes[24],bytes[25],bytes[26],bytes[27]);
    cont_sif := converter4Bytes(bytes[28],bytes[29],bytes[30],bytes[31]);
    miudos_antes := converter4Bytes(bytes[32],bytes[33],bytes[34],bytes[35]);
    miudos_depois := converter4Bytes(bytes[36],bytes[37],bytes[38],bytes[39]);
    diferenca_miudos := converter4Bytes(bytes[40],bytes[41],bytes[42],bytes[43]);
    cont_aut := converter4Bytes(bytes[44],bytes[45],bytes[46],bytes[47]);
    cont_man1 := converter4Bytes(bytes[48],bytes[49],bytes[50],bytes[51]);
    cont_man2 := converter4Bytes(bytes[52],bytes[53],bytes[54],bytes[55]);
    cont_chillers := converter4Bytes(bytes[56],bytes[57],bytes[58],bytes[59]);
    vel_esc_evc := converter4Bytes(bytes[60],bytes[61],bytes[62],bytes[63]);
    vel_sif := converter4Bytes(bytes[64],bytes[65],bytes[66],bytes[67]);
    vel_aut := converter4Bytes(bytes[68],bytes[69],bytes[70],bytes[71]);
    vel_man1 := converter4Bytes(bytes[72],bytes[73],bytes[74],bytes[75]);
    vel_man2 := converter4Bytes(bytes[76],bytes[77],bytes[78],bytes[79]);

    if (fdconnection1.Connected = false) then
    begin
      fdconnection1.Connected := true;
      atualizarlog('Conexão MySQL aberta.');
    end;

    sql := 'INSERT INTO contadores_norias(datahora, cont_pendura, diferenca_pen_esc,' +
          'cont_esc, cont_evisceradora, cont_evc, cont_sif, '+
          'miudos_antes, miudos_depois, diferenca_miudos,' +
          'cont_aut, cont_man1, cont_man2, cont_chillers) ' +
          'VALUES ("' + data + '",' +
          cont_pendura +',' + diferenca_pen_esc +',' + cont_esc + ', ' + cont_evisceradora + ', ' +
          cont_evc +', ' + cont_sif + ', ' +
          miudos_antes + ', ' + miudos_depois + ', ' + diferenca_miudos + ', ' +
          cont_aut + ', ' + cont_man1 +', ' + cont_man2 + ', ' +
          cont_chillers + ')';
    executarSql(sql,'01','00', false);

    sql := 'INSERT INTO velocidades_norias(datahora, vel_esc_evc, vel_sif, vel_aut, '+
    'vel_man1, vel_man2) ' +
          'VALUES ("' + data + '",' +
          vel_esc_evc + ', ' + vel_sif +', ' + vel_aut + ', ' +
          vel_man1 + ', ' + vel_man2 + ')';
    executarSql(sql,'01','00', false);

    sql := 'INSERT INTO ping(datahora, camera_sangria) ' +
          'VALUES ("' + data + '",' +
          ping_camera + ')';
    executarSql(sql,'01','00', false);

  end;

  if(codigo = '2') then
  begin
    perdaMiudos1 := converter4Bytes(bytes[8],bytes[9],bytes[10],bytes[11]);
    totalPacote1 := converter4Bytes(bytes[12],bytes[13],bytes[14],bytes[15]);
    porcentagemPerda1 := converter4Bytes(bytes[16],bytes[17],bytes[18],bytes[19]);

    if (fdconnection1.Connected = false) then
    begin
      fdconnection1.Connected := true;
      atualizarlog('Conexão MySQL aberta.');
    end;

    sql := 'INSERT INTO evisceradora(datahora, perdaMiudos1, totalPacote1, porcentagemPerda1) '+
          'VALUES ("' + data + '",' +
          perdaMiudos1 + ', ' + totalPacote1 +', ' + porcentagemPerda1 + ', ' +
          cont_aut + ', ' + cont_man1 +', ' + cont_man2 + ', ' +
          cont_chillers + ')';
    executarSql(sql,'01','00', false);

  end;

   if(codigo = '3') then
  begin
    totalEviscerados := converter4Bytes(bytes[8],bytes[9],bytes[10],bytes[11]);
    totalViscerasPerdidas := converter4Bytes(bytes[12],bytes[13],bytes[14],bytes[15]);
    rendimentoTotal := converter4Bytes(bytes[16],bytes[17],bytes[18],bytes[19]);

    if (fdconnection1.Connected = false) then
    begin
      fdconnection1.Connected := true;
      atualizarlog('Conexão MySQL aberta.');
    end;

    sql := 'INSERT INTO evisceradora(datahora, totalEviscerados, totalViscerasPerdidas, rendimentoTotal) '+
          'VALUES ("' + data + '",' +
          totalEviscerados + ', ' + totalViscerasPerdidas +', ' + rendimentoTotal + ')';
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
      atualizarlog('Conexão MySQL finalizada.');
    end;

  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  x, conexoes: integer;
begin

  fdconnection1.Connected := false;
  atualizarlog('Timeout, encerrando conexões MySQL...');

  conexoes := ServerSocket1.Socket.ActiveConnections;
  if (ServerSocket1.Active and (conexoes > 0)) then
  begin
    for x := 0 to (conexoes-1) do
    begin
      ServerSocket1.Socket.Connections[x].close;
    end;
     atualizarlog('Timeout, encerrando conexões socket...');
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
      atualizarlog('Conexão MySQL aberta.');
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
