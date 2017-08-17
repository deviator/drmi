import drmi.core;

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

void main()
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
