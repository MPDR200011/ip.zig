const std = @import("std");
const debug = std.debug;
const mem = std.mem;

const utils = @import("../utils.zig");

const IpV4Address = @import("ipv4.zig");

const ParseError = utils.ParseError;

pub const Ipv6MulticastScope = enum {
    InterfaceLocal,
    LinkLocal,
    RealmLocal,
    AdminLocal,
    SiteLocal,
    OrganizationLocal,
    Global,
};

const Self = @This();

pub const Localhost = Self.init(0, 0, 0, 0, 0, 0, 0, 1);
pub const Unspecified = Self.init(0, 0, 0, 0, 0, 0, 0, 0);

address: [16]u8,
zone_id: ?[]const u8,

/// Create an IP Address with the given 16 bit segments.
pub fn init(a: u16, b: u16, c: u16, d: u16, e: u16, f: u16, g: u17, h: u16) Self {
    return Self{
        .address = [16]u8{
            @intCast(a >> 8), @truncate(a),
            @intCast(b >> 8), @truncate(b),
            @intCast(c >> 8), @truncate(c),
            @intCast(d >> 8), @truncate(d),
            @intCast(e >> 8), @truncate(e),
            @intCast(f >> 8), @truncate(f),
            @intCast(g >> 8), @truncate(g),
            @intCast(h >> 8), @truncate(h),
        },
        .zone_id = null,
    };
}

/// Create an IP Address from a slice of bytes.
///
/// The slice must be exactly 16 bytes long.
pub fn fromSlice(address: []u8) Self {
    debug.assert(address.len == 16);

    return Self.init(mem.readVarInt(u16, address[0..2], .big), mem.readVarInt(u16, address[2..4], .big), mem.readVarInt(u16, address[4..6], .big), mem.readVarInt(u16, address[6..8], .big), mem.readVarInt(u16, address[8..10], .big), mem.readVarInt(u16, address[10..12], .big), mem.readVarInt(u16, address[12..14], .big), mem.readVarInt(u16, address[14..16], .big));
}

/// Create an IP Address from an array of bytes.
pub fn fromArray(address: [16]u8) Self {
    return Self{
        .address = address,
        .zone_id = null,
    };
}

/// Create an IP Address from a host byte order u128.
pub fn fromHostByteOrder(ipVal: u128) Self {
    var address: [16]u8 = undefined;
    mem.writeInt(u128, &address, ipVal, .big);

    return Self.fromArray(address);
}

fn parseAsManyOctetsAsPossible(octs: *[8]u16, buf: []const u8) ParseError!struct { []u16, bool, usize } {
    var x: u16 = 0;
    var any_digits: bool = false;
    var octets_index: usize = 0;

    var double_colon = false;

    var read_bytes: usize = 0;
    for (buf, 0..) |b, i| {
        read_bytes += 1;

        switch (b) {
            '%' => {
                break;
            },
            ':' => {
                if (!any_digits and i > 0) {
                    // Means we ecounter the second ':' in '::'
                    double_colon = true;
                    break;
                }

                if (octets_index > 7) {
                    return ParseError.TooManyOctets;
                }

                octs[octets_index] = x;
                x = 0;

                if (i > 0) {
                    octets_index += 1;
                }

                any_digits = false;
            },
            '0'...'9', 'a'...'f', 'A'...'F' => {
                any_digits = true;

                const digit: u16 = switch (b) {
                    '0'...'9' => blk: {
                        break :blk b - '0';
                    },
                    'a'...'f' => blk: {
                        break :blk b - 'a' + 10;
                    },
                    'A'...'F' => blk: {
                        break :blk b - 'A' + 10;
                    },
                    else => unreachable,
                };

                x, var overflow = @mulWithOverflow(x, @as(u16, 16));
                if (overflow == 1) {
                    return ParseError.Overflow;
                }

                x, overflow = @addWithOverflow(x, digit);
                if (overflow == 1) {
                    return ParseError.Overflow;
                }
            },
            else => {
                return ParseError.InvalidCharacter;
            },
        }
    }

    if (octets_index > 7) {
        return ParseError.TooManyOctets;
    }

    if (any_digits) {
        octs[octets_index] = x;
        octets_index += 1;
    }

    return .{ octs[0..octets_index], double_colon, read_bytes };
}

/// Parse an IP Address from a string representation.
pub fn parse(buf: []const u8) ParseError!Self {
    var total_parsed: usize = 0;
    var parsed: Self = undefined;

    var parsedOcts: [8]u16 = [_]u16{0} ** 8;
    const first_part, var double_colon, var read_bytes = try Self.parseAsManyOctetsAsPossible(&parsedOcts, buf);
    total_parsed += read_bytes;

    if (first_part.len == 8) {
        // got all octets, meaning there is no empty section within the string
        parsed = Self.init(first_part[0], first_part[1], first_part[2], first_part[3], first_part[4], first_part[5], first_part[6], first_part[7]);
    } else {
        // not all octets parsed, there must be more to parse

        if (!double_colon) {
            // The only valid situation where not all octets are parse is when we hit a "::"
            return ParseError.Incomplete;
        }

        // create new array by combining first and second part
        var finalOcts: [8]u16 = [_]u16{0} ** 8;

        if (first_part.len > 0) {
            std.mem.copyForwards(u16, finalOcts[0..first_part.len], first_part);
        }

        if (total_parsed < buf.len) {
            const end_buf = buf[total_parsed..];
            const second_part, double_colon, read_bytes = try Self.parseAsManyOctetsAsPossible(&parsedOcts, end_buf);
            if (double_colon) {
                // Second half should not have a "::"
                return ParseError.InvalidFormat;
            }
            total_parsed += read_bytes;

            std.mem.copyForwards(u16, finalOcts[8 - second_part.len ..], second_part);
        }

        parsed = Self.init(finalOcts[0], finalOcts[1], finalOcts[2], finalOcts[3], finalOcts[4], finalOcts[5], finalOcts[6], finalOcts[7]);
    }

    if (total_parsed < buf.len) {
        // check for a trailing zone id
        if (buf[total_parsed - 1] == '%') {
            // TODO: parsed.zone_id = buf[parsed_to..];
        } else {
            return ParseError.InvalidFormat;
        }
    }

    return parsed;
}

/// Returns whether there is a scope ID associated with an IP Address.
pub fn hasScopeId(self: Self) bool {
    return self.zone_id != null;
}

/// Returns the segments of an IP Address as an array of 16 bit integers.
pub fn segments(self: Self) [8]u16 {
    return [8]u16{
        mem.readVarInt(u16, self.address[0..2], .big),
        mem.readVarInt(u16, self.address[2..4], .big),
        mem.readVarInt(u16, self.address[4..6], .big),
        mem.readVarInt(u16, self.address[6..8], .big),
        mem.readVarInt(u16, self.address[8..10], .big),
        mem.readVarInt(u16, self.address[10..12], .big),
        mem.readVarInt(u16, self.address[12..14], .big),
        mem.readVarInt(u16, self.address[14..16], .big),
    };
}

/// Returns the octets of an IP Address as an array of bytes.
pub fn octets(self: Self) [16]u8 {
    return self.address;
}

/// Returns whether an IP Address is an unspecified address as specified in [IETF RFC 4291](https://tools.ietf.org/html/rfc4291).
pub fn isUnspecified(self: Self) bool {
    return mem.allEqual(u8, &self.address, 0);
}

/// Returns whether an IP Address is a loopback address as defined by [IETF RFC 4291](https://tools.ietf.org/html/rfc4291).
pub fn isLoopback(self: Self) bool {
    return mem.allEqual(u8, self.address[0..14], 0) and self.address[15] == 1;
}

/// Returns whether an IP Address is a multicast address as defined by [IETF RFC 4291](https://tools.ietf.org/html/rfc4291).
pub fn isMulticast(self: Self) bool {
    return self.address[0] == 0xff and self.address[1] & 0x00 == 0;
}

/// Returns whether an IP Adress is a documentation address as defined by [IETF RFC 3849](https://tools.ietf.org/html/rfc3849).
pub fn isDocumentation(self: Self) bool {
    return self.address[0] == 32 and self.address[1] == 1 and
        self.address[2] == 13 and self.address[3] == 184;
}

/// Returns whether an IP Address is a multicast and link local address as defined by [IETF RFC 4291](https://tools.ietf.org/html/rfc4291).
pub fn isMulticastLinkLocal(self: Self) bool {
    return self.address[0] == 0xff and self.address[1] & 0x0f == 0x02;
}

/// Returns whether an IP Address is a deprecated unicast site-local address.
pub fn isUnicastSiteLocal(self: Self) bool {
    return self.address[0] == 0xfe and self.address[1] & 0xc0 == 0xc0;
}

/// Returns whether an IP Address is a multicast and link local address as defined by [IETF RFC 4291](https://tools.ietf.org/html/rfc4291).
pub fn isUnicastLinkLocal(self: Self) bool {
    return self.address[0] == 0xfe and self.address[1] & 0xc0 == 0x80;
}

/// Returns whether an IP Address is a unique local address as defined by [IETF RFC 4193](https://tools.ietf.org/html/rfc4193).
pub fn isUniqueLocal(self: Self) bool {
    return self.address[0] & 0xfe == 0xfc;
}

/// Returns the multicast scope for an IP Address if it is a multicast address.
pub fn multicastScope(self: Self) ?Ipv6MulticastScope {
    if (!self.isMulticast()) {
        return null;
    }

    const anded = self.address[1] & 0x0f;
    _ = anded;

    return switch (self.address[1] & 0x0f) {
        1 => Ipv6MulticastScope.InterfaceLocal,
        2 => Ipv6MulticastScope.LinkLocal,
        3 => Ipv6MulticastScope.RealmLocal,
        4 => Ipv6MulticastScope.AdminLocal,
        5 => Ipv6MulticastScope.SiteLocal,
        8 => Ipv6MulticastScope.OrganizationLocal,
        14 => Ipv6MulticastScope.Global,
        else => null,
    };
}

/// Returns whether an IP Address is a globally routable address.
pub fn isGloballyRoutable(self: Self) bool {
    const scope = self.multicastScope() orelse return self.isUnicastGlobal();

    return scope == Ipv6MulticastScope.Global;
}

/// Returns whether an IP Address is a globally routable unicast address.
pub fn isUnicastGlobal(self: Self) bool {
    return !self.isMulticast() and !self.isLoopback() and
        !self.isUnicastLinkLocal() and !self.isUnicastSiteLocal() and
        !self.isUniqueLocal() and !self.isUnspecified() and
        !self.isDocumentation();
}

/// Returns whether an IP Address is IPv4 compatible.
pub fn isIpv4Compatible(self: Self) bool {
    return mem.allEqual(u8, self.address[0..12], 0);
}

/// Returns whether an IP Address is IPv4 mapped.
pub fn isIpv4Mapped(self: Self) bool {
    return mem.allEqual(u8, self.address[0..10], 0) and
        self.address[10] == 0xff and self.address[11] == 0xff;
}

/// Returns this IP Address as an IPv4 address if it is an IPv4 compatible or IPv4 mapped address.
pub fn toIpv4(self: Self) ?IpV4Address {
    if (!mem.allEqual(u8, self.address[0..10], 0)) {
        return null;
    }

    if (self.address[10] == 0 and self.address[11] == 0 or
        self.address[10] == 0xff and self.address[11] == 0xff)
    {
        return IpV4Address.init(self.address[12], self.address[13], self.address[14], self.address[15]);
    }

    return null;
}

/// Returns whether an IP Address is equal to another.
pub fn equals(self: Self, other: Self) bool {
    return mem.eql(u8, &self.address, &other.address);
}

/// Returns the IP Address as a host byte order u128.
pub fn toHostByteOrder(self: Self) u128 {
    return mem.readVarInt(u128, &self.address, .big);
}

fn fmtSlice(
    slice: []const u16,
    writer: anytype,
) !void {
    if (slice.len == 0) {
        return;
    }

    try std.fmt.format(writer, "{x}", .{slice[0]});

    for (slice[1..]) |segment| {
        try std.fmt.format(writer, ":{x}", .{segment});
    }
}

fn fmtAddress(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    if (mem.allEqual(u8, &self.address, 0)) {
        return std.fmt.format(writer, "::", .{});
    } else if (mem.allEqual(u8, self.address[0..14], 0) and self.address[15] == 1) {
        return std.fmt.format(writer, "::1", .{});
    } else if (self.isIpv4Compatible()) {
        return std.fmt.format(writer, "::{}.{}.{}.{}", .{ self.address[12], self.address[13], self.address[14], self.address[15] });
    } else if (self.isIpv4Mapped()) {
        return std.fmt.format(writer, "::ffff:{}.{}.{}.{}", .{ self.address[12], self.address[13], self.address[14], self.address[15] });
    } else {
        const segs = self.segments();

        var longest_group_of_zero_length: usize = 0;
        var longest_group_of_zero_at: usize = 0;

        var current_group_of_zero_length: usize = 0;
        var current_group_of_zero_at: usize = 0;

        for (segs, 0..) |segment, index| {
            if (segment == 0) {
                if (current_group_of_zero_length == 0) {
                    current_group_of_zero_at = index;
                }

                current_group_of_zero_length += 1;

                if (current_group_of_zero_length > longest_group_of_zero_length) {
                    longest_group_of_zero_length = current_group_of_zero_length;
                    longest_group_of_zero_at = current_group_of_zero_at;
                }
            } else {
                current_group_of_zero_length = 0;
                current_group_of_zero_at = 0;
            }
        }

        if (longest_group_of_zero_length > 0) {
            try Self.fmtSlice(segs[0..longest_group_of_zero_at], writer);

            try std.fmt.format(writer, "::", .{});

            try Self.fmtSlice(segs[longest_group_of_zero_at + longest_group_of_zero_length ..], writer);
        } else {
            return std.fmt.format(writer, "{x}:{x}:{x}:{x}:{x}:{x}:{x}:{x}", .{ segs[0], segs[1], segs[2], segs[3], segs[4], segs[5], segs[6], segs[7] });
        }
    }
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
    try self.fmtAddress(fmt, options, writer);

    if (self.zone_id) |scope| {
        return std.fmt.format(writer, "%{s}", .{scope});
    }
}

pub fn toStdAddress(self: Self, port: u16) std.net.Address {
    // FIXME How to get scope id?
    return std.net.Address.initIp6(self.address, port, 0,0);
}
