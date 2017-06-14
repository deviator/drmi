module three;

import iface;

class ThreeImpl : Three
{
    override string foo(double v) { return format("%.3e", v); }
    override int bar() { static int i; return i++; }
}

int main()
{
    auto acc = new Accessor!Three(new MqttTransport, new ThreeImpl);

    auto one = acc.getClient!One;
    auto two = acc.getClient!Two;

    acc.connect();
    sleep(2.seconds);

    runTask({ while (true) testPrintHello(one); });
    runTask({ while (true) testGetTime(one); });
    runTask({ while (true) testMagicmath(one); });
    runTask({ while (true) testGetArray(one); });

    runTask({ while (true) testSum(two); });

    scope (exit) { stderr.writeln("FAILS: ", failcount); }
    return runEventLoop();
}