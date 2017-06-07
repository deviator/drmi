### D Remote Method Invocation

This package not provide low level transport for messages (`RMICall`, `RMIResponse`), but provide high level wraps around your interfaces for packing arguments.

`RMICom` base interface with one method `RMIResponse process(RMICall)`.

`class RMISkeleton(T) : RMICom` is server-side wrap, method `process` must be used in your event loop for dispatch process to real object.

`class RMIStub(T) : T` is client-side wrap, it's use `RMICom` for sending messages and get's responses.

Your interface methods must have serializable to `vibe.data.json.Json` paramters and return value.

Example:
```d
import drmi;

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

void main()
{
    auto rea = new Realization;
    auto ske = new RMISkeleton!Test(rea);
    // use `ske` in low level transaction mechanism
    // for `cli` write RMICom low lovel transaction mechanism realization
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
```