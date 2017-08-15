module two;

import iface;

class TwoImpl : Two
{
    override int sum(int a, int b) { return a + b; }
}

void main()
{
    auto acc = new MqttAccessor!Two(new TwoImpl);

    auto one = acc.getClient!One;
    auto three = acc.getClient!Three;

    acc.connect();
    sleep(2.seconds);

    acc.spawnInfLoop({ testPrintHello(one); });
    acc.spawnInfLoop({ testGetTime(one); });
    acc.spawnInfLoop({ testMagicmath(one); });
    acc.spawnInfLoop({ testGetArray(one); });

    acc.spawnInfLoop({ testFoo(three); });
    acc.spawnInfLoop({ testBar(three); });

    scope (exit) { stderr.writeln("FAILS: ", failcount); }

    while (acc.loop()) {}
}