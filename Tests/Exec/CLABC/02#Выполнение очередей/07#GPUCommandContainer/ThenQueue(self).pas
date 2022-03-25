## uses OpenCLABC;

var q := MemorySegment.Create(1).NewQueue
  .ThenQuickProc(mem->Writeln(1))
  .ThenQuickProc(mem->Writeln(2))
;

Context.Default.SyncInvoke(
  q.ThenQueue(q)
);