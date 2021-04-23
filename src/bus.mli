(* 
Module BUS

the bus connects the CPU to the rest of the componentes
*)
open Stdint

(** `read address` reads data from indicated address **)
val cpu_read: uint16 -> uint8

(** `write address data` writes data to address **)
val cpu_write: uint16 -> uint8 -> unit
