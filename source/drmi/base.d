///
module drmi.base;

import drmi.types;
import drmi.exceptions;
import drmi.helpers;

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
        import std.typecons : tuple;

        template ov(string s) { alias ov = AliasSeq!(__traits(getOverloads, T, s)); }

        switch (call.func)
        {
            foreach (n, func; staticMap!(ov, __traits(derivedMembers, T)))
            {
                case rmiFunctionName!func:
                    try
                    {
                        auto params = Parameters!func.init;

                        static if (params.length)
                            params = call.data.sbinDeserialize!(typeof(tuple(params)));
                        
                        ubyte[] resData;
                        enum callstr = "server."~__traits(identifier, func)~"(params)";
                        static if(is(ReturnType!func == void)) mixin(callstr~";");
                        else resData = mixin(callstr).sbinSerialize;

                        return RMIResponse(0, call, resData);
                    }
                    catch (Throwable e)
                        return RMIResponse(2, call, e.msg.sbinSerialize);
            }
            default:
                return RMIResponse(1, call, "unknown func".sbinSerialize);
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

                auto tmp = tuple(Parameters!self.init);
                foreach (i, p; ParameterIdentifierTuple!self)
                    tmp[i] = mixin(p);

                call.data = tmp.sbinSerialize;

                auto result = com.process(call);

                enforce(result.status == 0, new RMIProcessException(result));

                static if (!is(typeof(return) == void))
                    return result.data.sbinDeserialize!(typeof(return));
            };

        import std.datetime : Clock;
        import std.exception : enforce;
        import std.typecons : tuple;
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