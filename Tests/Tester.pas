﻿uses MiscUtils in '..\Utils\MiscUtils.pas';

{$reference System.Windows.Forms.dll}
type MessageBox = System.Windows.Forms.MessageBox;
type MessageBoxButtons = System.Windows.Forms.MessageBoxButtons;
type MessageBoxIcon = System.Windows.Forms.MessageBoxIcon;
type MessageBoxDefaultButton = System.Windows.Forms.MessageBoxDefaultButton;
type DialogResult = System.Windows.Forms.DialogResult;

{ $define SingleThread}
{$define WriteDone}

///Result=True когда времени не хватило
function TimedExecute(p: procedure; t: integer): boolean;
begin
  {$ifndef SingleThread}
  var res := false;
  
  var exec_thr := ProcTask(p).StartExec;
  var stop_thr := ProcTask(()->
  begin
    Sleep(t);
    exec_thr.Abort;
    res := true;
  end).StartExec;
  
  exec_thr.Join;
  stop_thr.Abort;
  
  Result := res;
  {$else}
  p;
  Result := false;
  {$endif}
end;

type
  TestCanceledException = class(Exception) end;
  
  CompTester = class
    expected_comp_err: string;
    
    settings := new Dictionary<string, string>;
    used_settings := new HashSet<string>;
    
    constructor;
    begin
      used_settings += '#SkipTest';
      used_settings += '#ExpErr';
    end;
    
    procedure LoadSettings(pas_fname, td_fname: string); virtual;
    begin
      
      if not System.IO.File.Exists(td_fname) then
      begin
        if ReadLines(pas_fname).Take(1).SingleOrDefault(l->l.StartsWith('unit'))<>nil then
        begin
          WriteAllText(td_fname, '#SkipTest', new System.Text.UTF8Encoding(true));
          raise new TestCanceledException;
        end;
        
        case MessageBox.Show($'File {td_fname} not found'+#10'Mark .pas file as test-ignored?', 'New .pas file', MessageBoxButtons.YesNoCancel, MessageBoxIcon.Exclamation, MessageBoxDefaultButton.Button2) of
          
          DialogResult.Yes:
          begin
            WriteAllText(td_fname, '#SkipTest', new System.Text.UTF8Encoding(true));
            raise new TestCanceledException;
          end;
          
          DialogResult.No: WriteAllText(td_fname, '', new System.Text.UTF8Encoding(true));
          
          DialogResult.Cancel: Halt;
        end;
        
      end;
      
      var lns := ReadAllLines(td_fname);
      
      var i := -1;
      while true do
      begin
        i += 1;
        if i >= lns.Length then break;
        var s := lns[i];
        if not s.StartsWith('#') then continue;
        
        var sb := new StringBuilder;
        var key := s;
        while true do
        begin
          i += 1;
          if i = lns.Length then break;
          s := lns[i];
          
          if s.StartsWith('#') then
          begin
            i -= 1;
            break;
          end;
          
          sb += s;
          sb += #10;
          
        end;
        
        settings.Add(key, sb.ToString.TrimEnd(#10).Replace('\#','#'));
      end;
      
      if settings.ContainsKey('#SkipTest') then raise new TestCanceledException;
      
      if not settings.TryGetValue('#ExpErr', expected_comp_err) then expected_comp_err := nil;
      
    end;
    
    procedure Test(pas_fname, td_fname: string); virtual;
    begin
//      $'"{System.IO.Path.GetFullPath(pas_fname)}" cd="{MainFolder}" OutDir="{System.IO.Path.GetFullPath(System.IO.Path.GetDirectoryName(pas_fname))}"'.Println;
      
      var err_found := false;
      CompilePasFile(pas_fname, Otp, res->
      begin
        err_found := true;
        
        if expected_comp_err=nil then
          case MessageBox.Show($'In "{pas_fname}":{#10*2}{res}{#10*2}Add this to expected errors?', 'Unexpected error', MessageBoxButtons.YesNoCancel) of
            
            DialogResult.Yes:
            begin
              settings['#ExpErr'] := res;
              Otp($'%WARNING: settings updated for "{pas_fname}"');
            end;
            
            DialogResult.Cancel: Halt;
          end else
          if expected_comp_err<>res then
          case MessageBox.Show($'In "{pas_fname}"{#10}Expected:{#10*2}{expected_comp_err}{#10*2}Current error:{#10*2}{res}{#10*2}Replace expected error?', 'Wrong error', MessageBoxButtons.YesNoCancel) of
            
            DialogResult.Yes:
            begin
              settings['#ExpErr'] := res;
              Otp($'%WARNING: settings updated for "{pas_fname}"');
            end;
            
            DialogResult.Cancel: Halt;
          end;
        
      end);
      
      if (expected_comp_err<>nil) and not err_found then
        case MessageBox.Show($'In "{pas_fname}"{#10}Expected:{#10*2}{expected_comp_err}{#10*2}Remove error from expected?', 'Error expected', MessageBoxButtons.YesNoCancel) of
          
          DialogResult.Yes:
          begin
            settings.Remove('#ExpErr');
            Otp($'%WARNING: settings updated for "{pas_fname}"');
          end;
          
          DialogResult.Cancel: Halt;
        end;
      
    end;
    
    procedure SaveSettings(fname: string);
    begin
      var res := new StringBuilder;
      res += #10;
      
      foreach var kvp in settings do
        if used_settings.Contains(kvp.Key) then
        begin
          res += kvp.Key;
          res += #10;
          res += kvp.Value.Replace('#','\#');
          res += #10;
        end else
          Otp($'WARNING: setting {kvp.Key} was deleted from "{fname}"');
      
      var st := res.ToString;
      if ReadAllText(fname, new System.Text.UTF8Encoding(true)) <> st then
      begin
        WriteAllText(fname, st, new System.Text.UTF8Encoding(true));
        Otp($'WARNING: settings were resaved in "{fname}"');
      end;
    end;
    
    
    
    static procedure TestAll(path: string; get_tester: ()->CompTester);
    begin
      {$ifndef SingleThread}
      RegisterThr;
      {$endif SingleThread}
      
      foreach var dir in System.IO.Directory.EnumerateDirectories(path, '*.*', System.IO.SearchOption.AllDirectories).Prepend(path) do
      begin
        System.IO.File.Copy( 'OpenCL.pcu',    dir+'\OpenCL.pcu',    true );
        System.IO.File.Copy( 'OpenCLABC.pcu', dir+'\OpenCLABC.pcu', true );
        System.IO.File.Copy( 'OpenGL.pcu',    dir+'\OpenGL.pcu',    true );
        System.IO.File.Copy( 'OpenGLABC.pcu', dir+'\OpenGLABC.pcu', true );
      end;
      
      var procs :=
        System.IO.Directory.EnumerateFiles(
          path, '*.pas', System.IO.SearchOption.AllDirectories
        ).Select&<string,()->()>(pas_fname->()->
        try
          {$ifndef SingleThread}
          RegisterThr;
          {$endif SingleThread}
          if pas_fname.EndsWith('OpenCL.pas') then exit;
          if pas_fname.EndsWith('OpenCLABC.pas') then exit;
          if pas_fname.EndsWith('OpenGL.pas') then exit;
          if pas_fname.EndsWith('OpenGLABC.pas') then exit;
          
//          {$ifdef WriteDone}
//          Otp($'STARTED: "{pas_fname}"');
//          {$endif WriteDone}
          
          var tester: CompTester := get_tester();
          var td_fname := pas_fname.Remove(pas_fname.LastIndexOf('.')) + '.td';
          
          tester.LoadSettings(pas_fname, td_fname);
          tester.Test(pas_fname, td_fname);
          
          tester.SaveSettings(td_fname);
          
          {$ifdef WriteDone}
          Otp($'DONE: "{pas_fname}"');
//          Readln;
          {$endif WriteDone}
          
        except
          on e: TestCanceledException do;
          on e: Exception do ErrOtp(e);
        end)
        .ToArray
      ;
      
      {$ifdef SingleThread}
      foreach var proc in procs do proc;
      {$else SingleThread}
      System.Threading.Tasks.Parallel.Invoke(procs);
      {$endif SingleThread}
      
      foreach var fname in System.IO.Directory.EnumerateDirectories(path, '*.*', System.IO.SearchOption.AllDirectories).Prepend(path) do
      begin
        System.IO.File.Delete(fname+'\OpenCL.pcu');
        System.IO.File.Delete(fname+'\OpenCLABC.pcu');
        System.IO.File.Delete(fname+'\OpenGL.pcu');
        System.IO.File.Delete(fname+'\OpenGLABC.pcu');
      end;
      
    end;
    
    static procedure TestAll :=
    TestAll('Tests\Comp', ()->new CompTester);
    
    static procedure TestExamples :=
    TestAll('Samples', ()->new CompTester);
    
  end;
  
  ExecTester = class(CompTester)
    expected_otp: string;
    
    constructor;
    begin
      used_settings += '#ExpOtp';
    end;
    
    procedure LoadSettings(pas_fname, td_fname: string); override;
    begin
      inherited LoadSettings(pas_fname, td_fname);
      
      if expected_comp_err<>nil then Otp($'WARNING: compile error is expected in Exec test "{pas_fname}"');
      
      if not settings.TryGetValue('#ExpOtp', expected_otp) then expected_otp := nil;
      
    end;
    
    procedure Test(pas_fname, td_fname: string); override;
    begin
      inherited Test(pas_fname, td_fname);
      var fwoe := pas_fname.Remove(pas_fname.LastIndexOf('.'));
      
      var res_sb := new StringBuilder;
      if TimedExecute(()->RunFile(fwoe+'.exe', $'Testable[{fwoe}]', s->res_sb.AppendLine(s)), 5000) then
      begin
        Otp($'ERROR: execution took too long for "{pas_fname}"');
        raise new TestCanceledException;
      end;
      
      var res := res_sb.ToString.Remove(#13).Trim(#10);
      if expected_otp=nil then
      begin
        settings['#ExpOtp'] := res;
        Otp($'WARNING: settings updated for "{pas_fname}"');
      end else
      if expected_otp<>res then
      begin
//        Otp($'{expected_otp.Length} : {otp.Length}');
//        expected_otp.ZipTuple(otp)
//        .Select(t->(word(t[0]), word(t[1])))
//        .PrintLines;
//        halt;
        
        case MessageBox.Show($'In "{pas_fname}"{#10}Expected:{#10*2}{expected_otp}{#10*2}Current output:{#10*2}{res}{#10*2}Replace expected output?', 'Wrong output', MessageBoxButtons.YesNoCancel) of
          
          DialogResult.Yes:
          begin
            settings['#ExpOtp'] := res;
            Otp($'%WARNING: settings updated for "{pas_fname}"');
          end;
          
          DialogResult.Cancel: Halt;
        end;
      end;
      
    end;
    
    
    
    static procedure TestAll :=
    TestAll('Tests\Exec', ()->new ExecTester);
    
  end;

begin
  
  try
    if System.Environment.CurrentDirectory.EndsWith('Tests') then
      System.Environment.CurrentDirectory := System.IO.Path.GetDirectoryName(System.Environment.CurrentDirectory);
    
    {$ifdef SingleThread}
    CompTester.TestExamples;
    CompTester.TestAll;
    ExecTester.TestAll;
    {$else SingleThread}
    System.Threading.Tasks.Parallel.Invoke(
      CompTester.TestExamples,
      CompTester.TestAll,
      ExecTester.TestAll
    );
    {$endif SingleThread}
    
    Otp('Done testing');
    
  except
    on e: Exception do ErrOtp(e);
  end;
  
  if not CommandLineArgs.Contains('SecondaryProc') then ReadlnString('Press Enter to exit');
end.