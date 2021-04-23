(* ROM is connected to PPU and CPU *)
open Stdint

exception NotImplemented of string


(* 
Example of a ROM Header:

 ROM iNES - Super Mario (E)

 Header
 0-3: 0x4e 0x45 0x53 0x1A - "NES" followerd by MS-DOS end of file
 4  : 0x2                 - Size of the PRG ROM in 16KB units (32768 KB)
 5  : 0x1                 - Size of the CHR ROM in 8KB units (8192 KB)
 6  : 0x1                 - FLAGS - 1 means vertical mirroring
 7  : 0x0                 - FLAGS
 8  : 0x0                 - PRG-RAM size
 9  : 0x0                 - TV system
 10 : 0x0                 - TV system, PRG-RAM presence
 11-15 : 0x0              - Unused padding
*)

(* Rom type
  0 : NES 2.0
  1 : iNES
  2 : Archaic iNES
*)
type roms = 
 | Nes2
 | INes
 | ArchINes

let mapper_id = ref Uint8.zero
let num_prg_banks = ref Uint8.zero
let num_chr_banks = ref Uint8.zero
let pgr_memory = ref [|0x0|]
let chr_memory = ref [|0x0|]

module Header = struct
  let name = Array.make 4 0x0
  let pgr_rom_chunks = ref Uint8.zero
  let chr_rom_chunks = ref Uint8.zero
  let mapper1 = ref Uint8.zero
  let mapper2 = ref Uint8.zero
  let tv_system1 = ref Uint8.zero
  let tv_system2 = ref Uint8.zero
  let unused = Array.make 5 0x0
end

let load_header ic = 
  (* 1 - Read Name *)
  for i=0 to 3 do Header.name.(i) <- input_byte ic done;
  
  (* 2 - infos *)
  Header.pgr_rom_chunks := Uint8.of_int (input_byte ic);
  Header.chr_rom_chunks := Uint8.of_int (input_byte ic);
  Header.mapper1 := Uint8.of_int (input_byte ic);
  Header.mapper2 := Uint8.of_int (input_byte ic);
  Header.tv_system1 := Uint8.of_int (input_byte ic);
  Header.tv_system2 := Uint8.of_int (input_byte ic);

  (* 3 - Unused *)
  for i=0 to 4 do Header.unused.(i) <- input_byte ic done

let load_trainer ic =
  (* Ignore  the 512 bytes of the Trainer*)
  if (Uint8.logand !Header.mapper1 (Uint8.of_int 0x04)) <> Uint8.zero then
    for i=1 to 512 do  ignore(input_byte ic) done
    
let determine_mapper_id mapper1 mapper2 =
  let ( >> ) a b = Uint8.shift_right_logical a b in
  let ( << ) a b = Uint8.shift_left a b in  
  Uint8.logor ((mapper2 >> 4) << 4) (mapper1 >> 4)

let load_rom_banks ic = function
  | Nes2 -> 
    num_prg_banks := !Header.pgr_rom_chunks;
    pgr_memory := Array.make 16384 0x0; 
    for i=0 to 16384-1 do !pgr_memory.(i) <- input_byte ic done;
      
    num_chr_banks := !Header.chr_rom_chunks;
    chr_memory := Array.make 8192 0x0;
    for i=0 to 8192-1 do !chr_memory.(i) <- input_byte ic done;
  | INes -> raise (NotImplemented "load_rom_banks: Invalid ROM Format (INes)")
  | ArchINes -> raise (NotImplemented "load_rom_banks: Invalid ROM Format (ArchINes)")

(* Read file in binary mode *)
let read file = 
  let ic = open_in_bin file in
  try
    (* 1 - Load Header *)
    load_header ic;
    Printf.printf "header\n";

    (* 2 - Load Trainer*)
    load_trainer ic;
    Printf.printf "trainer\n";

    (* 3 - Determine mapper id *)
    mapper_id := determine_mapper_id !Header.mapper1 !Header.mapper2;
    Printf.printf "mapper_id\n";

    (* 4 - Determine file type 
      Todo: Implement the other formats *)
    let file_type = Nes2 in
    
    (* 5 - Load chr and pgr memory*)
    load_rom_banks ic file_type;
    Printf.printf "rom_banks\n";
    close_in ic
  with e -> close_in ic; raise End_of_file


(* Connections to BUS *)

(* CPU <-> BUS *)
let cpu_read address = assert false

let cpu_write address data = assert false

(* PPU <-> BUS *)
let ppu_read address = assert false

let ppu_write address data = assert false
