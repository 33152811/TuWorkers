{*******************************************************}
{                                                       }
{                 TU2 Worker&Job Library                }
{                                                       }
{               Copyright(C) 2016-2017 Tutu             }
{                       QQ:245806497                    }
{*******************************************************}
{       Minimum supported client: Windows 7            *}
{*   Minimum supported server: Windows Server 2008 R2  *}
{********************************************************
  【说明】
  TuWorkers是一个后台工作线程池，用于管理后台工作的调度及运行。
  在TuWorkers中，最小的工作单位被称为作业（Job），作业可以是:
  1、简单的一次异步执行过程;
  2、在指定的时间点自动执行的过程;
  3、间隔时间重复执行的过程;
  4、在得到相应的信号时执行的过程;
  5、在IO完成时执行的过程。
  【限制】
  1、时间间隔使用毫秒(ms)为基本单位，注意DWORD能表示的最大间隔时间(49.7天);
  2、定时器首次开始时间使用100纳秒(100ns)为基本单位，注意正值为绝对UTC时间，
    负值为相对时间;
  【注意事项】
  1、在桌面程序中，主线程销毁GWorkers（执行CloseThreadpoolCleanupGroupMembers）
    时，可能造成死锁，因为后台工作线程可能正在执行TThread.Synchronize。
    这种情况下请在程序主窗体关闭事件中主动使用SafeClose方法关闭线程池。
 --------------------------------------------------------------------
  更新记录
 --------------------------------------------------------------------
 2017.07.05 ver 1.5.0  - 重新定义回调接口，不回传内部Job对象
 2017.07.01 ver 1.4.0  - 信号作业只支持全局函数，删除冗余代码
 2017.05.16 ver 1.3.1  - IO作业只支持全局函数，删除冗余代码
 2017.02.25 ver 1.3.0  - 增加IO完成作业
 2017.01.14 ver 1.2.1  - 增加并行作业
 2017.01.12 ver 1.2.0  - 增加工作项作业和等待信号作业
 2016.10.30 ver 1.1.1  - 实现简单作业和定时重复作业
 2016.10.29 ver 1.1.0  - 重构代码，采用系统线程池API
 2016.05.27 ver 1.0.2  - 实现并行作业管理
 2016.05.12 ver 1.0.1  - 实现信号作业
 2016.04.29 ver 1.0.0  - 重构代码，实现简单作业
 --------------------------------------------------------------------
********************************************************}

unit uTuWorkers;

interface

uses Winapi.Windows, Winapi.ThreadPool, System.SysUtils;

type
  /// <summary>作业优先级</summary>
  TJobPriority = (jpHigh, jpNomal, jpLow);
  /// <summary>作业附加数据选项</summary>
  TJobDataOption = (
    jdoNone,              //作业不负责附加数据的释放
    jdoDataIsObject,      //附加数据是一个对象
    jdoDataIsInterface,   //附加数据是一个接口
    jdoDataIsSimpleRecord //附加数据是一个New创建的简单记录指针
    );

  /// <summary>作业处理回调成员函数</summary>
  TJobProc = procedure(const AJobData: Pointer) of object;
  /// <summary>作业处理回调全局函数</summary>
  TJobProcG = procedure(const AJobData: Pointer);
  /// <summary>作业处理回调匿名函数</summary>
  TJobProcA = reference to procedure(const AJobData: Pointer);
  /// <summary>并行作业处理回调成员函数</summary>
  TForJobProc = procedure(var bBreaked: Boolean; const AIndex: Integer; const AJobData: Pointer) of object;
  /// <summary>并行作业处理回调全局函数</summary>
  TForJobProcG = procedure(var bBreaked: Boolean; const AIndex: Integer; const AJobData: Pointer);
  /// <summary>并行作业处理回调匿名函数</summary>
  TForJobProcA = reference to procedure(var bBreaked: Boolean; const AIndex: Integer; const AJobData: Pointer);

  TuWorkers = class
  private type
    TJob = class abstract
    private
      fData: Pointer;                 // 附加数据内容
      fOption: TJobDataOption;        // 作业数据选项
      fFlag: Cardinal;                // 内部标记
      procedure InvokeCallback;
    protected
      procedure DoJob; virtual; abstract;
    public
      constructor Create(const AData: Pointer; const AOption: TJobDataOption);
      destructor Destroy; override;
    end;

    TMJob = class(TJob)
    private
      fMethod: TJobProc;
    protected
      procedure DoJob; override;
    end;

    TGJob = class(TJob)
    private
      fMethod: TJobProcG;
    protected
      procedure DoJob; override;
    end;

    TAJob = class(TJob)
    private
      fMethod: TJobProcA;
    protected
      procedure DoJob; override;
    public
      destructor Destroy; override;
    end;

    TForJob = class abstract(TJob)
    private
      FIterator: Int64;
      FStopIndex: Integer;
    protected
      procedure DoJob; override;
      procedure DoForJob(var bBreaked:Boolean; const AIndex: Integer); virtual; abstract;
    end;

    TMForJob = class(TForJob)
    private
      fMethod: TForJobProc;
    protected
      procedure DoForJob(var bBreaked:Boolean; const AIndex: Integer); override;
    end;

    TGForJob = class(TForJob)
    private
      fMethod: TForJobProcG;
    protected
      procedure DoForJob(var bBreaked:Boolean; const AIndex: Integer); override;
    end;

    TAForJob = class(TForJob)
    private
      fMethod: TForJobProcA;
    protected
      procedure DoForJob(var bBreaked:Boolean; const AIndex: Integer); override;
    public
      destructor Destroy; override;
    end;
  private
    fThreadPool: PTP_POOL;
    fCG: PTP_CLEANUP_GROUP;
    fMinWorker: Cardinal;
    fMaxWorker: Cardinal;
    procedure SetMinWorker(AMin: Cardinal);
    procedure SetMaxWorker(AMax: Cardinal);
    procedure InitCallBackEnviron(var CBE: TP_CALLBACK_ENVIRON_V3;
      const APriority: TJobPriority; const ACleanup: Boolean);
    procedure PostSimple(const AJob: TJob; const APriority: TJobPriority);
    function PostTimer(const AJob: TJob; const APriority: TJobPriority;
      const AStart: Int64; const AInterval: Cardinal): PTP_TIMER;
    function RegisterWork(const AJob: TJob; const APriority: TJobPriority): PTP_WORK; overload;
    function PostForWork(const AJob: TForJob;const AStart, AStop: Integer): PTP_WORK;
  public
    constructor Create;
    procedure Close;
    procedure SafeClose;
    destructor Destroy; override;
    /// <summary>投寄简单作业</summary>
    /// <param name="AProc">要执行的作业过程</param>
    /// <param name="APriority">作业优先级</param>
    /// <param name="AData">作业附加的用户数据</param>
    /// <param name="AOption">作业附加数据释放选项</param>
    procedure Post(const AProc: TJobProc; const APriority: TJobPriority=jpNomal;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone); overload;
    procedure Post(const AProc: TJobProcG; const APriority: TJobPriority=jpNomal;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone); overload;
    procedure Post(const AProc: TJobProcA; const APriority: TJobPriority=jpNomal;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone); overload;
    /// <summary>投寄在指定时间开始的重复作业</summary>
    /// <param name="AProc">要定时执行的作业过程</param>
    /// <param name="AStartTime">首次开始时间，单位为100ns。等于0，表示立即执行；
    ///小于0，代表相对于当前时间的延时间隔(不包括系统休眠或睡眠的时间)；
    ///大于0，代表相对于1601-1-1(UTC)的绝对时间，请使用类方法DataTimeToUtcFileTime
    ///将一个TDateTime转换为UTC绝对时间。</param>
    /// <param name="AInterval">重复作业时间间隔，单位为ms。等于0表示不重复，只执行一次。</param>
    /// <param name="APriority">作业优先级</param>
    /// <param name="AData">作业附加的用户数据</param>
    /// <param name="AOption">作业附加数据释放选项</param>
    /// <returns>线程池定时器</returns>
    /// <remarks>如果绝对时间(AStartTime>0)在内部调用SetThreadpoolTimer时已过期，
    ///线程池定时器回调将不会触发。所以请使用一个距离当前时间足够大间隔的绝对时
    ///间指定首次触发时间，否则使用相对时间方式指定。</remarks>
    function PostAt(const AProc: TJobProc; const AStartTime: Int64=0;
      const AInterval: Cardinal=0; const APriority: TJobPriority=jpNomal;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone): PTP_TIMER; overload;
    function PostAt(const AProc: TJobProcG; const AStartTime: Int64=0;
      const AInterval: Cardinal=0; const APriority: TJobPriority=jpNomal;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone): PTP_TIMER; overload;
    function PostAt(const AProc: TJobProcA; const AStartTime: Int64=0;
      const AInterval: Cardinal=0; const APriority: TJobPriority=jpNomal;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone): PTP_TIMER; overload;
    /// <summary>注册工作项</summary>
    /// <param name="AProc">工作项作业过程</param>
    /// <param name="APriority">作业优先级</param>
    /// <param name="AData">作业附加的用户数据</param>
    /// <param name="AOption">作业附加数据释放选项</param>
    /// <returns>线程池工作项</returns>
    function RegisterWork(const AProc: TJobProc; const APriority: TJobPriority=jpNomal;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone): PTP_WORK; overload;
    function RegisterWork(const AProc: TJobProcG; const APriority: TJobPriority=jpNomal;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone): PTP_WORK; overload;
    function RegisterWork(const AProc: TJobProcA; const APriority: TJobPriority=jpNomal;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone): PTP_WORK; overload;
    /// <summary>投寄等待信号的作业</summary>
    /// <param name="AHandle">等待的同步信号句柄</param>
    /// <param name="ACallBack">信号触发时执行的作业过程</param>
    /// <param name="AContext">作业过程上下文参数（全局）</param>
    /// <param name="ATimeout">超时时间，单位为100ns。小于0，代表相对于当前时间的超时间隔；
    ///等于0，代表无限长等待；大于0，代表超时相对于1601-1-1(UTC)的绝对时间，请使用类方法
    ///DataTimeToUtcFileTime将一个TDateTime转换为UTC绝对时间。</param>
    /// <param name="APriority">作业优先级</param>
    /// <returns>线程池等待信号对象</returns>
    function PostWait(const AHandle: THandle; const ACallBack: PTP_WAIT_CALLBACK;
      const AContext: Pointer=nil; const ATimeout: Int64=0;
      const APriority: TJobPriority=jpNomal): PTP_WAIT;
    /// <summary>投寄IO完成作业</summary>
    /// <param name="AHandle">IO完成对象绑定的句柄</param>
    /// <param name="ACallBack">IO作业过程</param>
    /// <param name="AContext">IO上下文参数（全局）</param>
    /// <param name="APriority">IO作业优先级（默认高优先级）</param>
    /// <returns>IO完成对象</returns>
    function PostIO(const AHandle: THandle; const ACallBack: PTP_WIN32_IO_CALLBACK;
      const AContext: Pointer=nil; const APriority: TJobPriority=jpNomal): PTP_IO;
    /// <summary>从指定的开始索引并行执行指定的过程到结束索引</summary>
    /// <param name="AWorkerProc">要并行执行的过程</param>
    /// <param name="AStart">起始索引（含）</param>
    /// <param name="AStop">结束索引（含）</param>
    /// <param name="AData">作业附加的用户数据</param>
    /// <param name="AOption">作业附加数据释放选项</param>
    /// <returns>返回并行工作项</returns>
    function &For(const AProc: TForJobProc; const AStart, AEnd: Integer;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone): PTP_WORK; overload;
    function &For(const AProc: TForJobProcG; const AStart, AEnd: Integer;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone): PTP_WORK; overload;
    function &For(const AProc: TForJobProcA; const AStart, AEnd: Integer;
      const AData: Pointer=nil; const AOption: TJobDataOption=jdoNone): PTP_WORK; overload;
    /// <summary>最小工作者（线程）数量，默认值1。</summary>
    property MinWorker: Cardinal read fMinWorker write SetMinWorker;
    /// <summary>最大工作者（线程）数量，默认值500。</summary>
    property MaxWorker: Cardinal read fMaxWorker write SetMaxWorker;
  public //内联辅助方法
    /// <summary>投寄已注册的工作项</summary>
    /// <param name="AWork">RegisterWork返回的Work</param>
    class procedure PostWork(const AWork: PTP_WORK); inline;
    /// <summary>修改线程池定时器参数</summary>
    /// <param name="ATimer">要修改的定时器。</param>
    /// <param name="AInterval">重复作业时间间隔，单位为ms。等于0表示不重复，只执行一次。</param>
    /// <param name="AStartTime">首次开始时间，单位为100ns。等于0，表示立即执行；
    ///小于0，代表相对于当前时间的延时间隔(不包括系统休眠或睡眠的时间)；
    ///大于0，代表相对于1601-1-1(UTC)的绝对时间，请使用DataTimeToUtcFileTime函数
    ///将一个TDateTime转换为UTC绝对时间。</param>
    /// <param name="AWindowLength">定时器窗口大小，单位毫秒(ms)，默认值10。</param>
    /// <remarks>如果绝对时间(AStartTime>0)在内部调用SetThreadpoolTimer时已过期，
    ///线程池定时器回调将不会触发。所以请使用一个距离当前时间足够大间隔的绝对时
    ///间指定首次触发时间，否则请使用相对时间方式指定。</remarks>
    class procedure ModifyTimer(const ATimer: PTP_TIMER; const AInterval: Cardinal=0;
       const AStartTime: Int64=0; const AWindowLength: Cardinal=10); inline;
    /// <summary>停止触发线程池定时器</summary>
    /// <param name="ATimer">要停止的定时器</param>
    class procedure StopTimer(const ATimer: PTP_TIMER); inline;
    /// <summary>修改等待信号参数</summary>
    /// <param name="AWait">要修改的等待信号Id</param>
    /// <param name="AHandle">要绑定的信号句柄</param>
    /// <param name="ATimeout">超时时间，单位为100ns。小于0，代表相对于当前时间的超时间隔；
    ///等于0，代表无限长等待；大于0，代表超时相对于1601-1-1(UTC)的绝对时间，请使用类方法
    ///DataTimeToUtcFileTime将一个TDateTime转换为UTC绝对时间。</param>
    class procedure ModifyWait(const AWait: PTP_WAIT; const AHandle: THandle; const ATimeout: Int64); inline;
    /// <summary>停止触发（响应）等待信号</summary>
    /// <param name="AWait">要解绑的等待信号</param>
    class procedure StopWait(const AWait: PTP_WAIT); inline;
    class function DataTimeToUtcFileTime(const ATime: TDateTime): Int64; inline;
  end;

const
  MSecsPerMin = MSecsPerSec*SecsPerMin;
  MSecsPerHour = MSecsPerSec*SecsPerHour;
  N100PerMSec = 10*1000;
  N100PerSec  = N100PerMSec*MSecsPerSec;
  Interval60s = Int64(-60)*N100PerSec;    //60s
var
  GWorkers: TuWorkers;

implementation

uses System.Classes;

procedure Simple_Callback(Instance: PTP_CALLBACK_INSTANCE; Context: PVOID); stdcall;
var
  AJob: TuWorkers.TJob;
begin
  AJob := TuWorkers.TJob(Context);
  try
    AJob.InvokeCallback;
  finally
    AJob.Free;
  end;
end;

procedure Timer_Callback(Instance: PTP_CALLBACK_INSTANCE; Context: PVOID; Work: PTP_TIMER); stdcall;
var
  AJob: TuWorkers.TJob;
begin
  AJob := TuWorkers.TJob(Context);
  if System.AtomicCmpExchange(AJob.fFlag, 1, 0)=0 then
  begin
    try
      AJob.InvokeCallback;
    finally
      System.AtomicExchange(AJob.fFlag, 0);
    end;
  end;
end;

procedure Work_Callback(Instance: PTP_CALLBACK_INSTANCE; Context: PVOID; Work: PTP_WORK); stdcall;
begin
  TuWorkers.TJob(Context).InvokeCallback;
end;

procedure CleanupGroupCancel_Callback(ObjectContext,CleanupContext: PVOID); stdcall;
begin
  TObject(ObjectContext).Free;
end;

{ TuWorkers }
constructor TuWorkers.Create;
begin
  inherited;
  fThreadPool := CreateThreadpool;
  if fThreadPool=nil then RaiseLastOSError;
  SetMaxWorker(500);
  SetMinWorker(1);
  fCG := CreateThreadpoolCleanupGroup;
  if fCG=nil then RaiseLastOSError;
end;

destructor TuWorkers.Destroy;
begin
  if fThreadPool<>nil then Close;
  inherited;
end;

type
  TSafeCloseThread = class(TThread)
  private
    fThreadPool: PTP_POOL;
    fCG: PTP_CLEANUP_GROUP;
  protected
    procedure Execute; override;
  end;

procedure TSafeCloseThread.Execute;
begin
  if fCG<>nil then
  begin
    CloseThreadpoolCleanupGroupMembers(fCG, True, nil);
    CloseThreadpoolCleanupGroup(fCG);
  end;
  CloseThreadpool(fThreadPool);
end;

procedure TuWorkers.SafeClose;
var
  AThread: TSafeCloseThread;
begin
  if TThread.Current.ThreadID=MainThreadID then
  begin
    AThread := TSafeCloseThread.Create(True);
    AThread.FreeOnTerminate := True;
    AThread.fThreadPool := fThreadPool;
    AThread.fCG := fCG;
    AThread.Start;
    fThreadPool := nil;
  end else
    Close;
end;

procedure TuWorkers.Close;
begin
  if fCG<>nil then
  begin
    //may cause deadlock, please see/use SafeClose method.
    CloseThreadpoolCleanupGroupMembers(fCG, True, nil);
    CloseThreadpoolCleanupGroup(fCG);
  end;
  CloseThreadpool(fThreadPool);
  fThreadPool := nil;
end;

procedure TuWorkers.SetMaxWorker(AMax: Cardinal);
begin
  if AMax<>fMaxWorker then
  begin
    SetThreadpoolThreadMaximum(fThreadPool, AMax);
    fMaxWorker := AMax;
  end;
end;

procedure TuWorkers.SetMinWorker(AMin: Cardinal);
begin
  if AMin<>fMinWorker then
  begin
    if SetThreadpoolThreadMinimum(fThreadPool, AMin) then
      fMinWorker := AMin
    else RaiseLastOSError;
  end;
end;

procedure TuWorkers.InitCallBackEnviron(var CBE: TP_CALLBACK_ENVIRON_V3;
  const APriority: TJobPriority; const ACleanup: Boolean);
var
  ASize: Integer;
begin
  ASize := SizeOf(TP_CALLBACK_ENVIRON_V3);
  FillChar(CBE, ASize, #0);
  CBE.Size := ASize;
  CBE.Version := 3;
  CBE.Pool := fThreadPool;
  if ACleanup then
  begin
    CBE.CleanupGroup := fCG;
    CBE.CleanupGroupCancelCallback := CleanupGroupCancel_Callback;
  end;
  CBE.CallbackPriority := TCallbackPriority(APriority);
  //RaceDll: PVOID;
  //ActivationContext: Pointer; //_ACTIVATION_CONTEXT *
  //FinalizationCallback: PTP_SIMPLE_CALLBACK;
  //u: TP_CALLBACK_ENVIRON_V3_U;
end;

procedure TuWorkers.PostSimple(const AJob: TJob; const APriority: TJobPriority);
var
  CBE: TP_CALLBACK_ENVIRON_V3;
begin
  InitCallBackEnviron(CBE, APriority, True);
  if not TrySubmitThreadpoolCallback(Simple_Callback, AJob, @CBE) then
  begin
    AJob.Free;
    RaiseLastOSError;
  end;
end;

function TuWorkers.PostTimer(const AJob: TJob; const APriority: TJobPriority;
  const AStart: Int64; const AInterval: Cardinal): PTP_TIMER;
var
  CBE: TP_CALLBACK_ENVIRON_V3;
begin
  InitCallBackEnviron(CBE, APriority, True);
  Result := CreateThreadpoolTimer(Timer_Callback, AJob, @CBE);
  if Result<>nil then
    ModifyTimer(Result, AInterval, AStart)
  else begin
    AJob.Free;
    RaiseLastOSError;
  end;
end;

function TuWorkers.RegisterWork(const AJob: TJob; const APriority: TJobPriority): PTP_WORK;
var
  CBE: TP_CALLBACK_ENVIRON_V3;
begin
  InitCallBackEnviron(CBE, APriority, True);
  Result := CreateThreadpoolWork(Work_Callback, AJob, @CBE);
  if Result=nil then
  begin
    AJob.Free;
    RaiseLastOSError;
  end;
end;

function TuWorkers.PostForWork(const AJob: TForJob; const AStart, AStop: Integer): PTP_WORK;
var
  AWorkerCount: Int64;
begin
  AWorkerCount := AStop-AStart+1;
  if AWorkerCount>0 then
  begin
    if AWorkerCount>CPUCount then
      AWorkerCount := CPUCount;
    Result := RegisterWork(AJob, jpHigh);
    AJob.FIterator := AStart;
    Dec(AJob.FIterator);
    AJob.FStopIndex := AStop;
    repeat
      PostWork(Result);
      Dec(AWorkerCount);
    until AWorkerCount=0;
  end else begin
    AJob.Free;
    raise Exception.Create('The Stop index is less than Start index');
  end;
end;
//------------------------------------------------------------------------------
procedure TuWorkers.Post(const AProc: TJobProc; const APriority: TJobPriority;
  const AData: Pointer; const AOption: TJobDataOption);
var
  AJob: TMJob;
begin
  AJob := TMJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  PostSimple(AJob, APriority);
end;

procedure TuWorkers.Post(const AProc: TJobProcG; const APriority: TJobPriority;
  const AData: Pointer; const AOption: TJobDataOption);
var
  AJob: TGJob;
begin
  AJob := TGJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  PostSimple(AJob, APriority);
end;

procedure TuWorkers.Post(const AProc: TJobProcA; const APriority: TJobPriority;
  const AData: Pointer; const AOption: TJobDataOption);
var
  AJob: TAJob;
begin
  AJob := TAJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  PostSimple(AJob, APriority);
end;

function TuWorkers.PostAt(const AProc: TJobProc; const AStartTime: Int64;
  const AInterval: Cardinal; const APriority: TJobPriority;
  const AData: Pointer; const AOption: TJobDataOption): PTP_TIMER;
var
  AJob: TMJob;
begin
  AJob := TMJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  Result := PostTimer(AJob, APriority, AStartTime, AInterval);
end;

function TuWorkers.PostAt(const AProc: TJobProcG; const AStartTime: Int64;
  const AInterval: Cardinal; const APriority: TJobPriority;
  const AData: Pointer; const AOption: TJobDataOption): PTP_TIMER;
var
  AJob: TGJob;
begin
  AJob := TGJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  Result := PostTimer(AJob, APriority, AStartTime, AInterval);
end;

function TuWorkers.PostAt(const AProc: TJobProcA; const AStartTime: Int64;
  const AInterval: Cardinal; const APriority: TJobPriority;
  const AData: Pointer; const AOption: TJobDataOption): PTP_TIMER;
var
  AJob: TAJob;
begin
  AJob := TAJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  Result := PostTimer(AJob, APriority, AStartTime, AInterval);
end;

function TuWorkers.RegisterWork(const AProc: TJobProc; const APriority: TJobPriority;
  const AData: Pointer; const AOption: TJobDataOption): PTP_WORK;
var
  AJob: TMJob;
begin
  AJob := TMJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  Result := RegisterWork(AJob, APriority);
end;

function TuWorkers.RegisterWork(const AProc: TJobProcG; const APriority: TJobPriority;
  const AData: Pointer; const AOption: TJobDataOption): PTP_WORK;
var
  AJob: TGJob;
begin
  AJob := TGJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  Result := RegisterWork(AJob, APriority);
end;

function TuWorkers.RegisterWork(const AProc: TJobProcA; const APriority: TJobPriority;
  const AData: Pointer; const AOption: TJobDataOption): PTP_WORK;
var
  AJob: TAJob;
begin
  AJob := TAJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  Result := RegisterWork(AJob, APriority);
end;

function TuWorkers.PostWait(const AHandle: THandle; const ACallBack: PTP_WAIT_CALLBACK;
  const AContext: Pointer=nil; const ATimeout: Int64=0; const APriority: TJobPriority=jpNomal): PTP_WAIT;
var
  CBE: TP_CALLBACK_ENVIRON_V3;
begin
  InitCallBackEnviron(CBE, APriority, False);
  Result := CreateThreadpoolWait(ACallBack, AContext, @CBE);
  if Result<>nil then
    ModifyWait(Result, AHandle, ATimeout)
  else
    RaiseLastOSError;
end;

function TuWorkers.PostIO(const AHandle: THandle; const ACallback: PTP_WIN32_IO_CALLBACK;
  const AContext: Pointer=nil; const APriority: TJobPriority=jpNomal): PTP_IO;
var
  CBE: TP_CALLBACK_ENVIRON_V3;
begin
  InitCallBackEnviron(CBE, APriority, False);
  Result := CreateThreadpoolIo(AHandle, ACallback, AContext, @CBE);
  if Result=nil then
    RaiseLastOSError;
end;

function TuWorkers.&For(const AProc: TForJobProc; const AStart, AEnd: Integer;
  const AData: Pointer; const AOption: TJobDataOption): PTP_WORK;
var
  AJob: TMForJob;
begin
  AJob := TMForJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  Result := PostForWork(AJob, AStart, AEnd);
end;

function TuWorkers.&For(const AProc: TForJobProcG; const AStart,AEnd: Integer;
  const AData: Pointer; const AOption: TJobDataOption): PTP_WORK;
var
  AJob: TGForJob;
begin
  AJob := TGForJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  Result := PostForWork(AJob, AStart, AEnd);
end;

function TuWorkers.&For(const AProc: TForJobProcA; const AStart, AEnd: Integer;
  const AData: Pointer; const AOption: TJobDataOption): PTP_WORK;
var
  AJob: TAForJob;
begin
  AJob := TAForJob.Create(AData, AOption);
  AJob.fMethod := AProc;
  Result := PostForWork(AJob, AStart, AEnd);
end;
//------------------------------------------------------------------------------
class procedure TuWorkers.PostWork;
begin
  SubmitThreadpoolWork(AWork);
end;

class procedure TuWorkers.ModifyTimer;
var
  ATime: TFileTime;
begin
  ATime.dwHighDateTime := Int64Rec(AStartTime).Hi;
	ATime.dwLowDateTime := Int64Rec(AStartTime).Lo;
  SetThreadpoolTimer(ATimer, @ATime, AInterval, AWindowLength);
end;

class procedure TuWorkers.StopTimer;
begin
  SetThreadpoolTimer(ATimer, nil, 0, 0);
end;

class procedure TuWorkers.ModifyWait;
var
  ATime: TFileTime;
begin
  if ATimeout=0 then
    SetThreadpoolWait(AWait, AHandle, nil)
  else begin
    ATime.dwHighDateTime := Int64Rec(ATimeout).Hi;
	  ATime.dwLowDateTime := Int64Rec(ATimeout).Lo;
    SetThreadpoolWait(AWait, AHandle, @ATime);
  end;
end;

class procedure TuWorkers.StopWait;
begin
  SetThreadpoolWait(AWait, 0, nil);
end;

class function TuWorkers.DataTimeToUtcFileTime(const ATime: TDateTime): Int64;
var
  v1: TSystemTime;
  v2,v3: TFileTime;
begin
  DateTimeToSystemTime(ATime, v1);
  if SystemTimeToFileTime(v1, v2) and LocalFileTimeToFileTime(v2, v3) then
  begin
    Int64Rec(Result).Lo := v3.dwLowDateTime;
    Int64Rec(Result).Hi := v3.dwHighDateTime;
  end else RaiseLastOSError;
end;

//------------------------------------------------------------------------------

{ TuWorkers.TJob }

constructor TuWorkers.TJob.Create(const AData: Pointer; const AOption: TJobDataOption);
begin
  fData := AData;
  fOption := AOption;
end;

destructor TuWorkers.TJob.Destroy;
begin
  if (fData <> nil) and (fOption<>jdoNone) then
  begin
    try
      case fOption of
        jdoDataIsObject: TObject(fData).Free;
        jdoDataIsInterface: IInterface(fData)._Release;
        jdoDataIsSimpleRecord: Dispose(fData);
      end;
    except
      {Log}
    end;
  end;
  inherited;
end;

procedure TuWorkers.TJob.InvokeCallback;
begin
  try
    DoJob;
  except
    {Do Log }
  end;
end;

{ TuWorkers.TMJob }

procedure TuWorkers.TMJob.DoJob;
begin
  fMethod(fData);
end;

{ TuWorkers.TGJob }

procedure TuWorkers.TGJob.DoJob;
begin
  fMethod(fData);
end;

{ TuWorkers.TAJob }
procedure TuWorkers.TAJob.DoJob;
begin
  fMethod(fData);
end;

destructor TuWorkers.TAJob.Destroy;
begin
  fMethod := nil;
  inherited;
end;

{ TuWorkers.TForJob }

procedure TuWorkers.TForJob.DoJob;
var
  I: Int64;
  lBreaked: Boolean;
begin
  I := System.AtomicIncrement(FIterator);
  if I<=FStopIndex then
  begin
    //SetThreadIdealProcessor(GetCurrentThread, System.AtomicIncrement(FIdeal));
    repeat
      lBreaked := False;
      if fFlag>0 then Break;
      DoForJob(lBreaked, I);
      if lBreaked then
      begin
        System.AtomicIncrement(fFlag);
        Break;
      end;
      I := System.AtomicIncrement(FIterator);
    until I>FStopIndex;
  end;
end;

{ TuWorkers.TMForJob }

procedure TuWorkers.TMForJob.DoForJob;
begin
  fMethod(bBreaked, AIndex, fData);
end;

{ TuWorkers.TGForJob }

procedure TuWorkers.TGForJob.DoForJob;
begin
  fMethod(bBreaked, AIndex, fData);
end;

{ TuWorkers.TAForJob }

destructor TuWorkers.TAForJob.Destroy;
begin
  fMethod := nil;
  inherited;
end;

procedure TuWorkers.TAForJob.DoForJob;
begin
  fMethod(bBreaked, AIndex, fData);
end;

initialization

GWorkers := TuWorkers.Create;

finalization

GWorkers.Free;



end.
