module drmi.mqtt.subscriber;

import mqttd;

import std.algorithm : map;
import std.array : array;

class Subscriber : MqttClient
{
protected:
    static struct CB
    {
        string pattern;
        void delegate(string, const(ubyte)[]) func;
        QoSLevel qos;
    }

    CB[] slist;

public:
    this(Settings s) { super(s); }

    override void onPublish(Publish msg)
    {
        super.onPublish(msg);
        () @trusted
        {
            foreach (cb; slist)
                if (match(msg.topic, cb.pattern))
                    cb.func(msg.topic, msg.payload);
        }();
    }

    void subscribe(string pattern, void delegate(string, const(ubyte)[]) cb, QoSLevel qos)
    {
        slist ~= CB(pattern, cb, qos);
    }

    override void onConnAck(ConnAck ca)
    {
        import std.algorithm : filter, map;
        super.onConnAck(ca);
        () @trusted
        {
            void fltr(QoSLevel lvl)
            {
                auto lst = slist.filter!(a=>a.qos==lvl).map!(a=>a.pattern).array;
                if (lst.length) super.subscribe(lst, lvl);
            }

            fltr(QoSLevel.QoS0);
            fltr(QoSLevel.QoS1);
            fltr(QoSLevel.QoS2);
        } ();
    }
}

private bool match(string topic, string pattern)
{
    enum ANY = "+";
    enum ANYLVL = "#";

    import std.algorithm : find;
    import std.exception : enforce;
    import std.string : split;

    debug (TopicMatchDebug) import std.stdio;

    auto pat = pattern.split("/");

    auto fanylvl = pat.find(ANYLVL);
    enforce(fanylvl.length <= 1, "# must be final char");

    auto top = topic.split("/");

    if (fanylvl.length == 0 && pat.length != top.length)
    {
        debug (TopicMatchDebug) stderr.writeln("no ANYLVL and mismatch levels: ", pat, " ", top, " returns false");
        return false;
    }

    foreach (i, e; pat)
    {
        if (i >= top.length)
        {
            debug (TopicMatchDebug) stderr.writeln("pat length more that top: ", pat, " ", top, " returns false");
            return false;
        }
        if (e != top[i])
        {
            if (i == pat.length - 1 && e == ANYLVL)
            {
                debug (TopicMatchDebug) stderr.writeln("matched: ", pat, " ", top);
                return true;
            }
            else if (e == ANY) { /+ pass +/ }
            else
            {
                debug (TopicMatchDebug) stderr.writefln("%s %s mismatch %s and %s (idx: %d) returns false", pat, top, e, top[i], i);
                return false;
            }
        }
    }
    debug (TopicMatchDebug) stderr.writeln("matched: ", pat, " ", top);
    return true;
}

unittest
{
    import std.exception;
    assertThrown(match("any", "#/"));
    assertNotThrown(match("any", "/#"));

    assert( match("a/b/c/d", "a/b/c/d"));
    assert( match("a/b/c/d", "+/b/c/d"));
    assert( match("a/b/c/d", "a/+/c/d"));
    assert( match("a/b/c/d", "a/b/+/d"));
    assert( match("a/b/c/d", "a/b/c/+"));
    assert( match("a/b/c/d", "+/b/c/+"));
    assert( match("a/b/c/d", "a/+/c/+"));
    assert( match("a/b/c/d", "a/b/+/+"));
    assert( match("a/b/c/d", "+/b/+/+"));
    assert( match("a/b/c/d", "a/+/+/+"));
    assert( match("a/b/c/d", "+/+/+/+"));

    assert(!match("a/b/c/d", "b/+/c/d"));
    assert(!match("a/b/c/d", "a/b/c"));
    assert(!match("a/b/c/d", "+/+/+"));

    assert(!match("a/b/c/d", "+/+/+"));
    assert( match("a/b/c/d", "+/+/#"));
    assert(!match("a/b", "+/+/#"));
    assert( match("a/b/", "+/+/#"));

    assert( match("/a/b", "#"));
    assert( match("/a//b", "#"));
    assert( match("a//b", "#"));
    assert( match("a/b", "#"));
    assert( match("a/b/", "#"));
    assert( match("/a/b", "/#"));
    assert( match("/a/b", "/+/b"));
    assert( match("/a/b", "+/+/b"));
    assert( match("/a//b", "/#"));
    assert( match("/a//b", "/a/+/b"));
}
