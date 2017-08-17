/// Simple binary serialization/deserialization
module drmi.sbin;

import std.bitmanip : nativeToLittleEndian, littleEndianToNative;
import std.exception : enforce, assertThrown;
import std.range;
import std.string : format;
import std.traits;

///
alias length_t = ulong;
///
alias pack = nativeToLittleEndian;
///
alias unpack = littleEndianToNative;

///
class SBinException : Exception
{
    this(string msg, string file=__FILE__, size_t line=__LINE__) @safe @nogc pure nothrow
    { super(msg, file, line); }
}

///
class SBinDeserializeException : SBinException
{
    ///
    this(string msg, string file=__FILE__, size_t line=__LINE__) @safe @nogc pure nothrow
    { super(msg, file, line); }
}

///
class SBinDeserializeFieldException : SBinDeserializeException
{
    ///
    string mainType, fieldName, fieldType;
    ///
    size_t readed, expected, fullReaded;
    ///
    this(string mainType, string fieldName, string fieldType,
         size_t readed, size_t expected, size_t fullReaded)
    {
        this.mainType = mainType;
        this.fieldName = fieldName;
        this.fieldType = fieldType;
        this.readed = readed;
        this.expected = expected;
        this.fullReaded = fullReaded;
        super(format("empty input range while "~
                "deserialize '%s' element %s:%s %d/%d (readed/expected), "~
                "readed message %d bytes", mainType, fieldName,
                fieldType, readed, expected, fullReaded));
    }
}

/++ Serialize to output ubyte range

    Params:
        val - serializible value
        r - output range
+/
void sbinSerialize(T, R)(auto ref const T val, ref R r)
    if (isOutputRange!(R, ubyte))
{
    static if (is(T : double) || is(T : long))
        r.put(val.pack[]);
    else static if (isStaticArray!T)
        foreach (v; val) sbinSerialize(v, r);
    else static if (isSomeString!T)
    {
        r.put((cast(length_t)val.length).pack[]);
        r.put(cast(ubyte[])val);
    }
    else static if (isDynamicArray!T)
    {
        r.put((cast(length_t)val.length).pack[]);
        foreach (v; val) sbinSerialize(v, r);
    }
    else static if (isAssociativeArray!T)
    {
        r.put((cast(length_t)val.length).pack[]);
        foreach (k, v; val)
        {
            sbinSerialize(k, r);
            sbinSerialize(v, r);
        }
    }
    else static if (is(T == struct) || isTypeTuple!T)
        foreach (v; val.tupleof) sbinSerialize(v, r);
    else static assert(0, "unsupported type: " ~ T.stringof);
}

/++ Serialize to ubyte[]

    using `appender!(ubyte[])` as output range

    Params:
        val = serializible value

    Returns:
        serialized data
+/
ubyte[] sbinSerialize(T)(auto ref const T val)
{
    import std.array : appender;
    auto buf = appender!(ubyte[]);
    sbinSerialize(val, buf);
    return buf.data.dup;
}

/++ Deserialize `Target` value

    Params:
        range = copy of input range with serialized data

    Returns:
        deserialized value
 +/
Target sbinDeserialize(Target, R)(R range)
{
    size_t cnt;

    ubyte pop(ref R rng, lazy string field, lazy string type,
                lazy size_t vcnt, lazy size_t vexp)
    {
        enforce (!rng.empty, new SBinDeserializeFieldException(
                    Target.stringof, field, type, vcnt, vexp, cnt));
        auto ret = rng.front;
        rng.popFront();
        cnt++;
        return ret;
    }

    auto impl(T)(ref R r, lazy string field)
    {
        string ff(lazy string n) { return field ~ "." ~ n; }
        string fi(size_t i) { return field ~ format("[%d]", i); }

        static if (is(T : double) || is(T : long))
        {
            ubyte[T.sizeof] tmp;
            foreach (i, ref v; tmp) v = pop(r, field, T.stringof, i, T.sizeof);
            return tmp.unpack!T;
        }
        else static if (isSomeString!T)
        {
            auto length = cast(size_t)impl!length_t(r, ff("length"));
            auto tmp = new ubyte[](length);
            foreach (i, ref v; tmp) v = pop(r, fi(i), T.stringof, i, length);
            return cast(T)tmp;
        }
        else static if (isStaticArray!T)
        {
            T ret;
            foreach (i, ref v; ret) v = impl!(typeof(ret[0]))(r, fi(i));
            return ret;
        }
        else static if (isDynamicArray!T)
        {
            T ret;
            ret.length = cast(size_t)impl!length_t(r, ff("length"));
            foreach (i, ref v; ret) v = impl!(typeof(ret[0]))(r, fi(i));
            return ret;
        }
        else static if (isAssociativeArray!T)
        {
            T ret;
            auto length = cast(size_t)impl!length_t(r, ff("length"));
            foreach (i; 0 .. length)
            {
                auto k = impl!(KeyType!T)(r, fi(i)~".key");
                auto v = impl!(ValueType!T)(r, fi(i)~".val");
                ret[k] = v;
            }
            return ret;
        }
        else static if (is(T == struct) || isTypeTuple!T)
        {
            T ret;
            foreach (i, ref v; ret.tupleof)
                v = impl!(Unqual!(typeof(v)))(r, ff(__traits(identifier, ret.tupleof[i])));
            return ret;
        }
        else static assert(0, "unsupported type: " ~ T.stringof);
    }

    auto ret = impl!Target(range, "");

    enforce(range.empty, new SBinDeserializeException(
        format("input range not empty after full '%s' deserialize", Target.stringof)));

    return ret;
}

version (unittest) import std.algorithm : equal;

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
    import std.array : appender;
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

unittest
{
    auto a = [1,2,3,4];
    auto as = a.sbinSerialize;
    auto as_tr = as[0..17];
    assertThrown!SBinDeserializeFieldException(as_tr.sbinDeserialize!(typeof(a)));
}

unittest
{
    auto a = [1,2,3,4];
    auto as = a.sbinSerialize;
    auto as_tr = as ~ as;
    assertThrown!SBinDeserializeException(as_tr.sbinDeserialize!(typeof(a)));
}

unittest
{
    auto a = ["hello" : 123, "ok" : 43];
    auto as = a.sbinSerialize;

    auto b = as.sbinDeserialize!(typeof(a));
    assert(b["hello"] == 123);
    assert(b["ok"] == 43);
}