#!/usr/bin/env rdmd
/**
 * Planned features:
 * ugo -> a
 * chmod setuid and sticky bits
 * full map of node types
 */

import std.format : format;
import std.traits : EnumMembers;

immutable usage = "Usage:
    %%s [--ls] [--nodetype=(%(%s%||%))] <octal modes...>".format([EnumMembers!NodeType]);

bool readable(ubyte permissions) {
    return !!(permissions & 4);
}

bool writable(ubyte permissions) {
    return !!(permissions & 2);
}

bool executable(ubyte permissions) {
    return !!(permissions & 1);
}

ubyte user(ushort mode) {
    return (mode >> 6) & 7;
}

ubyte group(ushort mode) {
    return (mode >> 3) & 7;
}

ubyte others(ushort mode) {
    return mode & 7;
}

bool sticky(ushort mode) {
    return (mode >> 9) & 1;
}

auto symbolic(ubyte permissions) {
    import std.range : only;
    return only(
        permissions.readable   ? 'r' : '-',
        permissions.writable   ? 'w' : '-',
        permissions.executable ? 'x' : '-');
}

enum NodeType : char {
    directory   = 'd',
    blockdevice = 'b',
    pipe        = 'p',
    socket      = 's',
    other       = '-',
}

auto toLsSyntax(ushort mode, NodeType type) {
    import std.range : chain, only;

    return chain(only(char(type)),
        mode.user.symbolic,
        mode.group.symbolic,
        mode.others.symbolic[0 .. 2],
        only(mode.sticky ? (mode.others.executable ? 't' : 'T') : mode.others.symbolic[2]));
}

auto toChmodSyntax(ushort mode) {
    import std.algorithm.iteration : chunkBy, filter, joiner, map;
    import std.range : chain, choose, only, zip;
    import std.typecons : tuple;

    return "ugo".zip(only(mode.user, mode.group, mode.others))
        .chunkBy!((a, b) => a[1] == b[1])
        .map!(
            bundle => chain(
                bundle.map!(permTuple => permTuple[0]),
                "=",
                bundle.front[1].symbolic.filter!(c => c != '-')))
        .joiner(",")
        .map!(i => cast(dchar)i); // Oh, dmd...
}

int main(string[] args) {
    import std.algorithm.iteration : map;
    import std.conv : to;
    import std.getopt : getopt;
    import std.stdio : stderr, stdout;

    bool lsMode = false;
    auto nodeType = NodeType.other;
    getopt(args,
        "ls", &lsMode,
        "nodetype", &nodeType);

    if (args.length < 2) {
        stderr.writefln(usage, args[0]);
        return 1;
    }

    auto modes = args[1 .. $].map!(arg => to!ushort(arg, 8));
    if (lsMode) {
        foreach(immutable mode; modes)
            stdout.writeln(toLsSyntax(mode, nodeType));
    } else {
        foreach(immutable mode; modes)
            stdout.writeln(toChmodSyntax(mode));
    }
    return 0;
}
