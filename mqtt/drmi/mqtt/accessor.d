///
module drmi.mqtt.accessor;

import drmi.ps.accessor;
import drmi.mqtt.transport;

import std.algorithm;
import std.array;
import std.datetime;
import core.thread;
import std.conv;
import std.experimental.logger;

class AFiber : Fiber
{
    ulong nextTime;
    this(void delegate() dlg) { super(dlg); }
    this(void delegate() dlg, size_t sz) { super(dlg, sz); }
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
            while (sw.peek.to!Duration < d) f.yield();
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
protected:
    MqttTransport tr;
    AFiber[] fibers;
    bool work = true;
    int exit_result;

    void callTransportLoop() { tr.loop(); }

public:

    alias Settings = MosquittoClient.Settings;

    ///
    size_t stackSize = 1024 * 128;

    ///
    this(T obj, string uniq="") { this(obj, Settings.init, uniq); }

    ///
    this(T obj, Settings sets, string uniq="")
    {
        tr = new MqttTransport(sets);
        super(tr, obj, uniq, (s){ .sleep(s); });

        spawnInfLoop({ callTransportLoop(); });
    }

    void spawn(void delegate() _body)
    {
        if (stackSize > 0)
            fibers ~= new AFiber({ _body(); }, stackSize);
        else
            fibers ~= new AFiber({ _body(); });
    }

    void spawnInfLoop(void delegate() loop_body)
    {
        fibers ~= new AFiber(
        {
            while (true)
            {
                loop_body();
                yield();
            }
        }, stackSize);
    }

    void exitLoop(int res=0)
    {
        work = false;
        exit_result = res;
    }

    int exitResult() const @property { return exit_result; }

    ///
    bool loop()
    {
        if (!work) return false;
        fibers = fibers.filter!(f=>f.state != Fiber.State.TERM).array;
        foreach (f; fibers)
            if (f.nextTime < Clock.currStdTime)
                f.call();
        return true;
    }
}