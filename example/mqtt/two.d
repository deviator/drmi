module two;

import iface;

class TwoImpl : Two
{
    override int sum(int a, int b) { return a + b; }
}

int main()
{
    auto acc = new Accessor!Two(new TwoImpl);

    auto one = acc.getClient!One;
    auto three = acc.getClient!Three;

    acc.connect();
    sleep(2.seconds);

    runTask({ while (true) testPrintHello(one); });
    runTask({ while (true) testGetTime(one); });
    runTask({ while (true) testMagicmath(one); });
    runTask({ while (true) testGetArray(one); });

    //runTask({ while (true) testFoo(three); });
    //runTask({ while (true) testBar(three); });

    scope (exit) { stderr.writeln("FAILS: ", failcount); }
    return runEventLoop();
}