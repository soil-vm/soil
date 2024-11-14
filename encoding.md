## Soil Binaries

Here is a grammar what the Soil binaries contain.
In the grammar, letters and dashes (like `section` or `magic-bytes`) represent non-terminals.
All numbers are in hexadecimal notation and each group of two digits (like `b0` or `00`) represent a byte.
Everything in parentheses in the grammar is just a comment.

```
byte = (an unsigned 8-bit integer, enocded in little endian)
word = (a signed 64-bit integer, enocded in little endian)

soil-binary     := magic-bytes sections
magic-bytes     := 73 6f 69 6c ("soil" in ASCII)
sections        := section *
section         := byte-code | initial-memory | name | label | description | other-section

other-section   := section-id section-length (length of section-content) section-content
section-id      := byte
section-length  := word
section-content := byte *

byte-code                     := byte-code-id section-length instructions
byte-code-id                  := 00
instructions                  := instruction *
instruction                   := nop | error-instructions | data-instructions | flow-instructions | compare-instructions | arithmetic-instructions | binary-instructions
error-instructions            := panic | trystart | tryend
data-instructions             := move | movei | moveb | moveib | load | loadb | store | storeb | push | pop
flow-instructions             := jump | cjump | call | ret | syscall
compare-instructions          := int-compare-instructions | float-compare-instructions
int-compare-instructions      := cmp | isequal | isless | isgreater | islessequal | isgreaterequal | isnotequal
float-compare-instructions    := fcmp | fisequal | fisless | fisgreater | fislessequal | fisgreaterequal | fisnotequal
arithmetic-instructions       := int-arithmetic-instructions | float-arithmetic-instructions
int-arithmetic-instructions   := add | sub | mul | div | mod
float-arithmetic-instructions := fadd | fsub | fmul | fdiv
binary-instructions           := and | or | xor | not

nop             := 00
panic           := e0
trystart        := e1 word
tryend          := e2
move            := d0 regs
movei           := d1 reg word
moveib          := d2 reg byte
load            := d3 regs
loadb           := d4 regs
store           := d5 regs
storeb          := d6 regs
push            := d7 reg
pop             := d8 reg
jump            := f0 word
cjump           := f1 word
call            := f2 word
ret             := f3
syscall         := f4 byte
cmp             := c0 regs
isequal         := c1
isless          := c2
isgreater       := c3
islessequal     := c4
isgreaterequal  := c5
isnotequal      := c6
fcmp            := c7 regs
fisequal        := c8
fisless         := c9
fisgreater      := ca
fislessequal    := cb
fisgreaterequal := cc
fisnotequal     := cd
inttofloat      := ce reg
floattoint      := cf reg
add             := a0 regs
sub             := a1 regs
mul             := a2 regs
div             := a3 regs
mod             := a4 regs
fadd            := a5 regs
fsub            := a6 regs
fmul            := a7 regs
fdiv            := a8 regs
and             := b0 regs
or              := b1 regs
xor             := b2 regs
not             := b3 regs

reg        := <bits 0000> reg-4-bits
regs       := reg-4-bits reg-4-bits
reg-4-bits := reg-sp | reg-st | reg-a | reg-b | reg-c | reg-d | reg-e | reg-f
reg-sp     := <bits 0000>
reg-st     := <bits 0001>
reg-a      := <bits 0010>
reg-b      := <bits 0011>
reg-c      := <bits 0100>
reg-d      := <bits 0101>
reg-e      := <bits 0110>
reg-f      := <bits 0111>
```

Note that you can interpret any section as `other-section`.
Because you know the length of the section content, you can skip sections that you are not interested in.

To make memorization easier, the first characters of the instruction hex opcodes describe what kind of instruction it is:

- 00: nop
- a\*: arithmetic
- b\*: binary
- c\*: comparisons / conversions
- d\*: data operations
- e\*: error
- f\*: control flow

