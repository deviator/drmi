///
module drmi;

import vibe.data.json;

///
alias RMIData = Json;
///
RMIData serialize(T)(auto ref const T val) { return val.serializeToJson; }
///
T deserialize(T)(auto ref const RMIData d) { return d.deserializeJson!T; }
///
auto as(T)(auto ref const RMIData d) @property { return d.deserialize!T; }

///
RMIData rmiEmptyArrayData() { return Json.emptyArray; }

///
struct RMICall
{
    ///
    string caller;
    ///
    string func;
    ///
    long ts;
    ///
    RMIData data;
}

///
struct RMIResponse
{
    ///
    uint status;
    ///
    RMICall call;
    ///
    RMIData data;
}

///
class RMIException : Exception
{
    ///
    RMIData data;
    ///
    this(RMIData data)
    {
        this.data = data;
        super(data.toString);
    }
}

///
class RMITimeoutException : Exception
{
    import std.conv : text;
    ///
    RMICall call;
    ///
    this(RMICall c) { call = c; super(text(c)); }
}

///
interface RMICom
{
    ///
    RMIResponse process(RMICall call);
}

///
class RMISkeleton(T) : RMICom
    if (is(T == interface))
{
protected:
    T server;

public:

    ///
    this(T server)
    {
        import std.exception : enforce;
        this.server = enforce(server, "server is null");
    }

    override RMIResponse process(RMICall call)
    {
        import std.meta;
        import std.traits;

        template ov(string s) { alias ov = AliasSeq!(__traits(getOverloads, T, s)); }

        switch (call.func)
        {
            foreach (n, func; staticMap!(ov, __traits(derivedMembers, T)))
            {
                case rmiFunctionName!func:
                    try
                    {
                        auto params = Parameters!func.init;
                        foreach (i, type; Parameters!func)
                            params[i] = call.data[i].as!type;
                        
                        RMIData resData = null;
                        enum callstr = "server."~__traits(identifier, func)~"(params)";
                        static if(is(ReturnType!func == void)) mixin(callstr~";");
                        else resData = mixin(callstr).serialize;

                        return RMIResponse(0, call, resData);
                    }
                    catch (Throwable e)
                        return RMIResponse(2, call, e.msg.serialize);
            }
            default:
                return RMIResponse(1, call, "unknown func".serialize);
        }
    }
}

///
interface RMIStubCom : RMICom
{
    ///
    string caller() const @property;
}

///
class RMIStub(T) : T
{
protected:
    RMIStubCom com;
public:
    ///
    this(RMIStubCom com) { this.com = com; }

    private mixin template overrideIface()
    {
        private enum string packCode =
            q{
                enum dummy;
                alias self = AliasSeq!(__traits(parent, dummy))[0];

                static fname = rmiFunctionName!self;

                RMICall call;
                call.caller = com.caller;
                call.func = fname;
                call.ts = Clock.currStdTime;
                call.data = rmiEmptyArrayData;

                foreach (p; ParameterIdentifierTuple!self)
                    call.data ~= mixin(p).serialize;

                auto result = com.process(call);

                enforce(result.status == 0, new RMIException(result.data));

                static if (!is(typeof(return) == void))
                    return result.data.as!(typeof(return));
            };

        import std.datetime : Clock;
        import std.exception : enforce;
        import std.meta : staticMap;
        import std.traits : ReturnType, AliasSeq, Parameters, ParameterIdentifierTuple,
                            functionAttributes, FunctionAttribute;

        private mixin template impl(F...)
        {
            private static string trueParameters(alias FNC)()
            {
                import std.conv : text;
                import std.string : join;
                string[] ret;
                foreach (i, param; Parameters!FNC)
                    ret ~= `Parameters!(F[0])[`~text(i)~`] __param_` ~ text(i);
                return ret.join(", ");
            }

            private static string getAttributesString(alias FNC)()
            {
                import std.string : join;
                string[] ret;
                // TODO
                ret ~= functionAttributes!FNC & FunctionAttribute.property ? "@property" : "";
                return ret.join(" ");
            }

            static if (F.length == 1)
            {
                mixin("override ReturnType!(F[0]) " ~ __traits(identifier, F[0]) ~
                      `(` ~ trueParameters!(F[0]) ~ `) ` ~ getAttributesString!(F[0]) ~
                      ` { ` ~ packCode ~ `}`);
            }
            else
            {
                mixin impl!(F[0..$/2]);
                mixin impl!(F[$/2..$]);
            }
        }

        private template getOverloads(string s)
        { alias getOverloads = AliasSeq!(__traits(getOverloads, T, s)); }

        mixin impl!(staticMap!(getOverloads, __traits(derivedMembers, T)));
    }

    mixin overrideIface;
}

private version (unittest)
{
    struct Point { double x, y, z; }

    interface Test
    {
        int foo(string abc, int xyz);
        string foo(string str);
        string bar(double val);
        double len(Point pnt);
        string state() @property;
        void state(string s) @property;
    }

    class Impl : Test
    {
        string _state;
    override:
        string foo(string str) { return "<" ~ str ~ ">"; }
        int foo(string abc, int xyz) { return cast(int)(abc.length * xyz); }
        string bar(double val) { return val > 3.14 ? "big" : "small"; }
        double len(Point pnt)
        {
            import std.math;
            return sqrt(pnt.x^^2 + pnt.y^^2 + pnt.z^^2);
        }
        string state() @property { return _state; }
        void state(string s) @property { _state = s; }
    }
}

unittest
{
    auto rea = new Impl;
    auto ske = new RMISkeleton!Test(rea);
    auto cli = new RMIStub!Test(new class RMIStubCom
    {
        string caller() const @property { return "fake caller"; }
        RMIResponse process(RMICall call) { return ske.process(call); }
    });

    assert(rea.foo("hello", 123) == cli.foo("hello", 123));
    assert(rea.bar(2.71) == cli.bar(2.71));
    assert(rea.bar(3.1415) == cli.bar(3.1415));
    assert(rea.foo("okda") == cli.foo("okda"));
    assert(rea.len(Point(1,2,3)) == cli.len(Point(1,2,3)));

    static str = "foo";
    cli.state = str;
    assert(rea.state == str);
    assert(cli.state == str);
}

private string rmiFunctionName(alias func)()
{
    import std.meta : staticMap;
    import std.traits : Parameters;
    import std.string : join;
    import std.algorithm : canFind;

    checkFunction!func;

    template s4t(X) { enum s4t = X.stringof; }

    static if (Parameters!func.length)
        return __traits(identifier, func) ~ "(" ~ [staticMap!(s4t, Parameters!func)].join(",") ~ ")";
    else
        return __traits(identifier, func) ~ "()";
}

private void checkFunction(alias func)()
{
    import std.algorithm : find;
    import std.traits : hasFunctionAttributes;
    enum funcstr = __traits(identifier, __traits(parent, __traits(parent, func))) ~ ":" ~ 
                    __traits(identifier, __traits(parent, func))
                    ~ "." ~ __traits(identifier, func);
    static assert(!hasFunctionAttributes!(func, "@safe"), "@safe not allowed: " ~ funcstr);
    static assert(!hasFunctionAttributes!(func,  "pure"), "pure not allowed: " ~ funcstr);
    static assert(!hasFunctionAttributes!(func, "@nogc"), "@nogc not allowed: " ~ funcstr);
}


unittest
{
    static auto i = [0];
    void foo(int a, double b, string c) @system { i ~= 1; }
    static assert(rmiFunctionName!foo == "foo(int,double,string)");
    void bar() @system { i ~= 2; }
    static assert(rmiFunctionName!bar == "bar()");
}