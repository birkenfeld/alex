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

#define ILIT(n) (n)
#define IBOX(n) (n)
#define FAST_INT Int
#define GTE(n,m) (n >= m)
#define EQ(n,m) (n == m)
#define PLUS(n,m) (n + m)
#define MINUS(n,m) (n - m)
#define TIMES(n,m) (n * m)
#define NEGATE(n) (negate (n))
#define IF_GHC(x)

pub fn alexIndexInt16OffAddr(arr: &[isize], off: isize) -> isize {
    arr[off as usize]
}

pub fn alexIndexInt32OffAddr(arr: &[isize], off: isize) -> isize {
    arr[off as usize]
}

pub fn quickIndex<E>(arr: &[E], i: isize) -> &E {
    &arr[i as usize]
}

// -----------------------------------------------------------------------------
// Main lexing routines

pub enum AlexReturn<a> {
    AlexEOF,
    AlexError(AlexInput),
    AlexSkip(AlexInput, isize),
    AlexToken(AlexInput, isize, a)
}
pub use self::AlexReturn::*;

pub fn alexScan(input: (Position, InputStream), sc: isize)
                -> AlexReturn<Box<Fn(&mut Parser, Position, isize, InputStream) -> Res<Token>>> {
    // TODO first argument should be "undefined"
    alexScanUser(false, input, sc)
}

pub fn alexScanUser(user: bool, input: AlexInput, sc: isize)
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

pub fn alex_scan_tkn(mut user: bool, mut orig_input: AlexInput, mut len: isize, mut input: AlexInput,
                     mut s: isize, mut last_acc: AlexLastAcc) -> (AlexLastAcc, AlexInput) {
    fn check_accs<A: Clone>(user: A, orig_input: &AlexInput, len: isize, input: AlexInput,
                            last_acc: AlexLastAcc, acc: &AlexAcc<A>) -> AlexLastAcc {
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
            _ => panic!("predicates are not supported")
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
                println!("State: {}, char: {}", IBOX(s), c);
#endif
                match c as isize {
                    ord_c => {
                        let base = alexIndexInt32OffAddr(&ALEX_BASE, s);
                        let offset = base + ord_c;
                        let check = alexIndexInt16OffAddr(&ALEX_CHECK, offset);

                        let new_s = if offset >= 0 && check == ord_c {
                            alexIndexInt16OffAddr(&ALEX_TABLE, offset)
                        } else {
                            alexIndexInt16OffAddr(&ALEX_DEFLT, s)
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

pub enum AlexLastAcc {
    AlexNone,
    AlexLastAcc(isize, AlexInput, isize),
    AlexLastSkip(AlexInput, isize)
}
pub use self::AlexLastAcc::*;

pub enum AlexAcc<user> {
    AlexAccNone,
    AlexAcc(isize),
    AlexAccSkip,
    AlexAccPred(isize, Box<AlexAccPred<user>>, Box<AlexAcc<user>>),
    AlexAccSkipPred(Box<AlexAccPred<user>>, Box<AlexAcc<user>>)
}
pub use self::AlexAcc::*;

pub type AlexAccPred<user> = Box<Fn(user, AlexInput, isize, AlexInput) -> bool>;

// -----------------------------------------------------------------------------
// Predicates on a rule

pub fn alexAndPred<a: Clone>(p1: Box<Fn(a, AlexInput, isize, AlexInput) -> bool>,
                             p2: Box<Fn(a, AlexInput, isize, AlexInput) -> bool>,
                             user: a, in1: AlexInput, len: isize, in2: AlexInput) -> bool {
    p1(user.clone(), in1.clone(), len, in2.clone()) && p2(user, in1, len, in2)
}

pub fn alexPrevCharIs(c: char, _: isize, input: AlexInput, _: isize, _: isize) -> bool {
    c == alexInputPrevChar(input)
}

pub fn alexPrevCharMatches(f: Box<Fn(char) -> isize>, _: isize, input: AlexInput, _: isize, _: isize) -> isize {
    f(alexInputPrevChar(input))
}

pub fn alexPrevCharIsOneOf(arr: Vec<bool>, _: isize, input: AlexInput, _: isize, _: AlexInput) -> bool {
    __op_array_index(arr, alexInputPrevChar(input) as isize)
}

pub fn alexRightContext(sc: isize, user: bool, _: AlexInput, _: isize, input: AlexInput) -> bool {
    match alex_scan_tkn(user, input.clone(), (0), input, sc, AlexNone) {
        (AlexNone, _) => false,
        _ => true,
    }
}
