///
module drmi.ps.accessor;

import drmi.core;

import drmi.ps.helpers;
import drmi.ps.iface;

import std.datetime;
import std.string;
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
    { this.publish(val.sbinSerialize, qos); }
}

///
class Accessor(T)
{
protected:
    Transport ll;

    QoS defaultQoS;

    Duration waitTime;
    Duration waitSleepStep;
    size_t maxWaitResponses;

    string name;

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

    void publish(V)(string topic, V val, QoS qos=QoS.undefined)
        if (!is(Unqual!T == ubyte[]))
    { publish(topic, val.sbinSerialize, qos); }

    void publish(string topic, const(ubyte)[] data, QoS qos=QoS.undefined)
    {
        if (qos == QoS.undefined) qos = defaultQoS;
        ll.publish(topic, data, qos);
    }

    class BCaster : Broadcaster
    {
        string topic;
        this(string t) { topic = t; }
        override void publish(const(ubyte)[] data, QoS qos=QoS.undefined)
        { this.outer.publish(topic, data, qos); }
    }

    RMISkeleton!T skeleton;

    void receive(string t, RMICall call)
    {
        import std.range : repeat;
        import std.algorithm : joiner;

        .infof("[%s] *** %s %s %s", cts, call.caller, call.ts, call.func);
        auto res = skeleton.process(call);
        publish(name ~ RES_ROOM ~ call.caller, res, defaultQoS);
        .infof("[%s] === %s %s", cts, " ".repeat(call.caller.length).joiner(""), call.ts);
    }

    class CliCom : RMIStubCom
    {
        import std.exception : enforce;
        import std.conv : text;
        import std.string;

        string target, reqbus;
        RMIResponse[string] responses;
        string[string] waitList;

        this(string target)
        {
            this.target = target;
            this.reqbus = target ~ REQ_ROOM;
        }

        string calcHash(RMICall call)
        { return format("%s:%s", call.func, call.ts); }

        void receive(string t, RMIResponse r)
        {
            if (r.call.caller != caller)
            {
                .errorf("unexpected response for %s in bus for %s", r.call.caller, caller);
                return;
            }
            .infof("[%s]  in %s %s", cts, r.call.ts, r.call.func);
            auto ch = calcHash(r.call);
            if (ch in waitList)
            {
                enforce(ch !in responses, format("internal error: unexpect having result in res for %s", ch));
                responses[ch] = r;
                waitList.remove(ch);
            }
            else .errorf("unexpected %s for calls: %s", r, waitList.keys);
        }

        override string caller() const @property { return name; }

        override RMIResponse process(RMICall call)
        {
            while (waitList.length >= maxWaitResponses)
                this.outer.sleep(waitSleepStep * 10);
            auto ch = calcHash(call);
            waitList[ch] = ch;
            .infof("[%s] out %s %s", cts, call.ts, call.func);
            publish(reqbus, call, defaultQoS);
            auto tm = StopWatch(AutoStart.yes);
            while (ch in waitList)
            {
                if (cast(Duration)tm.peek > waitTime)
                {
                    .infof("[%s] ### %s %s", cts, call.ts, call.func);
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
        ll = enforce(t, "transport is null");
        name = rmiPSClientName!T(uniqName);
        ll.init(name);

        defaultQoS = QoS.l2;
        this.waitTime = waitTime;
        this.waitSleepStep = waitSleepStep;
        this.maxWaitResponses = maxWaitResponses;

        skeleton = new RMISkeleton!T(serv);

        subscribe(name~REQ_ROOM, &this.receive);
    }

    this(Transport t, T serv, void delegate(Duration) sf=null)
    {
        this(t, serv, "", sf);
    }

    Broadcaster getBroadcaster(string topic) { return new BCaster(topic); }

    void subscribe(string topic, void delegate(string, const(ubyte)[]) dlg, QoS qos=QoS.undefined)
    { ll.subscribe(topic, dlg, qos==QoS.undefined ? defaultQoS : qos); }

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

    void connect() { ll.connect(); }
}

private long cts()()
{
    import std.datetime;
    return Clock.currStdTime;
}