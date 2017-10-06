module three;

import iface;

class ThreeImpl : Three
{
    override string foo(double v) { return format("%.3e", v); }
    override int bar() { static int i; return i++; }
}

void main()
{
    auto acc = new MqttAccessor!Three(new ThreeImpl);

    auto one = acc.getClient!One;
    auto two = acc.getClient!Two;

    acc.connect();
    sleep(2.seconds);

    acc.app.spawnInfLoop({ testPrintHello(one); });
    acc.app.spawnInfLoop({ testGetTime(one); });
    acc.app.spawnInfLoop({ testMagicmath(one); });
    acc.app.spawnInfLoop({ testGetArray(one); });

    acc.app.spawnInfLoop({ testSum(two); });

    scope (exit) { stderr.writeln("FAILS: ", failcount); }

    while (acc.app.loop()) { sleep(2.msecs); }
}