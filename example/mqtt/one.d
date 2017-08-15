module one;

import iface;

class OneImpl : One
{
    override string getTime() { return format("%s", Clock.currTime); }
    override void printHello() { writeln("HELLO"); }
    override double magicmath(double a, double b) { return (a/b)*b; }
    override int[] getArray(int c) { return ((new int[](c))[] = c); }
}

int main()
{
    auto acc = new MqttAccessor!One(new OneImpl, (d){ sleep(d); });

    auto two = acc.getClient!Two;
    auto three = acc.getClient!Three;

    acc.connect();
    sleep(2.seconds);

    runTask({ while (true) testSum(two); });

    runTask({ while (true) testFoo(three); });
    runTask({ while (true) testBar(three); });

    scope (exit) { stderr.writeln("FAILS: ", failcount); }
    return runEventLoop();
}
