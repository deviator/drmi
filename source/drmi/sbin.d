module drmi.sbin;

import std.algorithm;
import std.array;
import std.bitmanip;
import std.traits;
import std.range;

alias pack = nativeToLittleEndian;
alias unpack = littleEndianToNative;

void sbinSerialize(T, R)(auto ref const T val, ref R r)
    if (isOutputRange!(R, ubyte))
{
    static if (is(T : double) || is(T : long))
        r.put(val.pack[]);
    else static if (isStaticArray!T)
        foreach (v; val) sbinSerialize(v, r);
    else static if (isSomeString!T)
    {
        r.put((cast(ulong)val.length).pack[]);
        r.put(cast(ubyte[])val);
    }
    else static if (isDynamicArray!T)
    {
        r.put((cast(ulong)val.length).pack[]);
        foreach (v; val) sbinSerialize(v, r);
    }
    else static if (is(T == struct) || isTypeTuple!T)
        foreach (v; val.tupleof) sbinSerialize(v, r);
    else
        static assert(0, "unsupported type: " ~ T.stringof);
}

ubyte[] sbinSerialize(T)(auto ref const T val)
{
    auto buf = appender!(ubyte[]);
    sbinSerialize(val, buf);
    return buf.data.dup;
}

Tb sbinDeserialize(Tb, Rb)(Rb r)
{
    auto impl(T,R)(ref R r)
    {
        static if (is(T : double) || is(T : long))
        {
            ubyte[T.sizeof] tmp;
            foreach (ref v; tmp)
            {
                v = r.front;
                r.popFront();
            }
            return tmp.unpack!T;
        }
        else static if (isSomeString!T)
        {
            auto length = cast(size_t)impl!ulong(r);
            auto tmp = new ubyte[](length);
            foreach (ref v; tmp)
            {
                v = r.front;
                r.popFront();
            }
            return cast(T)tmp;
        }
        else static if (isStaticArray!T)
        {
            T ret;
            foreach (ref v; ret) v = impl!(typeof(ret[0]))(r);
            return ret;
        }
        else static if (isDynamicArray!T)
        {
            T ret;
            ret.length = cast(size_t)impl!ulong(r);
            foreach (ref v; ret) v = impl!(typeof(ret[0]))(r);
            return ret;
        }
        else static if (is(T == struct) || isTypeTuple!T)
        {
            T ret;
            foreach (i, ref v; ret.tupleof)
                v = impl!(Unqual!(typeof(v)))(r);
            return ret;
        }
        else
            static assert(0, "unsupported type: " ~ T.stringof);
    }
    return impl!Tb(r);
}

unittest
{
    auto a = 123;
    assert(a.sbinSerialize.sbinDeserialize!int == a);
}

unittest
{
    auto s = "hello world";
    assert(equal(s.sbinSerialize.sbinDeserialize!string, s));
}

unittest
{
    immutable(int[]) a = [1,2,3,2,3,2,1];
    assert(a.sbinSerialize.sbinDeserialize!(int[]) == a);
}

unittest
{
    import std.array;
    auto ap = appender!(ubyte[]);

    struct Cell
    {
        ulong id;
        float volt, temp;
        ushort soc, soh;
        string strData;
        bool tr;
    }

    struct Line
    {
        ulong id;
        float volt, curr;
        Cell[] cells;
    }

    auto lines = [
        Line(123,
            3.14, 2.17,
            [
                Cell(1, 1.1, 2.2, 5, 8, "one", true),
                Cell(2, 1.3, 2.5, 7, 9, "two"),
                Cell(3, 1.5, 2.8, 3, 7, "three"),
            ]
        ),
        Line(23,
            31.4, 21.7,
            [
                Cell(10, .11, .22, 50, 80, "1one1"),
                Cell(20, .13, .25, 70, 90, "2two2", true),
                Cell(30, .15, .28, 30, 70, "3three3"),
            ]
        ),
    ];

    auto sdata = lines.sbinSerialize;
    assert( equal(sdata.sbinDeserialize!(Line[]), lines));
    lines[0].cells[1].soh = 123;
    assert(!equal(sdata.sbinDeserialize!(Line[]), lines));
}

unittest
{
    static void foo(int a=123, string b="hello")
    {

    }
    auto a = ParameterDefaults!foo;

    import std.typecons;
    auto sa = tuple(a).sbinSerialize;

    Parameters!foo b;
    b = sa.sbinDeserialize!(typeof(tuple(b)));
    assert(a == b);
}