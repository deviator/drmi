module iface;

public import std.experimental.logger;
public import std.stdio;
public import std.datetime;
public import std.format;
public import std.random;
public import core.thread;
public import drmi;

interface One
{
    string getTime();
    void printHello();
    double magicmath(double, double);
    int[] getArray(int);
}

interface Two
{
    int sum(int, int);
}

interface Three
{
    string foo(double);
    int bar();
}

void rndSleep()
{
    sleep(uniform(10, 300).msecs);
}

static size_t failcount;

void timeoutFail(string msg)
{
    stderr.writeln(msg);
    failcount++;
    //exitEventLoop();
}

void print(Args...)(Args args)
{
    stderr.writefln(args);
}

void testGetTime(One one)
{
    rndSleep();
    try print(one.getTime());
    catch (RMITimeoutException e) timeoutFail(e.msg);
}

void testPrintHello(One one)
{
    rndSleep();
    try one.printHello();
    catch (RMITimeoutException e) timeoutFail(e.msg);
}

void testMagicmath(One one)
{
    rndSleep();
    auto r1 = uniform(5.0, 10.000001), r2 = uniform(1.0, 10.000001);
    try print("(%s / %s) * %s = %s", r1, r2, r2, one.magicmath(r1, r2));
    catch (RMITimeoutException e) timeoutFail(e.msg);
}

void testGetArray(One one)
{
    rndSleep();
    auto cnt = uniform(1, 6);
    try print("%(%s, %)", one.getArray(cnt));
    catch (RMITimeoutException e) timeoutFail(e.msg);
}

void testSum(Two two)
{
    rndSleep();
    auto r1 = uniform(-10, 11), r2 = uniform(-10, 11);
    try print("%s + %s = %s", r1, r2, two.sum(r1, r2));
    catch (RMITimeoutException e) timeoutFail(e.msg);
}

void testFoo(Three three)
{
    rndSleep();
    auto r1 = uniform!"[]"(-1.0, 1.0);
    try print("three.foo(%s) -> %s", r1, three.foo(r1));
    catch (RMITimeoutException e) timeoutFail(e.msg);
}

void testBar(Three three)
{
    rndSleep();
    try print("three.bar() -> %s", three.bar());
    catch (RMITimeoutException e) timeoutFail(e.msg);
}