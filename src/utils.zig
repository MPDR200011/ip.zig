
/// Errors that can occur when parsing an IP Address.
pub const ParseError = error{
    InvalidCharacter,
    TooManyOctets,
    Overflow,
    Incomplete,
    UnknownAddressType,
    InvalidFormat,
};

