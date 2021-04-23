(* 
Module BUS

the bus connects the CPU to the rest of the componentes 
*)

open Stdint

exception InvalidAddress of string

(* RAM *) 
let ram = Array.make 2048 Uint8.zero

let cpu_read address = match Uint16.to_int address with
 | address when 0x0000 <= address && address <= 0x1FFF -> ram.(address land 0x07FF)
 | address when 0x2000 <= address && address <= 0x3FFF -> Ppu.cpu_read (address land 0x0007)
 | x -> raise (InvalidAddress ("Reading from Invalid Address "^ string_of_int x))

let cpu_write address data = match Uint16.to_int address with  
 | address when 0x0000 <= address && address <= 0x1FFF -> ram.(address land 0x07FF) <- data
 | address when 0x2000 <= address && address <= 0x3FFF -> Ppu.cpu_write (address land 0x0007) data
 | x -> raise (InvalidAddress ("Writing Invalid Address "^ string_of_int x))
