# Experimental Z80 compiler

Inspired by a few things:

* Reading about how C translates poorly to Z80 assembler
* Wondering what might translate well to Z80 assembler
* A poor understanding of LLVM IR
* Trying to write Z80 assembler and doing a lot of register juggling

There is a space for something between assembly and C. Something like structured assembly.

## An example

This is an example of three nested loops inside a procedure:

    namespace m8fs

    .base = 0x0400
    .files_per_block = 8
    .file_entry_len = 8

    hl <= blkc_find[i nn l] {
        luz[i] {
            aa = blk_addr[i]
            a = .files_per_block
            luzd[a] {
                bb = aa
                cc = nn
                b = l
                luzd[b] {
                    break (*cc != *bb)
                    ++cc
                    ++bb
                    |
                    <= aa
                }
                aa = aa + .file_entry_len
            }
            ab = i * 2
            ac = ab + .base
            ++ac
            i = *ac
        }
    }

## Syntax

### Namespaces

Each time this is encountered:

    namespace m8fs

Everything after that (constants and procedures) have `m8fs_` prepended. This allows for multiple files to be assembled into one without label clashes.

### Constants

These are immutable values for convenience:

    .base = 0x0400
    .files_per_block = 8
    .file_entry_len = 8

They always start with a `.` to make life easier for the parser.

### Types

There are only two types: 8 bit integers and 16 bit integers.

### Variables

All variables are one or two characters in length. One character variables are 8 bit integers, two character variables are 16 bit integers. They will be mapped to Z80 registers depending on their scope and the capabilities required of them.

### Procedures

Procedures are a definition, with a list of statements wrapped in curly braces:

    hl <= blkc_find[i nn l] {
        <statements>
    }

They have an optional return type (by convention named `l` or `hl` depending on 8 or 16 bit), a name and an argument list. The arguments are separated by spaces. The calling convention is to push arguments from left to right, then `call` the function, with an 8 bit return value in l or a 16 bit return value in hl.

### Loops

There are only two loop types:

1. `luz` (loop-until-zero)
1. `luzd` (loop-until-zero-decrement)

    luz[b] {
        statements...
    }

    luzd[b] {
        statements...
    }

They take a single variable as an argument. In both cases the loop will end when the variable has a zero value. In the case of `luzd` this variable is automatically decremented on each pass of the loop. There are only two ways to exit a loop:

1. Make the variable zero (in the case of `luzd` by waiting for that to happen naturally, or explicitly by "shorting" the variable)
1. With a `break TEST` statement

#### Loop posts

One of the possible statements inside a loop is the post `|`. If the loop "falls through" naturally by the variable going to zero the block of statements after the post is executed. If the TEST in a `break TEST` is encountered the loop is exited *without* executing the code after the post:

    luzd[b] {
        aa = 10
        break (aa == 10)
        |
        aa = 20
    }

Here the code will break from the loop early and skip the `aa = 20` statement.

### Statements

Statements can be of several forms:

#### Return

Returns can happen anywhere inside a procedure:

    <= aa + ab

#### Increment or decrement

Increment or decrement a variable:

    ++a
    --bb
    ++*aa

#### Post

A post indicates a chunk of code that will execute when a loop condition exits due to the loop variable reaching zero:

    luzd[b] {
        aa = 10
        break (aa == 10)
        |
        aa = 20
    }
    
#### Break on Condition

Break from a loop early if a condition is met:

    break (aa == 10)

#### Loop

Loops X number of times until X becomes zero:

    luz[b] {}
    luzd[b] {}

#### Assignment

An assignment is to set a variable according to an expression, like:

Indirect memory access:

    a = *ab

Ternary:

    a = (b == 12) ? 13 : 14

A procedure call:

    a = someproc[c]

An operation on two values:

    a = b * 16

Or a value, like:

    a = 5
    a = c
    a = .constant

## Basic Blocks

I suppose most compilers try to break the code into basic blocks. In this compiler basic blocks are split on the following:

1. A procedure start of a basic block
1. Loop beginnings
1. Post statements inside loops
1. Loop ends

For the example procedure above the blocks would look like this:

    hl <= blkc_find[i nn l] {
    0------------------------------------------
        luz[i] {
            aa = blk_addr[i]
            a = .files_per_block
    1------------------------------------------
            luzd[a] {
                bb = aa
                cc = nn
                b = l
    2------------------------------------------
                luzd[b] {
                    break (*cc != *bb)
                    ++cc
                    ++bb
    3------------------------------------------
                    |
                    <= aa
                }
    4------------------------------------------
                aa = aa + .file_entry_len
            }
    5------------------------------------------
            ab = i * 2
            ac = ab + .base
            ++ac
            i = *ac
        }
    }

Each block boundry would generate a label. For example the `break (*cc != *bb)` would generate a jump to label `4` if the test is true. The `luzd[b] {` label `2` would be the destination for a `djnz`.
