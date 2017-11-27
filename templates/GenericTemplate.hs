// -----------------------------------------------------------------------------
// ALEX TEMPLATE
//
// This code is in the PUBLIC DOMAIN; you may copy it freely and use
// it for any purpose whatsoever.
//
// -----------------------------------------------------------------------------
// INTERNALS and main scanner engine

#ifdef ALEX_GHC
compile_error!("GHC mode is not supported")
#endif

// -----------------------------------------------------------------------------
// Main lexing routines

enum AlexReturn<T> {
    EOF,
    Error,
    Skip(usize),
    Token(usize, usize, T),
}

enum AlexLastAcc {
    None,
    Skip(usize),
    Token(usize, usize, usize),
}

enum AlexAcc {
    None,
    Skip,
    Token(usize),
}

type AlexAction = fn(&mut Parser, Position, usize) -> Res<Token>;

fn alex_scan(input: &mut AlexInput) -> AlexReturn<AlexAction> {
    match alex_scan_tkn(input) {
        AlexLastAcc::None => {
            if alex_get_byte(input).is_some() {
#ifdef ALEX_DEBUG
                println!("Error.");
#endif
                AlexReturn::Error
            } else {
#ifdef ALEX_DEBUG
                println!("End of input.");
#endif
                AlexReturn::EOF
            }
        },
        AlexLastAcc::Skip(len_bytes) => {
#ifdef ALEX_DEBUG
            println!("Skipping.");
#endif
            AlexReturn::Skip(len_bytes)
        },
        AlexLastAcc::Token(k, len_bytes, len_chars) => {
#ifdef ALEX_DEBUG
            println!("Accept.");
#endif
            AlexReturn::Token(len_bytes, len_chars, ALEX_ACTIONS[k])
        },
    }
}


/// Push the input through the DFA, remembering the most recent accepting
/// state it encountered.

fn alex_scan_tkn(input: &mut AlexInput) -> AlexLastAcc {
    let mut last_acc = AlexLastAcc::None;
    let mut len_bytes = 0;
    let mut len_chars = 0;
    let mut s = 0;
    loop {
        let right = &ALEX_ACCEPT[s as usize];
        let new_acc = match *right {
            AlexAcc::None => last_acc,
            AlexAcc::Token(a)  => AlexLastAcc::Token(a, len_bytes, len_chars),
            AlexAcc::Skip => AlexLastAcc::Skip(len_bytes),
        };

        match alex_get_byte(input) {
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
