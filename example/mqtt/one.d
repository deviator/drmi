module one;

import iface;

class OneImpl : One
{
    override string getTime() { return format("%s", Clock.currTime); }
    override void printHello() { writeln("HELLO"); }
    override double magicmath(double a, double b) { return (a/b)*b; }
    override int[] getArray(int c) { return ((new int[](c))[] = c); }
}

void main()
{
    auto acc = new MqttAccessor!One(new OneImpl);

    auto two = acc.getClient!Two;
    auto three = acc.getClient!Three;

    acc.connect();
    sleep(2.seconds);

    acc.spawnInfLoop({ testSum(two); });

    acc.spawnInfLoop({ testFoo(three); });
    acc.spawnInfLoop({ testBar(three); });

    scope (exit) { stderr.writeln("FAILS: ", failcount); }

    while (true) acc.loop();
}