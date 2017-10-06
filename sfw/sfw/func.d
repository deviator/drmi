///
module sfw.func;

import sfw.fiber;
import std.datetime : Clock, Duration;
import core.thread : Thread, Fiber;

/// set `nextTime` if fiber is `SFWFiber`
void sleep(Duration d)
{
    if (auto f = Fiber.getThis())
    {
        auto sfwf = cast(SFWFiber)f;
        auto nt = Clock.currStdTime + d.total!"hnsecs";
        if (sfwf !is null)
        {
            sfwf.nextTime = nt;
            sfwf.yield();
        }
        else while (Clock.currStdTime < nt) sfwf.yield();
    }
    else Thread.sleep(d);
}

///
void yield()
{
    if (auto f = Fiber.getThis()) f.yield();
    else Thread.yield();
}