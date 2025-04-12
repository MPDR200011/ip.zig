const std = @import("std");
const debug = std.debug;
const mem = std.mem;

const utils = @import("../utils.zig");

const ParseError = utils.ParseError;

/// An IPv4 address.
const Self = @This();

pub const Broadcast = Self.init(255, 255, 255, 255);
pub const Localhost = Self.init(127, 0, 0, 1);
pub const Unspecified = Self.init(0, 0, 0, 0);

address: [4]u8,

/// Create an IP Address with the given octets.
pub fn init(a: u8, b: u8, c: u8, d: u8) Self {
    return Self{
        .address = [_]u8{
            a,
            b,
            c,
            d,
        },
    };
}

/// Create an IP Address from a slice of bytes.
///
/// The slice must be exactly 4 bytes long.
pub fn fromSlice(address: []u8) Self {
    debug.assert(address.len == 4);

    return Self.init(address[0], address[1], address[2], address[3]);
}

/// Create an IP Address from an array of bytes.
pub fn fromArray(address: [4]u8) Self {
    return Self{
        .address = address,
    };
}

/// Create an IP Address from a host byte order u32.
pub fn fromHostByteOrder(ipVal: u32) Self {
    var address: [4]u8 = undefined;
    mem.writeInt(u32, &address, ipVal, .big);

    return Self.fromArray(address);
}

/// Parse an IP Address from a string representation.
pub fn parse(buf: []const u8) ParseError!Self {
    var octs: [4]u8 = [_]u8{0} ** 4;

    var octets_index: usize = 0;
    var any_digits: bool = false;

    for (buf) |b| {
        switch (b) {
            '.' => {
                if (!any_digits) {
                    return ParseError.InvalidCharacter;
                }

                if (octets_index >= 3) {
                    return ParseError.TooManyOctets;
                }

                octets_index += 1;
                any_digits = false;
            },
            '0'...'9' => {
                any_digits = true;

                const digit: u8 = b - '0';

                octs[octets_index], var overflow = @mulWithOverflow(octs[octets_index], @as(u8, 10));
                if (overflow == 1) {
                    return ParseError.Overflow;
                }

                octs[octets_index], overflow = @addWithOverflow(octs[octets_index], digit);
                if (overflow == 1) {
                    return ParseError.Overflow;
                }
            },
            else => {
                return ParseError.InvalidCharacter;
            },
        }
    }

    if (octets_index != 3 or !any_digits) {
        return ParseError.Incomplete;
    }

    return Self.fromArray(octs);
}

/// Returns the octets of an IP Address as an array of bytes.
pub fn octets(self: Self) [4]u8 {
    return self.address;
}

/// Returns whether an IP Address is an unspecified address as specified in _UNIX Network Programming, Second Edition_.
pub fn isUnspecified(self: Self) bool {
    return mem.allEqual(u8, &self.address, 0);
}

/// Returns whether an IP Address is a loopback address as defined by [IETF RFC 1122](https://tools.ietf.org/html/rfc1122).
pub fn isLoopback(self: Self) bool {
    return self.address[0] == 127;
}

/// Returns whether an IP Address is a private address as defined by [IETF RFC 1918](https://tools.ietf.org/html/rfc1918).
pub fn isPrivate(self: Self) bool {
    return switch (self.address[0]) {
        10 => true,
        172 => switch (self.address[1]) {
            16...31 => true,
            else => false,
        },
        192 => (self.address[1] == 168),
        else => false,
    };
}

/// Returns whether an IP Address is a link-local address as defined by [IETF RFC 3927](https://tools.ietf.org/html/rfc3927).
pub fn isLinkLocal(self: Self) bool {
    return self.address[0] == 169 and self.address[1] == 254;
}

/// Returns whether an IP Address is a multicast address as defined by [IETF RFC 5771](https://tools.ietf.org/html/rfc5771).
pub fn isMulticast(self: Self) bool {
    return switch (self.address[0]) {
        224...239 => true,
        else => false,
    };
}

/// Returns whether an IP Address is a broadcast address as defined by [IETF RFC 919](https://tools.ietf.org/html/rfc919).
pub fn isBroadcast(self: Self) bool {
    return mem.allEqual(u8, &self.address, 255);
}

/// Returns whether an IP Adress is a documentation address as defined by [IETF RFC 5737](https://tools.ietf.org/html/rfc5737).
pub fn isDocumentation(self: Self) bool {
    return switch (self.address[0]) {
        192 => switch (self.address[1]) {
            0 => switch (self.address[2]) {
                2 => true,
                else => false,
            },
            else => false,
        },
        198 => switch (self.address[1]) {
            51 => switch (self.address[2]) {
                100 => true,
                else => false,
            },
            else => false,
        },
        203 => switch (self.address[1]) {
            0 => switch (self.address[2]) {
                113 => true,
                else => false,
            },
            else => false,
        },
        else => false,
    };
}

/// Returns whether an IP Address is a globally routable address as defined by [the IANA IPv4 Special Registry](https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml).
pub fn isGloballyRoutable(self: Self) bool {
    return !self.isPrivate() and !self.isLoopback() and
        !self.isLinkLocal() and !self.isBroadcast() and
        !self.isDocumentation() and !self.isUnspecified();
}

/// Returns whether an IP Address is equal to another.
pub fn equals(self: Self, other: Self) bool {
    return mem.eql(u8, &self.address, &other.address);
}

/// Returns the IP Address as a host byte order u32.
pub fn toHostByteOrder(self: Self) u32 {
    return mem.readVarInt(u32, &self.address, .big);
}

/// Formats the IP Address using the given format string and context.
///
/// This is used by the `std.fmt` module to format an IP Address within a format string.
pub fn format(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    return try std.fmt.format(writer, "{}.{}.{}.{}", .{
        self.address[0],
        self.address[1],
        self.address[2],
        self.address[3],
    });
}
