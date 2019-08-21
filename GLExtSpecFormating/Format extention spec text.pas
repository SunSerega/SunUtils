﻿uses MiscUtils in '..\Utils\MiscUtils.pas';

begin
  try
    if System.IO.Directory.Exists('GLExtSpecFormating\gl ext spec') then System.IO.Directory.Delete('GLExtSpecFormating\gl ext spec',true);
    
    var fls := System.IO.Directory.EnumerateFiles('Reps\OpenGL-Registry\extensions', '*.txt', System.IO.SearchOption.AllDirectories).ToList;
    var done := 0;
    var start_time := DateTime.Now;
    
    System.Threading.Thread.Create(()->
    while true do
    begin
      var cdone := done;
      Otp($'Formating spec texts: {cdone/fls.Count:P}');
      if cdone=fls.Count then
      begin
        Otp($'Done in {DateTime.Now-start_time}');
        if not CommandLineArgs.Contains('SecondaryProc') then Readln;
        Halt;
      end;
      Sleep(500);
    end).Start;
    
    foreach var fname in fls.Shuffle do
    begin
      
      var text := ReadAllText(fname);
      text := text.Remove(#13).Replace(#9,' '*4);
      while text.Contains(' '#10) do text := text.Replace(' '#10, #10);
      text := text.Replace('New Procedures and'#10'Functions', 'New Procedures and Functions');
      
      var fname2 := fname.Replace('Reps\OpenGL-Registry\extension', 'GLExtSpecFormating\gl ext spec');
      System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(fname2));
      WriteAllText(fname2, text);
      
      done += 1;
    end;
    
  except
    on e: Exception do ErrOtp(e);
  end;
end.