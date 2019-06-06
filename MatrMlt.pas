﻿uses OpenCLABC;

const
  MatrW = 4; // можно поменять на любое положительное значение
  
  VecByteSize = MatrW*8;
  MatrL = MatrW*MatrW;
  MatrByteSize = MatrL*8;
  
//ToDo issue компилятора:
// - #1533

begin
  Randomize(0);
  
  // Чтение и компиляция .cl файла
  
  {$resource MatrMlt.cl}
  var code := new ProgramCode(Context.Default,
    System.IO.StreamReader.Create(GetResourceStream('MatrMlt.cl')).ReadToEnd
  );
  
  // Подготовка параметров
  
  'Матрица A:'.Println;
  var A_Mart := MatrRandomReal(MatrW,MatrW,0,1).Println;
  writeln;
  var A := new KernelArg(MatrByteSize);
  
  'Матрица B:'.Println;
  var B_Mart := MatrRandomReal(MatrW,MatrW,0,1).Println;
  writeln;
  var B := new KernelArg(MatrByteSize);
  
  var C := new KernelArg(MatrByteSize);
  
  'Вектор V1:'.Println;
  var V1_Arr := ArrRandomReal(MatrW);
  V1_Arr.Println;
  writeln;
  var V1 := new KernelArg(VecByteSize);
  
  var V2 := new KernelArg(VecByteSize);
  
  // (запись значений в параметры - позже, в очередях)
  
  // Подготовка очередей выполнения
  
  var Calc_C_Q :=
    code['MatrMltMatr'].NewQueue.Exec(MatrW, MatrW,
      A.NewQueue.WriteData(A_Mart) as CommandQueue<KernelArg>,
      B.NewQueue.WriteData(B_Mart) as CommandQueue<KernelArg>,
      C,
      KernelArg.ValueQueue(MatrW) as CommandQueue<KernelArg>
    ) as CommandQueue<Kernel>;
  
  var Otp_C_Q :=
    HFQ(
      ()->
      begin
        Result := C.GetArray&<array[,] of real>(MatrW,MatrW);
        lock output do
        begin
          'Матрица С = A*B:'.Println;
          Result.Println;
          writeln;
        end;
      end
    ) as CommandQueue<array[,] of real>;
  
  var Calc_V2_Q :=
    code['MatrMltVec'].NewQueue.Exec(MatrW,
      C,
      V1.NewQueue.WriteData(V1_Arr) as CommandQueue<KernelArg>,
      V2,
      KernelArg.ValueQueue(MatrW) as CommandQueue<KernelArg>
    ) as CommandQueue<Kernel>;
  
  var Otp_V2_Q :=
    HFQ(
      ()->
      begin
        Result := V2.GetArray&<array of real>(MatrW);
        lock output do
        begin
          'Вектор V2 = C*V1:'.Println;
          Result.Println;
          writeln;
        end;
      end
    ) as CommandQueue<array of real>;
  
  // Выполнение всего и сразу асинхронный вывод
  
  Context.Default.SyncInvoke(
    
    Calc_C_Q +
    (
      Otp_C_Q *
      (
        Calc_V2_Q +
        Otp_V2_Q
      )
    )
    
  );
  
end.