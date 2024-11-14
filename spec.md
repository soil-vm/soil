# The Anatomy of Soil

Soil consists of three parts of state: registers, memory, and byte code.

Soil is not a von Neumann machine – byte code and memory live in separate worlds.
Byte code can only read/write the memory, not byte code itself.
You can't reflect on the byte code itself, for example, to store pointers to instructions.
This gives Soil implementations the freedom to compile the byte code to machine code on startup.

Soil binaries are files that contain byte code and initial memory.

## Registers

Soil has 8 registers, all of which hold 64 bits.

| name | description              |
| ---- | ------------------------ |
| `sp` | stack pointer            |
| `st` | status register          |
| `a`  | general-purpose register |
| `b`  | general-purpose register |
| `c`  | general-purpose register |
| `d`  | general-purpose register |
| `e`  | general-purpose register |
| `f`  | general-purpose register |

Initially, `sp` is the memory size.
All other registers are zero.

## Memory

It also has byte-addressed memory.
For now, the size of the memory is hardcoded to something big.

## Byte Code

Byte code consists of a sequence of instructions.

Soil runs the instructions in sequence, starting from the first.
Some instructions alter control flow by jumping to other instructions.

These are all instructions:

### `nop`

Does nothing.

### `panic`

Panics.

### `trystart catch:word`

If a panic occurs, catches it, resets `sp`, and jumps to the `catch` address.

### `tryend`

Ends a scope started by `trystart`.

### `move to:reg from:reg`

Sets `to` to `from`.

### `movei to:reg value:word`

Sets `to` to `from`.

### `moveib to:reg value:word`

Sets `to` to `from`.

### `load to:reg from:reg`

Interprets `from` as an address and sets `to` to the word at that address in memory.

### `loadb to:reg from:reg`

Interprets `from` as an address and sets `to` to the byte at that address in memory.

### `store to:reg from:reg`

Interprets `to` as an address and sets the 64 bits at that address in memory to `from`.

### `storeb to:reg from:reg`

Interprets `to` as an address and sets the 8 bits at that address in memory to `from`.

### `push reg:reg`

Decreases `sp` by 8, then runs `store sp reg`.

### `pop reg:reg`

Runs `load reg sp`, then increases `sp` by 8.

### `jump to:word`

Continues executing at the `to`th byte.

### `cjump to:word`

Runs `jump to` if `st` is not 0.

### `call target:word`

Runs `jump target`. Saves the formerly next instruction on an internal stack so that `ret` returns.

### `ret`

Returns to the instruction after the matching `call`.

### `syscall number:byte`

Performs a syscall. Behavior depends on the syscall. The syscall can access all registers and memory.

### `cmp left:reg right:reg`

Saves `left` - `right` in `st`.

### `isequal`

If `st` is 0, sets `st` to 1, otherwise to 0.

### `isless`

If `st` is less than 0, sets `st` to 1; otherwise, sets it to 0.

### `isgreater`

If `st` is greater than 0, sets `st` to 1; otherwise, sets it to 0.

### `islessequal`

If `st` is 0 or less, sets `st` to 1; otherwise, sets it to 0.

### `isgreaterequal`

If `st` is 0 or greater, sets `st` to 1; otherwise, sets it to 0.

### `isnotequal`

If `st` is 0, sets `st` to 0; otherwise, sets it to 1.

### `fcmp`

Compares `left` and `right` by subtracting `right` from `left` and saving the result in `st`.

### `fisequal`

If `st` is 0, sets `st` to 1; otherwise, sets it to 0.

### `fisless`

If `st` is less than 0, sets `st` to 1; otherwise, sets it to 0.

### `fisgreater`

If `st` is greater than 0, sets `st` to 1; otherwise, sets it to 0.

### `fislessequal`

If `st` is 0 or less, sets `st` to 1; otherwise, sets it to 0.

### `fisgreaterequal`

If `st` is 0 or greater, sets `st` to 1; otherwise, sets it to 0.

### `fisnotequal`

If `st` is 0, sets `st` to 0; otherwise, sets it to 1.

### `inttofloat`

Interprets `reg` as an integer and sets it to a float of about the same value. TODO: specify edge cases.

### `floattoint`

Interprets `reg` as a float and sets it to its integer representation, rounded down. TODO: specify edge cases.

### `add`

Adds `from` to `to`.

### `sub`

Subtracts `from` from `to`.

### `mul`

Multiplies `from` and `to`, saving the result in `to`.

### `div`

Divides `dividend` by `divisor`, saving the quotient in `dividend`.

### `rem`

Divides `dividend` by `divisor`, saving the remainder in `dividend`.

### `fadd`

Adds `from` to `to`, interpreting both as floats.

### `fsub`

Subtracts `from` from `to`, interpreting both as floats.

### `fmul`

Multiplies `from` and `to`, interpreting both as floats, and saves the result in `to`.

### `fdiv`

Divides `dividend` by `divisor`, interpreting both as floats, and saves the quotient in `dividend`.

### `and`

Performs a binary AND on `to` and `from`, saving the result in `to`.

### `or`

Performs a binary OR on `to` and `from`, saving the result in `to`.

### `xor`

Performs a binary XOR on `to` and `from`, saving the result in `to`.

### `not`

Inverts the bits of `to`.
