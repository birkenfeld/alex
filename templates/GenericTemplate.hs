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
    AlexError(AlexInput),
    AlexSkip(AlexInput, isize),
    AlexToken(AlexInput, isize, T)
}
use self::AlexReturn::*;

fn alexScan(input: (Position, InputStream), sc: isize)
            -> AlexReturn<Box<Fn(&mut Parser, Position, isize, InputStream) -> Res<Token>>> {
    // TODO first argument should be "undefined"
    alexScanUser(false, input, sc)
}

fn alexScanUser(user: bool, input: AlexInput, sc: isize)
                -> AlexReturn<Box<Fn(&mut Parser, Position, isize, InputStream) -> Res<Token>>>
{
    match alex_scan_tkn(user, input.clone(), (0), input.clone(), sc, AlexNone) {
        (AlexNone, input_q) => {
            match alexGetByte(input) {
                None => {
#ifdef ALEX_DEBUG
                    println!("End of input.");
#endif
                    AlexEOF
                },
                Some(_) => {
#ifdef ALEX_DEBUG
                    println!("Error.");
#endif
                    AlexError(input_q)
                },
            }
        },
        (AlexLastSkip(input_q_q, len), _) => {
#ifdef ALEX_DEBUG
            println!("Skipping.");
#endif
            AlexSkip(input_q_q, len)
        },
        (AlexLastAcc(k, input_q_q_q, len), _) => {
#ifdef ALEX_DEBUG
            println!("Accept.");
#endif
            AlexToken(input_q_q_q, len, box ALEX_ACTIONS[k as usize])
        },
    }
}


/// Push the input through the DFA, remembering the most recent accepting
/// state it encountered.

fn alex_scan_tkn(mut user: bool, mut orig_input: AlexInput, mut len: isize, mut input: AlexInput,
                 mut s: isize, mut last_acc: AlexLastAcc) -> (AlexLastAcc, AlexInput) {
    fn check_accs<A: Clone>(user: A, orig_input: &AlexInput, len: isize, input: AlexInput,
                            last_acc: AlexLastAcc, acc: &AlexAcc) -> AlexLastAcc {
        match *acc {
            AlexAccNone => {
                last_acc
            },
            AlexAcc(a) => {
                AlexLastAcc(a, input, len)
            },
            AlexAccSkip => {
                AlexLastSkip(input, len)
            },
        }
    };

    loop {
        let right = &ALEX_ACCEPT[s as usize];
        let new_acc = check_accs(user, &orig_input, len, input.clone(), last_acc, right);

        match alexGetByte(input.clone()) {
            None => {
                return (new_acc, input)
            },
            Some((c, new_input)) => {
#ifdef ALEX_DEBUG
                println!("State: {}, char: {}", s, c);
#endif
                match c as isize {
                    ord_c => {
                        let base = ALEX_BASE[s as usize];
                        let offset = base + ord_c;
                        let check = ALEX_CHECK[offset as usize];

                        let new_s = if offset >= 0 && check == ord_c {
                            ALEX_TABLE[offset as usize]
                        } else {
                            ALEX_DEFLT[s as usize]
                        };

                        match new_s {
                            -1 => {
                                return (new_acc, input)
                            },
                            _ => {
                                user = user;
                                orig_input = orig_input;
                                len = if c < 128 || c >= 192 {
                                    len + 1
                                } else {
                                    len
                                };
                                input = new_input;
                                s = new_s;
                                last_acc = new_acc;
                            },
                        }
                    },
                }
            },
        }
    }
}

enum AlexLastAcc {
    AlexNone,
    AlexLastAcc(isize, AlexInput, isize),
    AlexLastSkip(AlexInput, isize)
}
use self::AlexLastAcc::*;

enum AlexAcc {
    AlexAccNone,
    AlexAcc(isize),
    AlexAccSkip,
}
use self::AlexAcc::*;
