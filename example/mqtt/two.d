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

    acc.app.spawnInfLoop({ testPrintHello(one); });
    acc.app.spawnInfLoop({ testGetTime(one); });
    acc.app.spawnInfLoop({ testMagicmath(one); });
    acc.app.spawnInfLoop({ testGetArray(one); });

    acc.app.spawnInfLoop({ testFoo(three); });
    acc.app.spawnInfLoop({ testBar(three); });

    scope (exit) { stderr.writeln("FAILS: ", failcount); }

    while (acc.app.loop()) { sleep(2.msecs); }
}