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
    AlexSkip(isize),
    AlexToken(isize, T)
}
use self::AlexReturn::*;

enum AlexLastAcc {
    AlexNone,
    AlexLastAcc(isize, isize),
    AlexLastSkip(isize)
}
use self::AlexLastAcc::*;

enum AlexAcc {
    AlexAccNone,
    AlexAcc(isize),
    AlexAccSkip,
}
use self::AlexAcc::*;

type AlexAction = fn(&mut Parser, Position, isize) -> Res<Token>;

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
        AlexLastSkip(len) => {
#ifdef ALEX_DEBUG
            println!("Skipping.");
#endif
            AlexSkip(len)
        },
        AlexLastAcc(k, len) => {
#ifdef ALEX_DEBUG
            println!("Accept.");
#endif
            AlexToken(len, ALEX_ACTIONS[k as usize])
        },
    }
}


/// Push the input through the DFA, remembering the most recent accepting
/// state it encountered.

fn alex_scan_tkn(input: &mut AlexInput) -> AlexLastAcc {
    let mut last_acc = AlexNone;
    let mut len = 0;
    let mut s = 0;
    loop {
        let right = &ALEX_ACCEPT[s as usize];
        let new_acc = match *right {
            AlexAccNone => last_acc,
            AlexAcc(a)  => AlexLastAcc(a, len),
            AlexAccSkip => AlexLastSkip(len),
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
                let check = ALEX_CHECK[offset as usize];

                let new_s = if offset >= 0 && check == c {
                    ALEX_TABLE[offset as usize]
                } else {
                    ALEX_DEFLT[s as usize]
                };

                if new_s == -1 {
                    return new_acc;
                } else {
                    len += if c < 128 || c >= 192 { 1 } else { 0 };
                    s = new_s;
                    last_acc = new_acc;
                }
            }
        }
    }
}
