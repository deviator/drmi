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
         size_t readed, size_t expected, size_t fullReaded) @safe pure
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
void sbinSerialize(R, T...)(ref R r, auto ref const T vals)
    if (isOutputRange!(R, ubyte) && T.length)
{
    static if (T.length == 1)
    {
        alias val = vals[0];
        static if (is(Unqual!T : double) || is(Unqual!T : long))
            r.put(val.pack[]);
        else static if (isStaticArray!T)
            foreach (ref v; val) r.sbinSerialize(v);
        else static if (isSomeString!T)
        {
            r.put((cast(length_t)val.length).pack[]);
            r.put(cast(ubyte[])val);
        }
        else static if (isDynamicArray!T)
        {
            r.put((cast(length_t)val.length).pack[]);
            foreach (ref v; val) r.sbinSerialize(v);
        }
        else static if (isAssociativeArray!T)
        {
            r.put((cast(length_t)val.length).pack[]);
            foreach (k, ref v; val)
            {
                r.sbinSerialize(k);
                r.sbinSerialize(v);
            }
        }
        else static if (is(T == struct) || isTypeTuple!T)
            foreach (ref v; val.tupleof) r.sbinSerialize(v);
        else static assert(0, "unsupported type: " ~ T.stringof);
    }
    else foreach (ref v; vals) r.sbinSerialize(v);
}

/// ditto
deprecated("use sbinSerialize(ref R r, auto ref const T val) version")
void sbinSerialize(R, T)(auto ref const T val, ref R r)
    if (isOutputRange!(R, ubyte))
{ sbinSerialize(r, val); }

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
    buf.sbinSerialize(val);
    return buf.data.dup;
}

/++ Deserialize `Target` value

    Params:
        range = input range with serialized data (not saved before work)

    Returns:
        deserialized value
 +/
Target sbinDeserialize(Target, R)(R range)
{
    auto ret = Target.init;
    range.sbinDeserialize(ret);
    return ret;
}

/++ Deserialize `Target` value

    Params:
        range = input range with serialized data (not saved before work)
        target = reference to result object

    Returns:
        deserialized value
 +/
void sbinDeserialize(R, Target...)(R range, ref Target target)
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

    auto impl(T)(ref R r, ref T trg, lazy string field)
    {
        string ff(lazy string n) { return field ~ "." ~ n; }
        string fi(size_t i) { return field ~ format("[%d]", i); }

        static if (is(T : double) || is(T : long))
        {
            ubyte[T.sizeof] tmp;
            version (LDC) auto _field = "<LDC-1.4.0 workaround>";
            else alias _field = field;
            foreach (i, ref v; tmp) v = pop(r, _field, T.stringof, i, T.sizeof);
            trg = tmp.unpack!T;
        }
        else static if (isSomeString!T)
        {
            length_t l;
            impl(r, l, ff("length"));
            auto length = cast(size_t)l;
            auto tmp = new ubyte[](length);
            foreach (i, ref v; tmp) v = pop(r, fi(i), T.stringof, i, length);
            trg = cast(T)tmp;
        }
        else static if (isStaticArray!T)
            foreach (i, ref v; trg) impl!(typeof(ret[0]))(r, v, fi(i));
        else static if (isDynamicArray!T)
        {
            length_t l;
            impl(r, l, ff("length"));
            auto length = cast(size_t)l;
            if (trg.length != length) trg.length = length;
            foreach (i, ref v; trg) impl(r, v, fi(i));
        }
        else static if (isAssociativeArray!T)
        {
            length_t l;
            impl(r, l, ff("length"));
            auto length = cast(size_t)l;

            trg.clear();

            foreach (i; 0 .. length)
            {
                KeyType!T k;
                ValueType!T v;
                impl(r, k, fi(i)~".key");
                impl(r, v, fi(i)~".val");
                trg[k] = v;
            }

            trg.rehash();
        }
        else static if (is(T == struct) || isTypeTuple!T)
        {
            foreach (i, ref v; trg.tupleof)
                impl(r, v, ff(__traits(identifier, trg.tupleof[i])));
        }
        else static assert(0, "unsupported type: " ~ T.stringof);
    }

    foreach (ref v; target)
        impl(range, v, typeof(v).stringof);

    enforce(range.empty, new SBinDeserializeException(
        format("input range not empty after full '%s' deserialize", Target.stringof)));
}

version (unittest) import std.algorithm : equal;

unittest
{
    auto a = 123;
    assert(a.sbinSerialize.sbinDeserialize!int == a);
}

unittest
{
    auto a = 123;
    auto as = a.sbinSerialize;
    int x;
    sbinDeserialize(as, x);
    assert(a == x);
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
    { assert(a==123); assert(b=="hello"); }

    auto a = ParameterDefaults!foo;

    import std.typecons;
    auto sa = tuple(a).sbinSerialize;

    Parameters!foo b;
    b = sa.sbinDeserialize!(typeof(tuple(b)));
    assert(a == b);
    foo(b);

    a[0] = 234;
    a[1] = "okda";
    auto sn = tuple(a).sbinSerialize;

    sn.sbinDeserialize(b);

    assert(b[0] == 234);
    assert(b[1] == "okda");
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

unittest
{
    static struct X
    {
        string[int] one;
        int[string] two;
    }

    auto a = X([3: "hello", 8: "abc"], ["ok": 1, "no": 2]);
    auto b = X([8: "abc", 15: "ololo"], ["zb": 10]);

    auto as = a.sbinSerialize;
    auto bs = b.sbinSerialize;

    auto c = as.sbinDeserialize!X;

    import std.algorithm;
    assert(equal(sort(a.one.keys.dup), sort(c.one.keys.dup)));
    assert(equal(sort(a.one.values.dup), sort(c.one.values.dup)));

    bs.sbinDeserialize(c);

    assert(equal(sort(b.one.keys.dup), sort(c.one.keys.dup)));
    assert(equal(sort(b.one.values.dup), sort(c.one.values.dup)));
}

unittest
{
    enum T { one, two, three }
    T[] a;
    with(T) a = [one, two, three, two, three, two, one];
    auto as = a.sbinSerialize;

    auto b = as.sbinDeserialize!(typeof(a));
    assert(equal(a, b));
}

unittest
{
    enum T { one="one", two="2", three="III" }
    T[] a;
    with(T) a = [one, two, three, two, three, two, one];
    auto as = a.sbinSerialize;

    auto b = as.sbinDeserialize!(typeof(a));
    assert(equal(a, b));
}

unittest
{
    int ai = 543;
    auto as = "hello";

    import std.typecons;
    auto buf = sbinSerialize(tuple(ai, as));

    int bi;
    string bs;
    sbinDeserialize(buf, bi, bs);

    assert(ai == bi);
    assert(bs == as);
}

unittest
{
    int ai = 543;
    auto as = "hello";

    import std.array : appender;
    auto buf = appender!(ubyte[]);
    sbinSerialize(buf, ai, as);

    int bi;
    string bs;
    sbinDeserialize(buf.data, bi, bs);

    assert(ai == bi);
    assert(bs == as);
}