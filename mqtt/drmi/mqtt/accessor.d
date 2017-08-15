///
module drmi.mqtt.accessor;

import drmi.ps.accessor;
import drmi.mqtt.transport;

import std.algorithm;
import std.array;
import std.datetime;
import core.thread;
import std.conv;

class AFiber : Fiber
{
    ulong nextTime;
    this(void delegate() dlg) { super(dlg); }
}

void sleep(Duration d)
{
    if (auto f = Fiber.getThis())
    {
        auto af = cast(AFiber)f;
        if (af !is null)
        {
            af.nextTime = Clock.currStdTime + d.total!"hnsecs";
            af.yield();
        }
        else
        {
            auto sw = StopWatch(AutoStart.yes);
            while (sw.peek.to!Duration < d)
                f.yield();
        }
    }
    else Thread.sleep(d);
}

void yield()
{
    if (auto f = Fiber.getThis()) f.yield();
    else Thread.yield();
}

///
class MqttAccessor(T) : Accessor!T
{

    private MqttTransport tr;
    private AFiber[] fibers;

    ///
    this(T obj, string uniq="")
    {
        tr = new MqttTransport;
        super(tr, obj, uniq, &sleep);
    }

    void spawn(void delegate() _body)
    { fibers ~= new AFiber({ _body(); }); }

    void spawnInfLoop(void delegate() loop_body)
    {
        fibers ~= new AFiber(
        {
            while (true)
            {
                loop_body();
                yield();
            }
        });
    }

    ///
    void loop()
    {
        fibers = fibers.filter!(f=>f.state != Fiber.State.TERM).array;
        foreach (f; fibers)
            if (f.nextTime < Clock.currStdTime)
                f.call();
        tr.loop();
        Thread.sleep(1.usecs);
    }
}