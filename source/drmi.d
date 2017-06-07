module drmi;

import vibe.data.json;

alias RMIData = Json;
RMIData serialize(T)(auto ref const T val) { return val.serializeToJson; }
T deserialize(T)(auto ref const RMIData d) { return d.deserializeJson!T; }
auto as(T)(auto ref const RMIData d) @property { return d.deserialize!T; }

struct RMICall
{
    string func;
    RMIData data;
}

struct RMIResponse
{
    uint status;
    RMICall call;
    RMIData data;
}

class RMIException : Exception
{
    RMIData data;
    this(RMIData data)
    {
        this.data = data;
        super(data.toString);
    }
}

interface RMICom
{
    RMIResponse process(RMICall call);
}

class RMISkeleton(T) : RMICom
    if (is(T == interface))
{
protected:
    T server;

public:

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
                        
                        RMIData resData;
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

class RMIStub(T) : T
{
    RMICom com;
    this(RMICom com) { this.com = com; }

    private mixin template overrideIface()
    {
        private enum string packCode =
            q{
                import std.exception : enforce;
                enum dummy;
                alias self = AliasSeq!(__traits(parent, dummy))[0];

                static fname = rmiFunctionName!self;

                RMICall call;
                call.func = fname;
                call.data = Json.emptyArray;

                foreach (p; ParameterIdentifierTuple!self)
                    call.data ~= mixin(p).serialize;

                auto result = } ~ "com.process" ~ q{(call);

                enforce(result.status == 0, new RMIException(result.data));

                static if (!is(typeof(return) == void))
                    return result.data.as!(typeof(return));
            };

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

    class Realization : Test
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
    auto rea = new Realization;
    auto ske = new RMISkeleton!Test(rea);
    // use `ske` in low level transaction mechanism
    // for `cli` write RMICom low lovel transaction mechaism realization
    auto cli = new RMIStub!Test(ske);


    assert(rea.foo("hello", 123) == cli.foo("hello", 123));
    assert(rea.bar(2.71) == cli.bar(2.71));
    assert(rea.bar(3.1415) == cli.bar(3.1415));
    assert(rea.foo("okda") == cli.foo("okda"));
    assert(rea.len(Point(1,2,3)) == cli.len(Point(1,2,3)));

    static str = "ololo";
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
    //static assert(!canFind([__traits(getFunctionAttributes, func)], "@property"),
    //              "property not allowed: " ~ __traits(identifier, func));
    template s4t(X) { enum s4t = X.stringof; }

    static if (Parameters!func.length)
        return __traits(identifier, func) ~ "(" ~ [staticMap!(s4t, Parameters!func)].join(",") ~ ")";
    else
        return __traits(identifier, func) ~ "()";
}

unittest
{
    void foo(int a, double b, string c) {}
    static assert(rmiFunctionName!foo == "foo(int,double,string)");
    void bar() {}
    static assert(rmiFunctionName!bar == "bar()");
}