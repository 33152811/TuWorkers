{*****************************************************}
{*                          Winapi                   *}
{*                     Thread Pool API               *}
{*         Copyright(C) 2016-2017 TU2 QQ:245806497   *}
{*        Minimum supported client: Windows Vista    *}
{*    Minimum supported server: Windows Server 2008  *}
{*****************************************************}
unit Winapi.ThreadPool;

interface

uses Winapi.Windows;

type
  PTP_CALLBACK_INSTANCE = Pointer;
  PTP_POOL = Pointer;
  PTP_WORK = Pointer;
  PTP_TIMER = Pointer;
  PTP_WAIT = Pointer;
  PTP_IO = Pointer;
  PTP_CLEANUP_GROUP = Pointer;
  TP_WAIT_RESULT = DWORD;   //WAIT_OBJECT_0, WAIT_TIMEOUT, WAIT_ABANDONED_0

  PTP_SIMPLE_CALLBACK = procedure(Instance: PTP_CALLBACK_INSTANCE; Context: PVOID); stdcall;
  PTP_WORK_CALLBACK = procedure(Instance: PTP_CALLBACK_INSTANCE; Context: PVOID; Work: PTP_WORK); stdcall;
  PTP_TIMER_CALLBACK = procedure(Instance: PTP_CALLBACK_INSTANCE; Context: PVOID; Work: PTP_TIMER); stdcall;
  PTP_WAIT_CALLBACK = procedure(Instance: PTP_CALLBACK_INSTANCE; Context: PVOID; Work: PTP_WAIT; WaitResult: TP_WAIT_RESULT); stdcall;
  PTP_WIN32_IO_CALLBACK = procedure(Instance: PTP_CALLBACK_INSTANCE; Context, Overlapped: PVOID; IoResult: ULONG; NumberOfBytesTransferred: ULONG_PTR; Io: PTP_IO); stdcall;
  PTP_CLEANUP_GROUP_CANCEL_CALLBACK = procedure(ObjectContext,CleanupContext: PVOID); stdcall;

  PTP_CALLBACK_ENVIRON = ^TP_CALLBACK_ENVIRON_V3;

  TP_CALLBACK_ENVIRON_V3_U_S = packed record
    case Integer of
      0: (LongFunction: DWORD);  //1
      1: (Persistent: DWORD);    //1
      2: (dwPrivate: DWORD);     //30
  end;

  TP_CALLBACK_ENVIRON_V3_U = packed record
    case Integer of
      0: (Flags: DWORD);
      1: (s: TP_CALLBACK_ENVIRON_V3_U_S);
  end;

  TCallbackPriority = (
    TP_CALLBACK_PRIORITY_HIGH,
    TP_CALLBACK_PRIORITY_NORMAL,
    TP_CALLBACK_PRIORITY_LOW
    //,TP_CALLBACK_PRIORITY_INVALID,
    //TP_CALLBACK_PRIORITY_COUNT = TP_CALLBACK_PRIORITY_INVALID
    );

  TP_CALLBACK_ENVIRON_V3 = record
    Version: DWORD;
    Pool: PTPPool;
    CleanupGroup: PTP_CLEANUP_GROUP;
    CleanupGroupCancelCallback: PTP_CLEANUP_GROUP_CANCEL_CALLBACK;
    RaceDll: PVOID;
    ActivationContext: Pointer; //_ACTIVATION_CONTEXT *
    FinalizationCallback: PTP_SIMPLE_CALLBACK;
    u: TP_CALLBACK_ENVIRON_V3_U;
    CallbackPriority: TCallbackPriority;
    Size: DWORD;
  end;

  function  CreateThreadpool(reserved: Pointer = nil): PTPPool; stdcall;
  procedure CloseThreadpool(ptpp: PTPPool); stdcall;
  procedure SetThreadpoolThreadMaximum(ptpp: PTPPool; cthrdMost: DWORD); stdcall;
  function  SetThreadpoolThreadMinimum(ptpp: PTPPool; cthrdMin: DWORD): BOOL; stdcall;
  function  CreateThreadpoolCleanupGroup: PTP_CLEANUP_GROUP; stdcall;
  procedure CloseThreadpoolCleanupGroup(ptpcg: PTP_CLEANUP_GROUP); stdcall;
  procedure CloseThreadpoolCleanupGroupMembers(ptpcg: PTP_CLEANUP_GROUP; bCancelPendingCallbacks: BOOL; pvCleanupContext: PVOID); stdcall;
  function  TrySubmitThreadpoolCallback(pfns: PTP_SIMPLE_CALLBACK; pv: PVOID; pcbe: PTP_CALLBACK_ENVIRON=nil): BOOL; stdcall;

  function  CreateThreadpoolWork(pfnwk: PTP_WORK_CALLBACK; pv: PVOID; pcbe: PTP_CALLBACK_ENVIRON=nil): PTP_WORK; stdcall;
  procedure CloseThreadpoolWork(pwk: PTP_WORK); stdcall;
  procedure SubmitThreadpoolWork(pwk: PTP_WORK); stdcall;
  procedure WaitForThreadpoolWorkCallbacks(pwk: PTP_WORK; fCancelPendingCallbacks: BOOL); stdcall;

  function  CreateThreadpoolTimer(pfnti: PTP_TIMER_CALLBACK; pv: PVOID; pcbe: PTP_CALLBACK_ENVIRON=nil): PTP_TIMER; stdcall;
  procedure CloseThreadpoolTimer(pwk: PTP_WORK); stdcall;
  function  IsThreadpoolTimerSet(pti: PTP_TIMER): BOOL; stdcall;
  procedure SetThreadpoolTimer(pti: PTP_TIMER; pftDueTime: PFileTime; msPeriod: DWORD; msWindowLength: DWORD); stdcall;
  procedure WaitForThreadpoolTimerCallbacks(pwk: PTP_TIMER; fCancelPendingCallbacks: BOOL); stdcall;

  function  CreateThreadpoolWait(pfnwa: PTP_WAIT_CALLBACK; pv: PVOID; pcbe: PTP_CALLBACK_ENVIRON=nil): PTP_WAIT; stdcall;
  procedure CloseThreadpoolWait(pwa: PTP_WAIT); stdcall;
  procedure SetThreadpoolWait(pwa: PTP_WAIT; h: THANDLE; pftTimeout: PFileTime); stdcall;
  procedure WaitForThreadpoolWaitCallbacks(pwa: PTP_WAIT; fCancelPendingCallbacks: BOOL); stdcall;

  function  CreateThreadpoolIo(f1: THandle; pfnio: PTP_WIN32_IO_CALLBACK; pv: PVOID; pcbe: PTP_CALLBACK_ENVIRON=nil): PTP_IO; stdcall;
  procedure CloseThreadpoolIo(pio: PTP_IO); stdcall;
  procedure StartThreadpoolIo(pio: PTP_IO); stdcall;
  procedure CancelThreadpoolIo(pio: PTP_IO); stdcall;
  procedure WaitForThreadpoolIoCallbacks(pio: PTP_IO; fCancelPendingCallbacks: BOOL); stdcall;

  procedure LeaveCriticalSectionWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; pcs: PRTLCriticalSection); stdcall;
  procedure ReleaseMutexWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; mut: THandle); stdcall;
  procedure ReleaseSemaphoreWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; sem: THandle; crel: DWORD); stdcall;
  procedure SetEventWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; evt: THandle); stdcall;
  procedure FreeLibraryWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; hMod: HMODULE); stdcall;
  procedure DisassociateCurrentThreadFromCallback(pci: PTP_CALLBACK_INSTANCE); stdcall;
  function  CallbackMayRunLong(pci: PTP_CALLBACK_INSTANCE): BOOL; stdcall;

implementation

function  CreateThreadpool; external kernel32;
procedure CloseThreadpool; external kernel32;
procedure SetThreadpoolThreadMaximum; external kernel32;
function  SetThreadpoolThreadMinimum; external kernel32;
function  CreateThreadpoolCleanupGroup; external kernel32;
procedure CloseThreadpoolCleanupGroup; external kernel32;
procedure CloseThreadpoolCleanupGroupMembers; external kernel32;
function  TrySubmitThreadpoolCallback; external kernel32;

function  CreateThreadpoolWork; external kernel32;
procedure CloseThreadpoolWork; external kernel32;
procedure SubmitThreadpoolWork; external kernel32;
procedure WaitForThreadpoolWorkCallbacks; external kernel32;

function CreateThreadpoolTimer; external kernel32;
procedure CloseThreadpoolTimer; external kernel32;
function IsThreadpoolTimerSet; external kernel32;
procedure SetThreadpoolTimer; external kernel32;
procedure WaitForThreadpoolTimerCallbacks; external kernel32;

function CreateThreadpoolWait; external kernel32;
procedure CloseThreadpoolWait; external kernel32;
procedure SetThreadpoolWait; external kernel32;
procedure WaitForThreadpoolWaitCallbacks; external kernel32;

function CreateThreadpoolIo; external kernel32;
procedure CloseThreadpoolIo; external kernel32;
procedure StartThreadpoolIo; external kernel32;
procedure CancelThreadpoolIo; external kernel32;
procedure WaitForThreadpoolIoCallbacks; external kernel32;

procedure LeaveCriticalSectionWhenCallbackReturns; external kernel32;
procedure ReleaseMutexWhenCallbackReturns; external kernel32;
procedure ReleaseSemaphoreWhenCallbackReturns; external kernel32;
procedure SetEventWhenCallbackReturns; external kernel32;
procedure FreeLibraryWhenCallbackReturns; external kernel32;
procedure DisassociateCurrentThreadFromCallback; external kernel32;
function  CallbackMayRunLong; external kernel32;

end.
