﻿uses OpenCLABC;

begin
  var code := new ProgramCode(Context.Default, '__kernel void p1() { }');
  var k := code['p1'];
  
  k.NewQueue
  .ThenExec2(1,1,
    
    MemorySegmentCCQ.Create(HFQ(()->new MemorySegment(1)))
    .ThenQueue(HFQ(()->5))
    .ThenProc(ms->begin exit() end),
    
    5
  ).Println;
  
end.