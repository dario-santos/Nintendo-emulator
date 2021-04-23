open Stdint

let _ = Printf.printf "Starting to Load ROM\n"
let _ = Rom.read "smb.nes"
let _ = Printf.printf "Completed ROM Loading\n"


let _ = Bus.cpu_read (Uint16.of_int 2)

(*let _ =
  Sdl.init [`VIDEO];
  let width, height = (320, 240) in
  let _ = Sdlwindow.create2 ~title:"NesML v0.0.0.0.0.1 - DT" ~x:`undefined ~y:`undefined ~width ~height ~flags:[] in

  Cpu.initialize ();
  
  (Sdltimer.delay ~ms: 10000);
  Sdl.quit ()*)
  