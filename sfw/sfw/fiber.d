///
module sfw.fiber;

import core.thread;

///
class SFWFiber : Fiber
{
    ///
    ulong nextTime;
    ///
    this(void delegate() f) { super(f); }
    ///
    this(void function() f) { super(f); }
    ///
    this(void delegate() f, size_t sz) { super(f, sz); }
    ///
    this(void function() f, size_t sz) { super(f, sz); }
}