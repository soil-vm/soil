#set page(
  paper: "a4",
  header: align(right)[The Soil Specification v1.0],
  numbering: "1",
)
#set heading(
  numbering: "1."
)

#align(center, text(17pt)[*The Soil Specification*])

Version: 1.0

#outline()

= Introduction <intro>

Soil is a general-purpose, register-based instruction set and bytecode.

== Preliminaries <prelims>

Soil uses two types of integer values. *Bytes* are 8 bits and *words* are 64 bits.
All integers are encoded as little-endian.

Floating point values in the Soil VM are 64-bit values according to IEEE-754.

Strings are encoded as UTF-8 and never null-terminated.

In the specification, list types are used as an abstraction. A `List<Type>` is encoded
as multiple instances of *Type* directly after each other in memory.

== About this document

This document provides a specification of the Soil VM. @structures defines the data structures
and encodings used by a Soil VM. @model describes the execution model
and environment of a Soil VM. @instructions provides an overview of all instructions defined by Soil
and their behavior.

= Data Structures <structures>

== Programs <programs>

A Soil VM executes _programs_. A program consists of one or more sections, as defined in @sections.
A valid Soil program contains exactly one bytecode section. 

=== Encoding

A program is encoded as follows:

#table(
  columns: (auto, auto, auto, 1fr),
  table.header([*Bytes*], [*Field*], [*Type*], [*Notes*]),
  [00 .. 03], [`"soil"`], [`String`], [Magic Bytes to identify a Soil program.],
  [04 .. n], [Sections], [`List<Section>`], []
)

== Sections <sections>

A Soil program is organized into sections. Soil supports four types of sections:

#table(
  columns: (auto, auto, 1fr),
  table.header([*Section Kind*], [*Encoding*], [*Description*]),
  [Bytecode], [0], [Contains a list of Soil instructions],
  [Initial Memory], [1], [Contains the memory the VM is initialized with],
  [Name], [2], [Provides a name for the Soil program],
  [Labels], [3], [Contains a list of labels (cf. @labels)],
  [Description], [4], [Provides a description for the Soil program],
)

A program may contain *at most* one section of each kind.

=== Labels <labels>

A label is a combination of a string and an offset into the bytecode.

==== Encoding

#table(
  columns: (auto, auto, 1fr),
  table.header([*Bytes*], [*Field*], [*Type*]),
  [00 .. 07], [Offset], [`Word`],
  [08 .. 15], [Length], [`Word`],
  [16 .. 16 + Length ], [Label], [`String`]
)

=== Encoding

A section is encoded as follows:

#table(
  columns: (auto, auto, auto, 1fr),
  table.header([*Bytes*], [*Field*], [*Type*], [*Notes*]),
  [00 .. 01], [Kind], [`Byte`], [],
  [02 .. 09], [Length], [`Word`], [],
  [10 .. 10 + Length], [Content], [`List<Byte>`], [Depending on the kind, this may be a `List<Instruction>`, `List<Label>` or `String`]
)

= VM Model <model>

A Soil VM provides a set of registers and byte-addressable memory.

=== Registers <registers>

A register in Soil is word-sized. A Soil VM has the following registers:

#table(
  columns: (auto, auto, 1fr),
  table.header([*Name*], [*Encoding*], [*Purpose*]),
  [SP], [0], [Stack Pointer],
  [ST], [1], [Status Register],
  [A], [2], [General Purpose],
  [B], [3], [General Purpose],
  [C], [4], [General Purpose],
  [D], [5], [General Purpose],
  [E], [6], [General Purpose],
  [F], [7], [General Purpose],
)

=== Memory <memory>

Memory is a zero-initialized `List<Byte>`. The size of the memory is implementation-defined.
Accessing an out-of-bounds memory address is illegal and causes a VM panic.

=== Execution Model

==== Initialization

1. The VM initializes the memory (cf. @memory) and registers to zero.
2. If the program defines initial memory, the VM copies the initial memory definition into its own memory. If the VM's memory is smaller than the initial memory, the VM must panic.
3. The VM initialized the `SP` register to the size of its memory.

==== Execution

Conceptually, the Soil VM has an instruction pointer that is initially at the start of a program's
bytecode section. The instruction pointer advances until the VM has read a full instruction and executes
it. Generally, instructions are executed linearly one after another. However, control flow instructions
(cf. @instructions) may change the instruction pointer's location in the bytecode.

=== System Calls

= Instructions <instructions>

Soil supports the following instructions:

#table(
  columns: (auto, auto, auto, auto, 1fr),
  table.header([*Instruction*], [*Opcode*], [*Operand 1*], [*Operand 2*], [*Description*]),
[`nop`], [0x00], [-], [-], [Does nothing.],
[`panic`], [0xe0], [-], [-], [End program execution with an error.],
[`trystart`], [0xe1], [`catch:word`], [-], [If a panic occurs, catches it, resets `sp`, and jumps to the `catch` address.],
[`tryend`], [0xe2], [-], [-], [Ends a scope started by `trystart`.],
[`move`], [0xd0], [`to:reg`], [`from:reg`], [Sets `to` to `from`.],
[`movei`], [0xd1], [`to:reg`], [`value:word`], [Sets `to` to `from`.],
[`moveib`], [0xd2], [`to:reg`], [`value:word`], [Sets `to` to `from`.],
[`load`], [0xd3], [`to:reg`], [`from:reg`], [Interprets `from` as an address and sets `to` to the word at that address in memory.],
[`loadb`], [0xd4], [`to:reg`], [`from:reg`], [Interprets `from` as an address and sets `to` to the byte at that address in memory.],
[`store`], [0xd5], [`to:reg`], [`from:reg`], [Interprets `to` as an address and sets the 64 bits at that address in memory to `from`.],
[`storeb`], [0xd6], [`to:reg`], [`from:reg`], [Interprets `to` as an address and sets the 8 bits at that address in memory to `from`.],
[`push`], [0xd7], [`reg:reg`], [-], [Decreases `sp` by 8, then runs `store sp reg`.],
[`pop`], [0xd8], [`reg:reg`], [-], [Runs `load reg sp`, then increases `sp` by 8.],
[`jump`], [0xf0], [`to:word`], [-], [Continues executing at the `to`th byte.],
[`cjump`], [0xf1], [`to:word`], [-], [Runs `jump to` if `st` is not 0.],
[`call`], [0xf2], [`target:word`], [-], [Runs `jump target`. Saves the formerly next instruction on an internal stack so that `ret` returns.],
[`ret`], [0xf3], [-], [-], [Returns to the instruction after the matching `call`.],
[`syscall`], [0xf4], [`number:byte`], [-], [Performs a syscall. Behavior depends on the syscall. The syscall can access all registers and memory.],
[`cmp`], [0xc0], [`left:reg`], [`right:reg`], [Saves `left` - `right` in `st`.],
[`isequal`], [0xc1], [-], [-], [If `st` is 0, sets `st` to 1, otherwise to 0.],
[`isless`], [0xc2], [-], [-], [If `st` is less than 0, sets `st` to 1; otherwise, sets it to 0.],
[`isgreater`], [0xc3], [-], [-], [If `st` is greater than 0, sets `st` to 1; otherwise, sets it to 0.],
[`islessequal`], [0xc4], [-], [-], [If `st` is 0 or less, sets `st` to 1; otherwise, sets it to 0.],
[`isgreaterequal`], [0xc5], [-], [-], [If `st` is 0 or greater, sets `st` to 1; otherwise, sets it to 0.],
[`isnotequal`], [0xc6], [-], [-], [If `st` is 0, sets `st` to 0; otherwise, sets it to 1.],
[`fcmp`], [0xc7], [`left:regt`], [`right:reg`], [Compares `left` and `right` by subtracting `right` from `left` and saving the result in `st`.],
[`fisequal`], [0xc8], [-], [-], [If `st` is 0, sets `st` to 1; otherwise, sets it to 0.],
[`fisless`], [0xc9], [-], [-], [If `st` is less than 0, sets `st` to 1; otherwise, sets it to 0.],
[`fisgreater`], [0xca], [-], [-], [If `st` is greater than 0, sets `st` to 1; otherwise, sets it to 0.],
[`fislessequal`], [0xcb], [-], [-], [If `st` is 0 or less, sets `st` to 1; otherwise, sets it to 0.],
[`fisgreaterequal`], [0xcc], [-], [-], [If `st` is 0 or greater, sets `st` to 1; otherwise, sets it to 0.],
[`fisnotequal`], [0xcd], [-], [-], [If `st` is 0, sets `st` to 0; otherwise, sets it to 1.],
[`inttofloat`], [0xce], [`reg:reg`], [-], [Interprets `reg` as an integer and sets it to a float of about the same value. TODO: specify edge cases.],
[`floattoint`], [0xcf], [`reg:reg`], [-], [Interprets `reg` as a float and sets it to its integer representation, rounded down. TODO: specify edge cases.],
[`add`], [0xa0], [`to:reg`], [`from:reg`], [Adds `from` to `to`.],
[`sub`], [0xa1], [`to:reg`], [`from:reg`], [Subtracts `from` from `to`.],
[`mul`], [0xa2], [`to:reg`], [`from:reg`], [Multiplies `from` and `to`, saving the result in `to`.],
[`div`], [0xa3], [`dividend:reg`], [`divisor:reg`], [Divides `dividend` by `divisor`, saving the quotient in `dividend`.],
[`rem`], [0xa4], [`dividend:reg`], [`divisor:reg`], [Divides `dividend` by `divisor`, saving the remainder in `dividend`.],
[`fadd`], [0xa5], [`to:reg`], [`from:reg`], [Adds `from` to `to`, interpreting both as floats.],
[`fsub`], [0xa6], [`to:reg`], [`from:reg`], [Subtracts `from` from `to`, interpreting both as floats.],
[`fmul`], [0xa7], [`to:reg`], [`from:reg`], [Multiplies `from` and `to`, interpreting both as floats, and saves the result in `to`.],
[`fdiv`], [0xa8], [`dividend:reg`], [`divisor:reg`], [Divides `dividend` by `divisor`, interpreting both as floats, and saves the quotient in `dividend`.],
[`and`], [0xb0], [`to:reg`], [`from:reg`], [Performs a binary AND on `to` and `from`, saving the result in `to`.],
[`or`], [0xb1], [`to:reg`], [`from:reg`], [Performs a binary OR on `to` and `from`, saving the result in `to`.],
[`xor`], [0xb2], [`to:reg`], [`from:reg`], [Performs a binary XOR on `to` and `from`, saving the result in `to`.],
[`not`], [0xb3], [`to:reg`], [-], [Inverts the bits of `to`.]
)

== Encoding

Instructions are encoded as follows:

#table(
  columns: (auto, auto, auto, 1fr),
  table.header([*Bytes*], [*Field*], [*Type*], [*Notes*]),
  [00 .. 01], [Opcode], [`Byte`], [],
  [02 .. n], [Operands], [Operands], [],
)

A Soil instruction may have between zero and two operands. For one instruction, the number and types
of operands are always the same. If an instruction operates on two registers, they are encoded in a
single byte with the first register encoded in the lower four bits and the second register encoded in
the upper four bits.
