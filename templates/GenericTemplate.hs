// -----------------------------------------------------------------------------
// ALEX TEMPLATE
//
// This code is in the PUBLIC DOMAIN; you may copy it freely and use
// it for any purpose whatsoever.
//
//-----------------------------------------------------------------------------
// INTERNALS and main scanner engine

#ifdef ALEX_GHC
compile_error!("GHC mode is not supported")
#endif

// -----------------------------------------------------------------------------
// Main lexing routines

enum AlexReturn<T> {
    AlexEOF,
    AlexError,
    AlexSkip(usize),
    AlexToken(usize, usize, T)
}
use self::AlexReturn::*;

enum AlexLastAcc {
    AlexNone,
    AlexLastAcc(usize, usize, usize),
    AlexLastSkip(usize)
}
use self::AlexLastAcc::*;

enum AlexAcc {
    AlexAccNone,
    AlexAcc(usize),
    AlexAccSkip,
}
use self::AlexAcc::*;

type AlexAction = fn(&mut Parser, Position, usize) -> Res<Token>;

fn alexScan(input: &mut AlexInput) -> AlexReturn<AlexAction> {
    match alex_scan_tkn(input) {
        AlexNone => {
            if alexGetByte(input).is_some() {
#ifdef ALEX_DEBUG
                println!("Error.");
#endif
                AlexError
            } else {
#ifdef ALEX_DEBUG
                println!("End of input.");
#endif
                AlexEOF
            }
        },
        AlexLastSkip(len_bytes) => {
#ifdef ALEX_DEBUG
            println!("Skipping.");
#endif
            AlexSkip(len_bytes)
        },
        AlexLastAcc(k, len_bytes, len_chars) => {
#ifdef ALEX_DEBUG
            println!("Accept.");
#endif
            AlexToken(len_bytes, len_chars, ALEX_ACTIONS[k])
        },
    }
}


/// Push the input through the DFA, remembering the most recent accepting
/// state it encountered.

fn alex_scan_tkn(input: &mut AlexInput) -> AlexLastAcc {
    let mut last_acc = AlexNone;
    let mut len_bytes = 0;
    let mut len_chars = 0;
    let mut s = 0;
    loop {
        let right = &ALEX_ACCEPT[s as usize];
        let new_acc = match *right {
            AlexAccNone => last_acc,
            AlexAcc(a)  => AlexLastAcc(a, len_bytes, len_chars),
            AlexAccSkip => AlexLastSkip(len_bytes),
        };

        match alexGetByte(input) {
            None => return new_acc,
            Some(c) => {
                let c = c as isize;
#ifdef ALEX_DEBUG
                println!("State: {}, char: {}", s, c);
#endif
                let base = ALEX_BASE[s as usize];
                let offset = base + c;

                let new_s = if offset >= 0 && ALEX_CHECK[offset as usize] == c {
                    ALEX_TABLE[offset as usize]
                } else {
                    ALEX_DEFLT[s as usize]
                };

                if new_s == -1 {
                    return new_acc;
                } else {
                    len_bytes += 1;
                    len_chars += if c < 128 || c >= 192 { 1 } else { 0 };
                    s = new_s;
                    last_acc = new_acc;
                }
            }
        }
    }
}
