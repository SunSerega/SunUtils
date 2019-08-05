﻿uses OpenCLABC;

begin
  var b := new Buffer( 3*sizeof(integer) ); //Буфер достаточного размера чтоб содержать 3 значений типа integer. 
  
  // Создаём очередь
  var q := b.NewQueue;
  
  // Добавлять команды в полученную очередь можно вызывая соответствующие методы
  q.WriteValue(1, 0*sizeof(integer) );
  
  // Методы, добавляющие команду в очередь - возвращают саму же очередь (не копию а ссылку на оригинал)
  // Поэтому можно добавлять по несколько команд в 1 строчке:
  q.WriteValue(5, 1*sizeof(integer) ).WriteValue(7, 2*sizeof(integer) );
  // Все команды в q будут выполнятся последовательно, что не всегда хорошо
  // Если надо выполнять параллельно - создавайте отдельные очереди и умножайте друг на друга
  
  // В данной версии надо писать "as CommandQueue<...>", при передаче очереди куда-либо, из за бага компилятора
  Context.Default.SyncInvoke(q as CommandQueue<Buffer>);
  
  b.GetArray1&<integer>(3).Println;
  
end.