///
module sfw.app;

import std.algorithm : filter;
import std.array : array;
import std.datetime;
import core.thread;

import sfw.fiber;
import sfw.func;

///
class SFWApp
{
protected:
    SFWFiber[] fibers;
    ///
    bool work = true;
    int exit_result;

    alias voidDelegate = void delegate();
    alias voidFunction = void function();
public:

    /// use for new fibers
    size_t stackSize;

    /// stackSize = 1024 * ss
    this(size_t ss=32) { stackSize = 1024 * ss; }

    /// create managed SFWFiber
    void spawn(T)(T _body)
        if(is(T == voidDelegate) || is(T == voidFunction))
    {
        if (stackSize > 0)
            fibers ~= new SFWFiber(_body, stackSize);
        else
            fibers ~= new SFWFiber(_body);
    }

    /// create managed SFWFiber with infinity loop
    void spawnInfLoop(T)(T loop_body)
        if(is(T == voidDelegate) || is(T == voidFunction))
    {
        spawn({
            while (true)
            {
                loop_body();
                yield();
            }
        });
    }

    /// set `work` to false and set exit_result
    void exitLoop(int res=0)
    {
        work = false;
        exit_result = res;
    }

    ///
    int exitResult() nothrow const @property { return exit_result; }

    /// while `work` call not terminate fibers
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