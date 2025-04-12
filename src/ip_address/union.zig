const std = @import("std");

const utils = @import("../utils.zig");

const ParseError = utils.ParseError;

const IpV4Address = @import("ipv4.zig");
const IpV6Address = @import("ipv6.zig");

pub const IpAddressType = enum {
    V4,
    V6,
};

pub const IpAddress = union(IpAddressType) {
    const Self = @This();

    V4: IpV4Address,
    V6: IpV6Address,

    /// Parse an IP Address from a string representation.
    pub fn parse(buf: []const u8) ParseError!Self {
        for (buf) |b| {
            switch (b) {
                '.' => {
                    // IPv4
                    const addr = try IpV4Address.parse(buf);

                    return Self{
                        .V4 = addr,
                    };
                },
                ':' => {
                    // IPv6
                    const addr = try IpV6Address.parse(buf);

                    return Self{
                        .V6 = addr,
                    };
                },
                else => continue,
            }
        }

        return ParseError.UnknownAddressType;
    }

    /// Returns whether the IP Address is an IPv4 address.
    pub fn isIpv4(self: Self) bool {
        return switch (self) {
            .V4 => true,
            else => false,
        };
    }

    /// Returns whether the IP Address is an IPv6 address.
    pub fn isIpv6(self: Self) bool {
        return switch (self) {
            .V6 => true,
            else => false,
        };
    }

    /// Returns whether an IP Address is an unspecified address.
    pub fn isUnspecified(self: Self) bool {
        return switch (self) {
            .V4 => |a| a.isUnspecified(),
            .V6 => |a| a.isUnspecified(),
        };
    }

    /// Returns whether an IP Address is a loopback address.
    pub fn isLoopback(self: Self) bool {
        return switch (self) {
            .V4 => |a| a.isLoopback(),
            .V6 => |a| a.isLoopback(),
        };
    }

    /// Returns whether an IP Address is a multicast address.
    pub fn isMulticast(self: Self) bool {
        return switch (self) {
            .V4 => |a| a.isMulticast(),
            .V6 => |a| a.isMulticast(),
        };
    }

    /// Returns whether an IP Adress is a documentation address.
    pub fn isDocumentation(self: Self) bool {
        return switch (self) {
            .V4 => |a| a.isDocumentation(),
            .V6 => |a| a.isDocumentation(),
        };
    }

    /// Returns whether an IP Address is a globally routable address.
    pub fn isGloballyRoutable(self: Self) bool {
        return switch (self) {
            .V4 => |a| a.isGloballyRoutable(),
            .V6 => |a| a.isGloballyRoutable(),
        };
    }

    /// Returns whether an IP Address is equal to another.
    pub fn equals(self: Self, other: Self) bool {
        return switch (self) {
            .V4 => |a| blk: {
                break :blk switch (other) {
                    .V4 => |b| a.equals(b),
                    else => false,
                };
            },
            .V6 => |a| blk: {
                break :blk switch (other) {
                    .V6 => |b| a.equals(b),
                    else => false,
                };
            },
        };
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
        return switch (self) {
            .V4 => |a| a.format(fmt, options, writer),
            .V6 => |a| a.format(fmt, options, writer),
        };
    }
};
