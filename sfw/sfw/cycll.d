/// cycle call
module sfw.cycll;

import std.datetime;
import std.exception : enforce;

/++ For cases when can't use async methods and whey must
    calls every N hnsecs, but strictly sync
 +/
struct CyCll
{
    /// returns step for next call
    Duration delegate() func;
    /// next std time for call
    long next = 0;

    ///
    this(Duration delegate() func)
    { this.func = enforce(func, "bodyfunc is null"); }

    /// if time is up call func, set next and return true
    bool opCall()
    {
        if (now < next) return false;
        next = now + func().total!"hnsecs";
        return true;
    }

    ///
    static auto now() @property { return Clock.currStdTime; }
}