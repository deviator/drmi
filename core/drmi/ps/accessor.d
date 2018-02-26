///
module drmi.ps.accessor;

import drmi.core;

import drmi.ps.helpers;
import drmi.ps.iface;

import std.datetime.stopwatch;
import std.string;
import std.array : appender, Appender;
import std.exception : enforce;
import std.experimental.logger;

enum REQ_ROOM = "/request";
enum RES_ROOM = "/response/";

///
interface Broadcaster
{
    ///
    void publish(const(ubyte)[], QoS qos=QoS.undefined);

    ///
    final void publish(T)(T val, QoS qos=QoS.undefined)
        if (!is(Unqual!T == ubyte[]))
    {
        auto buf = localAppender();
        buf.clear();
        buf.sbinSerialize(val);
        this.publish(buf.data, qos);
    }

    protected ref Appender!(ubyte[]) localAppender() @property;
}

///
class Accessor(T)
{
protected:
    Transport tport;

    QoS defaultQoS;

    Duration waitTime;
    Duration waitSleepStep;
    size_t maxWaitResponses;

    string name;

    auto sBuffer = appender!(ubyte[]);

    void delegate(Duration d) sleepFunc;

    void sleep(Duration t)
    {
        import core.thread;
        if (sleepFunc !is null) sleepFunc(t);
        else
        {
            if (auto f = Fiber.getThis()) f.yield();
            else Thread.sleep(t);
        }
    }

    class BCaster : Broadcaster
    {
        string topic;
        this(string t) { topic = t; }
        override void publish(const(ubyte)[] data, QoS qos=QoS.undefined)
        { this.outer.publish(topic, data, qos); }
        protected override ref Appender!(ubyte[]) localAppender() @property
        { return this.outer.sBuffer; }
    }

    RMISkeleton!T skeleton;

    void receive(string t, RMICall call)
    {
        import std.range : repeat;
        import std.algorithm : joiner;

        version (drmi_verbose) .infof("[%s] *** %s %s %s", cts, call.caller, call.ts, call.func);
        auto res = skeleton.process(call);
        publish(name ~ RES_ROOM ~ call.caller, res, defaultQoS);
        version (drmi_verbose) .infof("[%s] === %s %s", cts, " ".repeat(call.caller.length).joiner(""), call.ts);
    }

    class CliCom : RMIStubCom
    {
        import std.exception : enforce;
        import std.conv : text;
        import std.string;

        alias rhash_t = ubyte[28];

        string target, reqbus;
        RMIResponse[rhash_t] responses;
        rhash_t[rhash_t] waitList;

        this(string target)
        {
            this.target = target;
            this.reqbus = target ~ REQ_ROOM;
        }

        rhash_t calcHash(RMICall call) @nogc
        {
            import std.digest.sha;
            auto r1 = sha224Of(call.func);
            auto r2 = sha224Of(cast(ulong[1])[call.ts]);
            r1[] += r2[];
            return r1;
        }

        void receive(string t, RMIResponse r)
        {
            if (r.call.caller != caller)
            {
                .errorf("unexpected response for %s in bus for %s", r.call.caller, caller);
                return;
            }

            version (drmi_verbose) .infof("[%s]  in %s %s", cts, r.call.ts, r.call.func);
            auto ch = calcHash(r.call);

            if (ch !in waitList)
            {
                .errorf("unexpected %s for calls: %s", r, waitList.keys);
                return;
            }

            enforce(ch !in responses, format("internal error: unexpect having result in res for %s", ch));
            responses[ch] = r;
            waitList.remove(ch);
        }

        override string caller() const @property { return name; }

        override RMIResponse process(RMICall call)
        {
            while (waitList.length >= maxWaitResponses)
                this.outer.sleep(waitSleepStep * 10);
            auto ch = calcHash(call);
            waitList[ch] = ch;
            version (drmi_verbose) .infof("[%s] out %s %s", cts, call.ts, call.func);
            publish(reqbus, call, defaultQoS);
            auto tm = StopWatch(AutoStart.yes);
            while (ch in waitList)
            {
                if (cast(Duration)tm.peek > waitTime)
                {
                    version (drmi_verbose) .infof("[%s] ### %s %s", cts, call.ts, call.func);
                    waitList.remove(ch);
                    throw new RMITimeoutException(call);
                }
                else this.outer.sleep(waitSleepStep);
            }
            enforce(ch in responses, format("internal error: no result then not wait and not except for %s", ch));
            auto r = responses[ch];
            responses.remove(ch);
            return r;
        }
    }

public:

    this(Transport t, T serv, string uniqName="", void delegate(Duration) sf=null,
            Duration waitTime=30.seconds, Duration waitSleepStep=1.msecs, size_t maxWaitResponses=10)
    {
        tport = enforce(t, "transport is null");
        name = rmiPSClientName!T(uniqName);
        tport.init(name);

        defaultQoS = QoS.l2;
        this.waitTime = waitTime;
        this.waitSleepStep = waitSleepStep;
        this.maxWaitResponses = maxWaitResponses;

        skeleton = new RMISkeleton!T(serv);

        subscribe(name~REQ_ROOM, &this.receive);
    }

    this(Transport t, T serv, void delegate(Duration) sf=null)
    { this(t, serv, "", sf); }

    void publish(V)(string topic, V val, QoS qos=QoS.undefined)
        if (!is(Unqual!T == ubyte[]))
    {
        sBuffer.clear();
        sBuffer.sbinSerialize(val);
        publish(topic, sBuffer.data, qos);
    }

    void publish(string topic, const(ubyte)[] data, QoS qos=QoS.undefined)
    {
        if (qos == QoS.undefined) qos = defaultQoS;
        tport.publish(topic, data, qos);
    }

    Broadcaster getBroadcaster(string topic) { return new BCaster(topic); }

    void subscribe(string topic, void delegate(string, const(ubyte)[]) dlg, QoS qos=QoS.undefined)
    { tport.subscribe(topic, dlg, qos==QoS.undefined ? defaultQoS : qos); }

    void subscribe(V)(string bus, void delegate(string, V) dlg, QoS qos=QoS.undefined)
        if (!is(V == const(ubyte)[]))
    {
        subscribe(bus, (string t, const(ubyte)[] data)
        {
            V bm = void;
            // for accurance exception handling
            bool converted = false;
            try // catch exceptions only while deserialization
            {
                bm = data.sbinDeserialize!V;
                converted = true;
            }
            catch (Exception e)
                // vibe.data.json.deserializeJson has no throwable exception
                // list in documentation
                .errorf("error while parse %s: %s", V.stringof, e.msg);

            // if all is ok call delegate
            if (converted) dlg(t, bm);
        }, qos);
    }

    RMIStub!X getClient(X)(string uniqName="")
    {
        auto cn = rmiPSClientName!X(uniqName);
        auto clicom = new CliCom(cn);
        subscribe(cn ~ RES_ROOM ~ name, &clicom.receive);
        return new RMIStub!X(clicom);
    }

    void connect() { tport.connect(); }

    bool connected() { return tport.connected(); }
}

private long cts()()
{
    import std.datetime;
    return Clock.currStdTime;
}