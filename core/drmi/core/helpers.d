///
module drmi.core.helpers;

package string rmiFunctionName(alias func)()
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

package void checkFunction(alias func)()
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