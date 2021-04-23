open Stdint

exception InvalidOpcode of string

(* == Registers == *)
(* 8 bit registers *)
let a : uint8 ref = ref Uint8.zero (* Accumulator*)
let x : uint8 ref = ref Uint8.zero (* Index X *)
let y : uint8 ref = ref Uint8.zero (* Index Y *)

(* Stack Pointer - 8 bits
The stack pointer works top-down, when a byte is pushed it is decremented,
when a byte is pulled the stack pointer is incremented.
There is no detection of stack overflow and the stack pointer 
will just wrap around from $00 to $FF. *)
let sp : uint8 ref = ref Uint8.zero

(* Program Counter - 16 bits *)
let pc : uint16 ref = ref Uint16.zero


(* Status Register - 8 bits
 6 bits are used byte the Arithmetic Logic Unit (ALU)
 +-+-+-+-+-+-+-+-+
 |N|V|U|B|D|I|Z|C|
 +-+-+-+-+-+-+-+-+
 7 6 5 4 3 2 1 0
*)
let status : uint8 ref = ref Uint8.zero

type flags = 
  | C (* Carry Bit *)
  | Z (* Zero *)
  | I (* Disable Interrupts *)
  | D (* Decimal Mode *)
  | B (* Break *)
  | U (* Undefined*)
  | V (* Overflow *)
  | N (* Negative *)

let fetched = ref Uint8.zero

let address_abs = ref Uint16.zero
let address_rel = ref Uint16.zero
let opcode = ref Uint8.zero
let cycles = ref 0

let initialize () =  
  a  := Uint8.zero;
  x  := Uint8.zero;
  y  := Uint8.zero;
  sp := Uint8.of_int 0x01FF;
  pc := Uint16.of_int 0xC000;
  status  := Uint8.zero

let read address = Bus.cpu_read address

let write address data = Bus.cpu_write address data

(** Adressing Modes **)
module AddrsMode = struct
  type modes = Imp | Imm | Zp0 | Zpx | Zpy | Abs | Abx | Aby | Ind | Izx | Izy | Rel

  (* Implied *)
  let imp () = 
    fetched := !a; 
    0
  
  (* Immediate *)
  let imm () =
    address_abs := !pc;
    pc := Uint16.(!pc + Uint16.one);
    0

  (* Zero page *)
  let zp0 () =
    address_abs := Uint16.of_uint8(read !pc);
    pc := Uint16.(!pc + Uint16.one);
    address_abs := Uint16.logand !address_abs (Uint16.of_int 0x00FF);
    0

  (* Zero page x *)
  let zpx () =
    address_abs := Uint16.of_uint8(Uint8.((read !pc) + !x));
    pc := Uint16.(!pc + Uint16.one);
    address_abs := Uint16.logand !address_abs (Uint16.of_int 0x00FF);
    0

  (* Zero page y *)
  let zpy () = 
    address_abs := Uint16.of_uint8(Uint8.((read !pc) + !y));
    pc := Uint16.(!pc + Uint16.one);
    address_abs := Uint16.logand !address_abs (Uint16.of_int 0x00FF);
    0
  
  (* Absolute *)
  let abs () =
    let ( << ) a b = Uint16.of_int( a lsl b) in

    let low = Uint16.of_uint8(read !pc) in
    pc := Uint16.(!pc + Uint16.one);
    let high = Uint8.to_int(read !pc) in
    pc := Uint16.(!pc + Uint16.one);

    address_abs := Uint16.logor (high << 8) low;
    0
    

  (* Absolute x *)
  let abx () = 
    let ( << ) a b = Uint16.of_int( a lsl b) in

    let low = Uint16.of_uint8(read !pc) in
    pc := Uint16.(!pc + Uint16.one);
    let high = Uint8.to_int(read !pc) in
    pc := Uint16.(!pc + Uint16.one);

    address_abs := Uint16.logor (high << 8) low;
    address_abs := Uint16.(!address_abs + (Uint16.of_uint8 !x));
    
    if (high << 8) <> Uint16.logand !address_abs (Uint16.of_int 0xFF00) then 
      1
    else 
      0

  (* Absolute y *)
  let aby () =
    let ( << ) a b = Uint16.of_int( a lsl b) in

    let low = Uint16.of_uint8(read !pc) in
    pc := Uint16.(!pc + Uint16.one);
    let high = Uint8.to_int(read !pc) in
    pc := Uint16.(!pc + Uint16.one);

    address_abs := Uint16.logor (high << 8) low;
    address_abs := Uint16.(!address_abs + (Uint16.of_uint8 !y));
    
    if (high << 8) <> Uint16.logand !address_abs (Uint16.of_int 0xFF00) then 
      1
    else 
      0

  (* Indirect *)
  let ind () = 
    let ( << ) a b = Uint16.of_int( a lsl b) in

    let ptr_low = Uint16.of_uint8(read !pc) in
    pc := Uint16.(!pc + Uint16.one);
    let ptr_high = Uint8.to_int(read !pc) in
    pc := Uint16.(!pc + Uint16.one);

    let ptr = Uint16.logor (ptr_high << 8) ptr_low in

    let low = Uint16.of_uint8(read ptr) in
    let high = Uint8.to_int(read Uint16.(ptr + Uint16.one)) in

    (* Don't change page if ptr_low = 0x00FF *)
    (if ptr_low = (Uint16.of_int 0xFF) then
     address_abs := Uint16.logor (Uint16.logand (high << 8) (Uint16.of_int 0xFF00)) low
    else 
      address_abs := Uint16.logor (high << 8) low);
    0


  (* Indirect Zero Page X *)
  let izx () = 
    let ( << ) a b = Uint16.of_int(a lsl b) in

    let tmp = Uint16.of_uint8(read !pc) in
    pc := Uint16.(!pc + Uint16.one);

    let low = Uint16.of_uint8(
      read (Uint16.logand Uint16.(tmp + (Uint16.of_uint8 !x)) (Uint16.of_int 0x00FF))      
    ) in
    
    let high = Uint8.to_int(
      read (Uint16.logand Uint16.(tmp + (Uint16.of_uint8 !x) + Uint16.one) (Uint16.of_int 0x00FF))      
    ) in
    
    address_abs := Uint16.logor (high << 8) low;
    0
  
  (* Indirect Zero Page Y *)
  let izy () = 
    let ( << ) a b = Uint16.of_int(a lsl b) in

    let tmp = Uint16.of_uint8(read !pc) in
    pc := Uint16.(!pc + Uint16.one);

    let low = Uint16.of_uint8(
      read (Uint16.logand tmp (Uint16.of_int 0x00FF))      
    ) in
    
    let high = Uint8.to_int(
      read (Uint16.logand Uint16.(tmp + Uint16.one) (Uint16.of_int 0x00FF))      
    ) in
    
    address_abs := Uint16.logor (high << 8) low;
    address_abs := Uint16.(!address_abs + (Uint16.of_uint8 !y));

    if (high << 8) <> Uint16.logand !address_abs (Uint16.of_int 0xFF00) then 
      1
    else 
      0
  

  (* Relative *)
  let rel () = 
    address_rel := !pc;
    pc := Uint16.(!pc + Uint16.one);

    if Uint16.logand !address_rel (Uint16.of_int 0x80) <> Uint16.zero then
      address_rel := Uint16.logor !address_rel (Uint16.of_int 0xFF00);
    0
  
  
  let access = function
    | Imp -> imp ()
    | Imm -> imm ()
    | Zp0 -> zp0 ()
    | Zpx -> zpx ()
    | Zpy -> zpy ()
    | Abs -> abs ()
    | Abx -> abx ()
    | Aby -> aby ()
    | Ind -> ind ()
    | Izx -> izx ()
    | Izy -> izy ()
    | Rel -> rel ()
end

type instruction = { 
  name     : string;
  operate  : unit -> int;
  addrmode : AddrsMode.modes;
  cicles   : int;
}

(** Instruction set **)
let rec reset () =
  let ( << ) a b = Uint16.shift_left a b in
  a  := Uint8.zero;
  x  := Uint8.zero;
  y  := Uint8.zero;
  sp := Uint8.of_int 0xFD;
  status := Uint8.logor (Uint8.of_int 0x00) (get_flag U);
  address_abs := Uint16.of_int 0xFFFC;
  let lo = Uint16.of_uint8 (read !address_abs) in
  let hi = Uint16.of_uint8 (read Uint16.(!address_abs + Uint16.one)) in
  
  pc := Uint16.logor (hi << 8) lo;
  address_rel := Uint16.zero;
  address_abs := Uint16.zero;
  fetched := Uint8.zero;
  
  cycles := 8
  
and irq () =
  let ( << ) a b = Uint16.shift_left a b in
  let ( >> ) a b = Uint16.shift_right a b in
  if (get_flag I) = Uint8.zero then
  (
    write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) (Uint8.of_uint16 (Uint16.logand (!pc >> 8) (Uint16.of_int 0x00FF)));
    sp := Uint8.(!sp - Uint8.one);
    write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) (Uint8.of_uint16 (Uint16.logand !pc (Uint16.of_int 0x00FF)));
    sp := Uint8.(!sp - Uint8.one);
    
    set_flag B false;
    set_flag U true;
    set_flag I true;
    
    write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) !status;
    sp := Uint8.(!sp - Uint8.one);
    
    address_abs := Uint16.of_int 0xFFFE;
    let lo = Uint16.of_uint8 (read !address_abs) in
    let hi = Uint16.of_uint8 (read Uint16.(!address_abs + Uint16.one)) in
    pc := Uint16.logor (hi << 8) lo;

    cycles := 7;
  )

and nmi () =
  let ( << ) a b = Uint16.shift_left a b in
  let ( >> ) a b = Uint16.shift_right a b in

  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) (Uint8.of_uint16 (Uint16.logand (!pc >> 8) (Uint16.of_int 0x00FF)));
  sp := Uint8.(!sp - Uint8.one);
  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) (Uint8.of_uint16 (Uint16.logand !pc (Uint16.of_int 0x00FF)));
  sp := Uint8.(!sp - Uint8.one);
    
  set_flag B false;
  set_flag U true;
  set_flag I true;
  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) !status;
  sp := Uint8.(!sp - Uint8.one);
    
  address_abs := Uint16.of_int 0xFFFA;
  let lo = Uint16.of_uint8 (read !address_abs) in
  let hi = Uint16.of_uint8 (read Uint16.(!address_abs + Uint16.one)) in
  pc := Uint16.logor (hi << 8) lo;

  cycles := 8

and get_flag flag =
  let ( << ) a b = Uint8.of_int (a lsl b) in
  let f = match flag with
    | C -> 1 << 0
    | Z -> 1 << 1
    | I -> 1 << 2
    | D -> 1 << 3
    | B -> 1 << 4
    | U -> 1 << 5
    | V -> 1 << 6
    | N -> 1 << 7 
  in

  if Uint8.logand !status f > Uint8.zero then Uint8.one else Uint8.zero

and set_flag flag value =
  let ( << ) a b = Uint8.of_int (a lsl b) in

  let f = match flag with
    | C -> 1 << 0
    | Z -> 1 << 1
    | I -> 1 << 2
    | D -> 1 << 3
    | B -> 1 << 4
    | U -> 1 << 5
    | V -> 1 << 6
    | N -> 1 << 7 
  in
  
  if value then
    status := Uint8.logor !status f
  else
    status := Uint8.logand !status (Uint8.lognot f)


and fetch () =
  let instr = opcode_table !opcode in

  if instr.addrmode = AddrsMode.Imp then 
    fetched := read !address_abs;

  fetched

and adc () =
  ignore(fetch ());
  let tmp = Uint16.( (Uint16.of_uint8 !a) + (Uint16.of_uint8 !fetched) + (Uint16.of_uint8 (get_flag C))) in
  set_flag C (tmp > (Uint16.of_int 255));
  set_flag Z ((Uint16.logand tmp (Uint16.of_int 0x00FF)) = Uint16.zero);
  set_flag N ((Uint16.logand tmp (Uint16.of_int 0x0080)) <> Uint16.zero);
  (* V = (A^R) & ~(A^M)*)
  let a16 = Uint16.of_uint8 (!a) in
  set_flag V ((Uint16.logand (Uint16.logand (Uint16.logxor a16 tmp) (Uint16.lognot (Uint16.logxor a16 (Uint16.of_uint8 !fetched)))) (Uint16.of_int 0x0080)) <> Uint16.zero);
  a := Uint8.of_uint16(Uint16.logand tmp (Uint16.of_int 0x00FF));
  1

and _and() =
  ignore(fetch ());

  a := Uint8.logand !a !fetched;

  set_flag Z (!a = Uint8.zero);
  set_flag N ((Uint8.logand !a (Uint8.of_int 0x80)) <> Uint8.zero);
  1

and asl () =
  ignore (fetch ());
  set_flag C ((Uint8.logand !fetched (Uint8.of_int 0x80)) <> Uint8.zero);

  fetched := Uint8.shift_left !fetched 1;

  let instr = opcode_table !opcode in
  (if instr.addrmode = AddrsMode.Imp then a := !fetched else write !address_abs !fetched);

  set_flag Z (!fetched = Uint8.zero);
  set_flag N ((Uint8.logand !fetched(Uint8.of_int 0x80)) <> Uint8.zero);
  0

and bcc () =
  if get_flag C = Uint8.zero then
  (
    cycles := !cycles + 1;
    address_abs := Uint16.(!pc + !address_rel);

    if Uint16.logand !address_abs (Uint16.of_int 0xFF00) <> Uint16.logand !pc (Uint16.of_int 0xFF00) then
      cycles := !cycles + 1;

    pc := !address_abs
  );
  0

and bcs () =
  if get_flag C = Uint8.one then
  (
    cycles := !cycles + 1;
    address_abs := Uint16.(!pc + !address_rel);

    if Uint16.logand !address_abs (Uint16.of_int 0xFF00) <> Uint16.logand !pc (Uint16.of_int 0xFF00) then
      cycles := !cycles + 1;

    pc := !address_abs
  );
  0

and beq () =
  if get_flag Z = Uint8.one then
  (
    cycles := !cycles + 1;
    address_abs := Uint16.(!pc + !address_rel);

    if Uint16.logand !address_abs (Uint16.of_int 0xFF00) <> Uint16.logand !pc (Uint16.of_int 0xFF00) then
      cycles := !cycles + 1;

    pc := !address_abs
  );
  0

and bit () =
  ignore(fetch ());

  let tmp = Uint8.logand !a !fetched in

  set_flag Z (tmp = Uint8.zero);
  set_flag V ((Uint8.logand tmp (Uint8.of_int 0x40)) <> Uint8.zero);
  set_flag N ((Uint8.logand tmp (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and bmi () =
  if get_flag N = Uint8.zero then
  (
    cycles := !cycles + 1;
    address_abs := Uint16.(!pc + !address_rel);

    if Uint16.logand !address_abs (Uint16.of_int 0xFF00) <> Uint16.logand !pc (Uint16.of_int 0xFF00) then
      cycles := !cycles + 1;

    pc := !address_abs
  );
  0

and bne () =
  if get_flag Z = Uint8.zero then
  (
    cycles := !cycles + 1;
    address_abs := Uint16.(!pc + !address_rel);

    if Uint16.logand !address_abs (Uint16.of_int 0xFF00) <> Uint16.logand !pc (Uint16.of_int 0xFF00) then
      cycles := !cycles + 1;

    pc := !address_abs
  );
  0

and bpl () =
  if get_flag N = Uint8.zero then
  (
    cycles := !cycles + 1;
    address_abs := Uint16.(!pc + !address_rel);

    if Uint16.logand !address_abs (Uint16.of_int 0xFF00) <> Uint16.logand !pc (Uint16.of_int 0xFF00) then
      cycles := !cycles + 1;

    pc := !address_abs
  );
  0

and brk () =
  set_flag I true;
  
  pc := Uint16.(!pc + Uint16.one);

  let hi = Uint8.of_uint16 (Uint16.shift_right_logical !pc 8) in
  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) hi;
  sp := Uint8.(!sp - Uint8.one);

  let lo = Uint8.of_uint16 (Uint16.logand !pc (Uint16.of_int 0x00FF)) in
  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) lo;
  sp := Uint8.(!sp - Uint8.one);

  set_flag B true;

  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) !status; 
  sp := Uint8.(!sp - Uint8.one);

  sp := Uint8.(!sp - Uint8.one);
  set_flag B false;
  0

and bvc () =
  if get_flag V = Uint8.zero then
  (
    cycles := !cycles + 1;
    address_abs := Uint16.(!pc + !address_rel);

    if Uint16.logand !address_abs (Uint16.of_int 0xFF00) <> Uint16.logand !pc (Uint16.of_int 0xFF00) then
      cycles := !cycles + 1;

    pc := !address_abs
  );
  0

and bvs () =
  if get_flag V = Uint8.one then
  (
    cycles := !cycles + 1;
    address_abs := Uint16.(!pc + !address_rel);

    if Uint16.logand !address_abs (Uint16.of_int 0xFF00) <> Uint16.logand !pc (Uint16.of_int 0xFF00) then
      cycles := !cycles + 1;

    pc := !address_abs
  );
  0

and clc () =
  set_flag C false;
  0

and cld () =
  set_flag D false;
  0

and cli () =
  set_flag I false;
  0

and clv () =
  set_flag V false;
  0

and cmp () =
  ignore(fetch());
  (* A - M *)
  let tmp = Uint8.(!a - !fetched) in

  set_flag C (!a >= !fetched);
  set_flag Z (tmp = Uint8.zero);
  set_flag N ((Uint8.logand tmp (Uint8.of_int 0x80)) <> Uint8.zero);  

  1

and cpx () =
  ignore(fetch());
  (* X - M *)
  let tmp = Uint8.(!x - !fetched) in

  set_flag C (!x >= !fetched);
  set_flag Z (tmp = Uint8.zero);
  set_flag N ((Uint8.logand tmp (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and cpy () =
  ignore(fetch());
  (* X - M *)
  let tmp = Uint8.(!y - !fetched) in

  set_flag C (!y >= !fetched);
  set_flag Z (tmp = Uint8.zero);
  set_flag N ((Uint8.logand tmp (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and dec () =
  ignore(fetch ());

  (* M = M - 1*)
  fetched := Uint8.(!fetched - Uint8.one);

  write !address_abs !fetched;

  set_flag Z (!fetched = Uint8.zero);
  set_flag N ((Uint8.logand !fetched (Uint8.of_int 0x80)) <> Uint8.zero);
  1

and dex () =
  (* X = X - 1 *)
  x := Uint8.(!x - Uint8.one);

  set_flag Z (!x = Uint8.zero);
  set_flag N ((Uint8.logand !x (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and dey () =
  (* Y = Y - 1 *)
  y := Uint8.(!y - Uint8.one);

  set_flag Z (!y = Uint8.zero);
  set_flag N ((Uint8.logand !y (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and eor () =
  ignore(fetch ());

  (* A EOR M -> A *)
  a := Uint8.logxor !a !fetched;

  set_flag Z (!a = Uint8.zero);
  set_flag N ((Uint8.logand !a (Uint8.of_int 0x80)) <> Uint8.zero);
  1

and inc () =
  ignore(fetch ());
  (* M = M + 1*)
  fetched := Uint8.(!fetched + Uint8.one);

  write !address_abs !fetched;

  set_flag Z (!fetched = Uint8.zero);
  set_flag N ((Uint8.logand !fetched (Uint8.of_int 0x80)) <> Uint8.zero);
  1

and inx () =
  ignore(fetch ());

  (* X = X + 1 *)
  x := Uint8.(!x + Uint8.one);

  set_flag Z (!x = Uint8.zero);
  set_flag N ((Uint8.logand !x (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and iny () =
  ignore(fetch ());
  (* Y = Y + 1*)
  y := Uint8.(!y + Uint8.one);

  set_flag Z (!y = Uint8.zero);
  set_flag N ((Uint8.logand !y (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and jmp () =
  let ( << ) a b = Uint16.shift_left a b in
  
  let lo = Uint16.of_uint8 (read !pc) in
  pc := Uint16.(!pc + Uint16.one);

  let hi = Uint16.of_uint8 (read !pc) << 8 in

  pc := Uint16.logor hi lo;
  0


and jsr () =
  let ( >> ) a b = Uint16.shift_left a b in
  
  (* 
            ...
   SP -> |  PCL   |
         |  PCH   |
            ...
  *)

  let hi = Uint8.of_uint16 (!pc >> 8)  in
  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) hi;
  sp := Uint8.(!sp - Uint8.one);

  let lo = Uint8.of_uint16(Uint16.logand !pc (Uint16.of_int 0x00FF)) in
  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) lo;
  sp := Uint8.(!sp - Uint8.one);

  pc := !address_abs;
  0

and lda () =
  ignore(fetch ());
  
  (* a = M *)
  a := !fetched;

  set_flag Z (!a = Uint8.zero);
  set_flag N ((Uint8.logand !a (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and ldx () =
  ignore(fetch ());
  
  (* x = M *)
  x := !fetched;

  set_flag Z (!x = Uint8.zero);
  set_flag N ((Uint8.logand !x (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and ldy () =
  ignore(fetch ());
  
  (* y = M *)
  y := !fetched;

  set_flag Z (!y = Uint8.zero);
  set_flag N ((Uint8.logand !y (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and _lsr() =
  ignore (fetch ());
  set_flag C ((Uint8.logand !fetched Uint8.one) <> Uint8.zero);

  fetched := Uint8.shift_right_logical !fetched 1;
  
  let instr = opcode_table !opcode in
  (if instr.addrmode = AddrsMode.Imp then a := !fetched else write !address_abs !fetched);

  set_flag Z (!fetched = Uint8.zero);
  set_flag N false;
  0

and nop () =
 0

and ora () =
  ignore(fetch ());

  (* A OR M -> A *)
  a := Uint8.logor !a !fetched;

  set_flag Z (!a = Uint8.zero);
  set_flag N ((Uint8.logand !a (Uint8.of_int 0x80)) <> Uint8.zero);
  1

and pha () =
  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) !a;
  sp := Uint8.(!sp - Uint8.one);
  0

and php () =
  write Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp)) !status;
  sp := Uint8.(!sp - Uint8.one);
  0

and pla () =
  sp := Uint8.(!sp + Uint8.one);
  a := read Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp));
  set_flag Z (!a = Uint8.zero);
  set_flag N ((Uint8.logand !a (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and plp () =
  sp := Uint8.(!sp + Uint8.one);
  status := read Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp));
  0

and rol () =
  ignore (fetch ());
  let carry = get_flag C in
  
  set_flag C ((Uint8.logand !fetched (Uint8.of_int 0x80)) <> Uint8.zero);

  fetched := Uint8.shift_left !fetched 1;
  fetched := Uint8.logor !fetched carry;
  
  let instr = opcode_table !opcode in
  (if instr.addrmode = AddrsMode.Imp then a := !fetched else write !address_abs !fetched);

  set_flag Z (!fetched = Uint8.zero);
  set_flag N ((Uint8.logand !fetched(Uint8.of_int 0x80)) <> Uint8.zero);
  0

and ror () =
  ignore (fetch ());
  let carry = Uint8.shift_right (get_flag C) 7 in
  
  set_flag C ((Uint8.logand !fetched Uint8.one) <> Uint8.zero);

  fetched := Uint8.shift_right !fetched 1;
  fetched := Uint8.logor !fetched carry;
  
  let instr = opcode_table !opcode in
  (if instr.addrmode = AddrsMode.Imp then a := !fetched else write !address_abs !fetched);

  set_flag Z (!fetched = Uint8.zero);
  set_flag N ((Uint8.logand !fetched(Uint8.of_int 0x80)) <> Uint8.zero);
  0

and rti () =
  let ( << ) a b = Uint16.shift_left a b in

  sp := Uint8.(!sp + Uint8.one);
  
  status := read Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp));
  status := Uint8.logand !status (Uint8.lognot (Uint8.of_int 0b0001_0000));
  status := Uint8.logand !status (Uint8.lognot (Uint8.of_int 0b0010_0000));
  
  sp := Uint8.(!sp + Uint8.one);
  
  let lo = Uint16.of_uint8 (read Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp))) in
  let hi = Uint16.of_uint8 (read Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp))) << 8 in
  pc := Uint16.logor hi lo;
  0

and rts () =
  let ( << ) a b = Uint16.shift_left a b in
  
  (* pull PC, PC + 1 -> PC *)
  sp := Uint8.(!sp + Uint8.one);
  let lo = Uint16.of_uint8 (read Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp))) in
  
  sp := Uint8.(!sp + Uint8.one);
  let hi = Uint16.of_uint8 (read Uint16.((Uint16.of_int 0x0100) + (Uint16.of_uint8 !sp))) << 8 in
  
  pc := Uint16.logor hi lo;
  pc := Uint16.(!pc + Uint16.one);
  0

and sbc () =
  ignore(fetch ());
  let value = Uint16.logxor (Uint16.of_uint8 !fetched) (Uint16.of_int 0x00FF) in
  
  let tmp = Uint16.((Uint16.of_uint8 !a) + value + (Uint16.of_uint8 (get_flag C))) in
  set_flag C (Uint16.logand tmp (Uint16.of_int 0xFF00) <> Uint16.zero);
  set_flag Z ((Uint16.logand tmp (Uint16.of_int 0x00FF)) = Uint16.zero);
  (* V = (A^R) & ~(A^M)*)
  let a16 = Uint16.of_uint8 (!a) in
  set_flag V ((Uint16.logand (Uint16.logand (Uint16.logxor a16 tmp) (Uint16.logxor a16 value)) (Uint16.of_int 0x0080)) <> Uint16.zero );
  set_flag N ((Uint16.logand tmp (Uint16.of_int 0x0080)) <> Uint16.zero);
  a := Uint8.of_uint16(Uint16.logand tmp (Uint16.of_int 0x00FF));
  1

and sec () =
  set_flag C true;
  0

and sed () =
  set_flag D true;
  0

and sei () =
  set_flag I true;
  0

and sta () =
  ignore(fetch ());
  
  (* M = A *)
  write !address_abs !a;
  0

and stx () =
  ignore(fetch ());
  
  (* M = X *)
  write !address_abs !x;
  0

and sty () =
  ignore(fetch ());
  
  (* M = Y *)
  write !address_abs !y;
  0

and tax () =
  ignore(fetch ());
  (* X = A*)
  x := !a;

  set_flag Z (!x = Uint8.zero);
  set_flag N ((Uint8.logand !x (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and tay () =
  ignore(fetch ());
  (* Y = A*)
  y := !a;

  set_flag Z (!y = Uint8.zero);
  set_flag N ((Uint8.logand !y (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and tsx () =
  x := !sp;
  
  set_flag Z (!x = Uint8.zero);
  set_flag N ((Uint8.logand !x (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and txa () =
  ignore(fetch ());
  (* A = X*)
  a := !x;

  set_flag Z (!a = Uint8.zero);
  set_flag N ((Uint8.logand !a (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and txs () =
  sp := !x;
  0

and tya () =
  ignore(fetch ());
  (* A = Y *)
  a := !y;

  set_flag Z (!y = Uint8.zero);
  set_flag N ((Uint8.logand !y (Uint8.of_int 0x80)) <> Uint8.zero);
  0

and opcode_table opcode = match Uint8.to_int opcode with
  | 0x00 -> { name = "BRK"; operate = brk; addrmode = AddrsMode.Imp; cicles = 7; }
  | 0x01 -> { name = "ORA"; operate = ora; addrmode = AddrsMode.Izx; cicles = 6; }
  | 0x05 -> { name = "ORA"; operate = ora; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0x06 -> { name = "ASL"; operate = asl; addrmode = AddrsMode.Zp0; cicles = 5; }
  | 0x08 -> { name = "PHP"; operate = php; addrmode = AddrsMode.Imp; cicles = 3; }
  | 0x09 -> { name = "ORA"; operate = ora; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0x0A -> { name = "ASL"; operate = asl; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x0D -> { name = "ORA"; operate = ora; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0x0E -> { name = "ASL"; operate = asl; addrmode = AddrsMode.Abs; cicles = 6; }
  (* === 10 *)
  | 0x10 -> { name = "BPL"; operate = bpl; addrmode = AddrsMode.Rel; cicles = 2; }
  | 0x11 -> { name = "ORA"; operate = ora; addrmode = AddrsMode.Izy; cicles = 5; }
  | 0x15 -> { name = "ORA"; operate = ora; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0x16 -> { name = "ASL"; operate = asl; addrmode = AddrsMode.Zpx; cicles = 6; }
  | 0x18 -> { name = "CLC"; operate = clc; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x19 -> { name = "ORA"; operate = ora; addrmode = AddrsMode.Aby; cicles = 4; }
  | 0x1D -> { name = "ORA"; operate = ora; addrmode = AddrsMode.Abx; cicles = 4; }
  | 0x1E -> { name = "ASL"; operate = asl; addrmode = AddrsMode.Abx; cicles = 7; }
  (* === 20 *)
  | 0x20 -> { name = "JSR"; operate = jsr; addrmode = AddrsMode.Abs; cicles = 6; }
  | 0x21 -> { name = "AND"; operate =_and; addrmode = AddrsMode.Izx; cicles = 6; }
  | 0x24 -> { name = "BIT"; operate = bit; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0x25 -> { name = "AND"; operate =_and; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0x26 -> { name = "ROL"; operate = rol; addrmode = AddrsMode.Zp0; cicles = 5; }
  | 0x28 -> { name = "PLP"; operate = plp; addrmode = AddrsMode.Imp; cicles = 4; }
  | 0x29 -> { name = "AND"; operate =_and; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0x2A -> { name = "ROL"; operate = rol; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x2C -> { name = "BIT"; operate = bit; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0x2D -> { name = "AND"; operate =_and; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0x2E -> { name = "ROL"; operate = rol; addrmode = AddrsMode.Abs; cicles = 6; }
  (* === 30 *)
  | 0x30 -> { name = "BMI"; operate = bmi; addrmode = AddrsMode.Rel; cicles = 2; }
  | 0x31 -> { name = "AND"; operate =_and; addrmode = AddrsMode.Izy; cicles = 5; }
  | 0x35 -> { name = "AND"; operate =_and; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0x36 -> { name = "ROL"; operate = rol; addrmode = AddrsMode.Zpx; cicles = 6; }
  | 0x38 -> { name = "SEC"; operate = sec; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x39 -> { name = "AND"; operate =_and; addrmode = AddrsMode.Aby; cicles = 4; }
  | 0x3D -> { name = "AND"; operate =_and; addrmode = AddrsMode.Abx; cicles = 4; }
  | 0x3E -> { name = "ROL"; operate = rol; addrmode = AddrsMode.Abx; cicles = 7; }
  (* === 40 *)
  | 0x40 -> { name = "RTI"; operate = rti; addrmode = AddrsMode.Imp; cicles = 6; }
  | 0x41 -> { name = "EOR"; operate = eor; addrmode = AddrsMode.Izx; cicles = 6; }
  | 0x45 -> { name = "EOR"; operate = eor; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0x46 -> { name = "LSR"; operate =_lsr; addrmode = AddrsMode.Zp0; cicles = 5; }
  | 0x48 -> { name = "PHA"; operate = pha; addrmode = AddrsMode.Imp; cicles = 3; }
  | 0x49 -> { name = "EOR"; operate = eor; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0x4A -> { name = "LSR"; operate =_lsr; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x4C -> { name = "JMP"; operate = jmp; addrmode = AddrsMode.Abs; cicles = 3; }
  | 0x4D -> { name = "EOR"; operate = eor; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0x4E -> { name = "LSR"; operate =_lsr; addrmode = AddrsMode.Abs; cicles = 6; }
  (* === 50 *)
  | 0x50 -> { name = "BVC"; operate = bvc; addrmode = AddrsMode.Rel; cicles = 2; }
  | 0x51 -> { name = "EOR"; operate = eor; addrmode = AddrsMode.Izy; cicles = 5; }
  | 0x55 -> { name = "EOR"; operate = eor; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0x56 -> { name = "LSR"; operate =_lsr; addrmode = AddrsMode.Zpx; cicles = 6; }
  | 0x58 -> { name = "CLI"; operate = cli; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x59 -> { name = "EOR"; operate = eor; addrmode = AddrsMode.Aby; cicles = 4; }
  | 0x5D -> { name = "EOR"; operate = eor; addrmode = AddrsMode.Abx; cicles = 4; }
  | 0x5E -> { name = "LSR"; operate =_lsr; addrmode = AddrsMode.Abx; cicles = 7; }
  (* === 60 *)
  | 0x60 -> { name = "RTS"; operate = rts; addrmode = AddrsMode.Imp; cicles = 6; }
  | 0x61 -> { name = "ADC"; operate = adc; addrmode = AddrsMode.Izx; cicles = 6; }
  | 0x65 -> { name = "ADC"; operate = adc; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0x66 -> { name = "ROR"; operate = ror; addrmode = AddrsMode.Zp0; cicles = 5; }
  | 0x68 -> { name = "PLA"; operate = pla; addrmode = AddrsMode.Imp; cicles = 4; }
  | 0x69 -> { name = "ADC"; operate = adc; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0x6A -> { name = "ROR"; operate = ror; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x6C -> { name = "JMP"; operate = jmp; addrmode = AddrsMode.Ind; cicles = 5; }
  | 0x6D -> { name = "ADC"; operate = adc; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0x6E -> { name = "ROR"; operate = ror; addrmode = AddrsMode.Abs; cicles = 6; }
  (* === 70 *)
  | 0x70 -> { name = "BVS"; operate = bvs; addrmode = AddrsMode.Rel; cicles = 2; }
  | 0x71 -> { name = "ADC"; operate = adc; addrmode = AddrsMode.Izy; cicles = 5; }
  | 0x75 -> { name = "ADC"; operate = adc; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0x76 -> { name = "ROR"; operate = ror; addrmode = AddrsMode.Zpx; cicles = 6; }
  | 0x78 -> { name = "SEI"; operate = sei; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x79 -> { name = "ADC"; operate = adc; addrmode = AddrsMode.Aby; cicles = 4; }
  | 0x7D -> { name = "ADC"; operate = adc; addrmode = AddrsMode.Abx; cicles = 4; }
  | 0x7E -> { name = "ROR"; operate = ror; addrmode = AddrsMode.Abx; cicles = 7; }
  (* === 80 *)
  | 0x81 -> { name = "STA"; operate = sta; addrmode = AddrsMode.Izx; cicles = 6; }
  | 0x84 -> { name = "STY"; operate = sty; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0x85 -> { name = "STA"; operate = sta; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0x86 -> { name = "STX"; operate = stx; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0x88 -> { name = "DEY"; operate = dey; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x8A -> { name = "TXA"; operate = txa; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x8C -> { name = "STY"; operate = sty; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0x8D -> { name = "STA"; operate = sta; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0x8E -> { name = "STX"; operate = stx; addrmode = AddrsMode.Abs; cicles = 4; }
  (* === 90 *)
  | 0x90 -> { name = "BCC"; operate = bcc; addrmode = AddrsMode.Rel; cicles = 2; }
  | 0x91 -> { name = "STA"; operate = sta; addrmode = AddrsMode.Izy; cicles = 6; }
  | 0x94 -> { name = "STY"; operate = sty; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0x95 -> { name = "STA"; operate = sta; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0x96 -> { name = "STX"; operate = stx; addrmode = AddrsMode.Zpy; cicles = 4; }
  | 0x98 -> { name = "TYA"; operate = tya; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x99 -> { name = "STA"; operate = sta; addrmode = AddrsMode.Aby; cicles = 5; }
  | 0x9A -> { name = "TXS"; operate = txs; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0x9D -> { name = "STA"; operate = sta; addrmode = AddrsMode.Abx; cicles = 5; }
  (* === A0 *)
  | 0xA0 -> { name = "LDY"; operate = ldy; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0xA1 -> { name = "LDA"; operate = lda; addrmode = AddrsMode.Izx; cicles = 6; }
  | 0xA2 -> { name = "LDX"; operate = ldx; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0xA4 -> { name = "LDY"; operate = ldy; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0xA5 -> { name = "LDA"; operate = lda; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0xA6 -> { name = "LDX"; operate = ldx; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0xA8 -> { name = "TAY"; operate = tay; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xA9 -> { name = "LDA"; operate = lda; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0xAA -> { name = "TAX"; operate = tax; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xAC -> { name = "LDY"; operate = ldy; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0xAD -> { name = "LDA"; operate = lda; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0xAE -> { name = "LDX"; operate = ldx; addrmode = AddrsMode.Abs; cicles = 4; }
  (* === B0 *)
  | 0xB0 -> { name = "BCS"; operate = bcs; addrmode = AddrsMode.Rel; cicles = 2; }
  | 0xB1 -> { name = "LDA"; operate = lda; addrmode = AddrsMode.Izy; cicles = 5; }
  | 0xB4 -> { name = "LDY"; operate = ldy; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0xB5 -> { name = "LDA"; operate = lda; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0xB6 -> { name = "LDX"; operate = ldx; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0xB8 -> { name = "CLV"; operate = clv; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xB9 -> { name = "LDA"; operate = lda; addrmode = AddrsMode.Aby; cicles = 4; }
  | 0xBA -> { name = "TSX"; operate = tsx; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xBC -> { name = "LDY"; operate = ldy; addrmode = AddrsMode.Abx; cicles = 4; }
  | 0xBD -> { name = "LDA"; operate = lda; addrmode = AddrsMode.Abx; cicles = 4; }
  | 0xBE -> { name = "LDX"; operate = ldx; addrmode = AddrsMode.Abx; cicles = 4; }
  (* === C0 *)
  | 0xC0 -> { name = "CPY"; operate = cpy; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0xC1 -> { name = "CMP"; operate = cmp; addrmode = AddrsMode.Izx; cicles = 6; }
  | 0xC4 -> { name = "CPY"; operate = cpy; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0xC5 -> { name = "CMP"; operate = cmp; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0xC6 -> { name = "DEC"; operate = dec; addrmode = AddrsMode.Zp0; cicles = 5; }
  | 0xC8 -> { name = "INY"; operate = iny; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xC9 -> { name = "CMP"; operate = cmp; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0xCA -> { name = "DEX"; operate = dex; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xCC -> { name = "CPY"; operate = cpy; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0xCD -> { name = "CMP"; operate = cmp; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0xCE -> { name = "DEC"; operate = dec; addrmode = AddrsMode.Abs; cicles = 6; }
  (* === D0 *)
  | 0xD0 -> { name = "BNE"; operate = bne; addrmode = AddrsMode.Rel; cicles = 2; }
  | 0xD1 -> { name = "CMP"; operate = cmp; addrmode = AddrsMode.Izy; cicles = 5; }
  | 0xD5 -> { name = "CMP"; operate = cmp; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0xD6 -> { name = "DEC"; operate = dec; addrmode = AddrsMode.Zpx; cicles = 6; }
  | 0xD8 -> { name = "CLD"; operate = cld; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xD9 -> { name = "CMP"; operate = cmp; addrmode = AddrsMode.Aby; cicles = 4; }
  | 0xDC -> { name = "CMP"; operate = cmp; addrmode = AddrsMode.Abx; cicles = 4; }
  | 0xDD -> { name = "DEC"; operate = dec; addrmode = AddrsMode.Abx; cicles = 7; }
  (* === E0 *)
  | 0xE0 -> { name = "CPX"; operate = cpx; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0xE1 -> { name = "SBC"; operate = sbc; addrmode = AddrsMode.Izx; cicles = 6; }
  | 0xE4 -> { name = "CPX"; operate = cpx; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0xE5 -> { name = "SBC"; operate = sbc; addrmode = AddrsMode.Zp0; cicles = 3; }
  | 0xE6 -> { name = "INC"; operate = inc; addrmode = AddrsMode.Zp0; cicles = 5; }
  | 0xE8 -> { name = "INX"; operate = inx; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xE9 -> { name = "SBC"; operate = sbc; addrmode = AddrsMode.Imm; cicles = 2; }
  | 0xEA -> { name = "NOP"; operate = nop; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xEC -> { name = "CPX"; operate = cpx; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0xED -> { name = "SBC"; operate = sbc; addrmode = AddrsMode.Abs; cicles = 4; }
  | 0xEE -> { name = "INC"; operate = inc; addrmode = AddrsMode.Abs; cicles = 6; }
  (* === F0 *)
  | 0xF0 -> { name = "BEQ"; operate = beq; addrmode = AddrsMode.Rel; cicles = 2; }
  | 0xF1 -> { name = "SBC"; operate = sbc; addrmode = AddrsMode.Izy; cicles = 5; }
  | 0xF5 -> { name = "SBC"; operate = sbc; addrmode = AddrsMode.Zpx; cicles = 4; }
  | 0xF6 -> { name = "INC"; operate = inc; addrmode = AddrsMode.Zpx; cicles = 6; }
  | 0xF8 -> { name = "SED"; operate = sed; addrmode = AddrsMode.Imp; cicles = 2; }
  | 0xF9 -> { name = "SBC"; operate = sbc; addrmode = AddrsMode.Aby; cicles = 4; }
  | 0xFD -> { name = "SBC"; operate = sbc; addrmode = AddrsMode.Abx; cicles = 4; }
  | 0xFE -> { name = "INC"; operate = inc; addrmode = AddrsMode.Abx; cicles = 7; }
  (* === Invalid *)
  | x -> raise (InvalidOpcode ("Invalid Instruction"^(string_of_int x)))

(* Clock simulates a clock of the cpu *)
let clock () =
  if !cycles <> 0 then (
    (* 1 - Read current opcode *)
    opcode := read !pc;
    (* 2 - Move PC register *)
    pc := Uint16.(!pc + Uint16.one);

    (* 3 - Get the opcode instruction *)
    let instr = opcode_table !opcode in
    
    (* Depending on the operation we need to increment this value *)
    cycles := instr.cicles;
    let addrmode_cicles = AddrsMode.access instr.addrmode in
    let operate_cicles = instr.operate () in

   (* Todo: ADD cicles *)
   cycles := !cycles + (addrmode_cicles land operate_cicles)
  );

  cycles := !cycles - 1
