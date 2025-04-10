# ip.zig

A Zig library for working with IP Addresses

Forked from: [https://github.com/euantorano/ip.zig](https://github.com/euantorano/ip.zig)

## Installation

```
zig fetch --save https://github.com/MPDR200011/ip.zig/archive/master.tar.gz
```

## Current Status

- [X] Constructing IPv4/IPv6 addresses from octets or bytes
- [X] IpAddress union
- [X] Various utility methods for working with IP addresses, such as: comparing for equality; checking for loopback/multicast/globally routable
- [X] Formatting IPv4/IPv6 addresses using `std.format`
- [ ] Parsing IPv4/IPv6 addresses from strings
    - [X] Parsing IPv4 addresses
    - [ ] Parsing IPv6 addresses
        - [X] Parsing simple IPv6 addresses
        - [ ] Parsing IPv4 compatible/mapped IPv6 addresses
        - [ ] Parsing IPv6 address scopes (`scope id`)