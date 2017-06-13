module drmi.mqtt.accessor;

import mqttd;
import vibe.data.json;
import vibe.core.log;
import vibe.core.core;

import drmi;

import drmi.mqtt.types;
import drmi.mqtt.subscriber;

import std.datetime;
import std.string;

enum REQ_ROOM = "/request";
enum RES_ROOM = "/response/";

interface Broadcaster
{
    void pub(BusData, QoSLevel q=QoSLevel.Reserved);

    final void pub(T)(T val, string type="", QoSLevel q=QoSLevel.Reserved) if (!is(T == BData))
    { this.pub(BusData(val, type), q); }
}

string cliName(T)(string un)
{ return un.length ? format("%s_%s", T.stringof, un) : T.stringof; }

class Accessor(T)
{
protected:
    Subscriber sub;
    MqttClient pub;

    QoSLevel qos;

    Duration waitTime;
    size_t maxWaitResponses;

    string name;

    void publish(V)(string topic, V val, QoSLevel q=QoSLevel.Reserved)
    {
        if (q == QoSLevel.Reserved) q = qos;
        pub.publish(topic, val.serializeToPrettyJson, q);
    }

    class BCaster : Broadcaster
    {
        string bus;
        this(string bus) { this.bus = bus; }
        override void pub(BusData d, QoSLevel q=QoSLevel.Reserved)
        { publish(bus, d, q); }
    }

    RMISkeleton!T skeleton;

    void receive(string t, BusData msg)
    {
        if (msg.type == RMICall.stringof)
        {
            import std.range : repeat;
            import std.algorithm : joiner;
            auto call = msg.as!RMICall;
            logDebug("[%s] *** %s %s %s", cts, call.caller, call.ts, call.func);
            auto res = skeleton.process(call);
            publish(name ~ RES_ROOM ~ call.caller, BusData(res), qos);
            logDebug("[%s] === %s %s", cts, " ".repeat(call.caller.length).joiner(""), call.ts);
        }
        else logWarn("unexpected request message: %s", msg);
    }

    class CliCom : RMIStubCom
    {
        import std.exception : enforce;
        import std.conv : text;
        import std.string;

        string target, reqbus;
        RMIResponse[string] res;
        string[string] waitList;

        Duration sleepStep;

        this(string target)
        {
            this.target = target;
            this.reqbus = target ~ REQ_ROOM;
            sleepStep = 1.msecs;
        }

        string callHash(RMICall call)
        { return format("%s:%s", call.func, call.ts); }

        void receive(string t, BusData msg)
        {
            if (msg.type == RMIResponse.stringof)
            {
                auto r = msg.as!RMIResponse;
                if (r.call.caller != caller)
                {
                    logError("unexpected response for %s in bus for %s", r.call.caller, caller);
                    return;
                }
                logDebug("[%s]  in %s %s", cts, r.call.ts, r.call.func);
                auto ch = callHash(r.call);
                if (ch in waitList)
                {
                    enforce(ch !in res, format("internal error: unexpect having result in res for %s", ch));
                    res[ch] = r;
                    waitList.remove(ch);
                }
                else logTrace("unexpected %s for calls: %s", r, waitList.keys);
            }
            else logWarn("unexpected request message: %s", msg);
        }

        override string caller() const @property { return name; }

        override RMIResponse process(RMICall call)
        {
            while (waitList.length >= maxWaitResponses) sleep(sleepStep * 10);
            auto ch = callHash(call);
            waitList[ch] = ch;
            logDebug("[%s] out %s %s", cts, call.ts, call.func);
            publish(reqbus, BusData(call));
            auto tm = StopWatch(AutoStart.yes);
            while (ch in waitList)
            {
                if (cast(Duration)tm.peek > waitTime)
                {
                    logDebug("[%s] ### %s %s", cts, call.ts, call.func);
                    waitList.remove(ch);
                    throw new RMITimeoutException(call);
                }
                else sleep(sleepStep);
            }
            enforce(ch in res, format("internal error: no result then not wait and not except for %s", ch));
            auto r = res[ch];
            res.remove(ch);
            return r;
        }
    }

public:

    this(T serv, string uniqName="")
    {
        name = cliName!T(uniqName);
        qos = QoSLevel.QoS2;
        waitTime = 5.minutes;
        maxWaitResponses = 100;

        skeleton = new RMISkeleton!T(serv);

        Settings pset, sset;
        pset.clientId = name ~ ".pub";
        sset.clientId = name ~ ".sub";

        pub = new MqttClient(pset);
        sub = new Subscriber(sset, qos);

        subscribe(name~REQ_ROOM, &this.receive);
    }

    Broadcaster getBroadcaster(string bus) { return new BCaster(bus); }

    void subscribe(string bus, void delegate(string, const(ubyte)[]) dlg)
    { sub.subscribe(bus, dlg); }

    void subscribe(string bus, void delegate(string, Json) dlg)
    {
        subscribe(bus, (string t, const(ubyte)[] data)
        {
            auto j = Json.undefined;
            try j = (cast(string)data).parseJsonString;
            catch (JSONException e)
                logError("error while parsing json msg: ", e.msg);
            if (j != Json.undefined) dlg(t, j);
            else logWarn("parsed json is undefined, don't call dlg");
        });
    }

    void subscribe(string bus, void delegate(string, BusData bm) dlg)
    {
        subscribe(bus, (string t, Json j)
        {
            BusData bm;
            // for accurance exception handling
            bool converted = false;
            try // catch exceptions only while deserialization
            {
                bm = j.deserializeJson!BusData;
                converted = true;
            }
            catch (Exception e)
                // vibe.data.json.deserializeJson has no throwable exception
                // list in documentation
                logError("error while convert json to BusMessage: ", e.msg);

            // if all is ok call delegate
            if (converted) dlg(t, bm);
        });
    }

    RMIStub!X getClient(X)(string uniqName="")
    {
        auto cn = cliName!X(uniqName);
        auto clicom = new CliCom(cn);
        subscribe(cn ~ RES_ROOM ~ name, &clicom.receive);
        return new RMIStub!X(clicom);
    }

    void connect()
    {
        pub.connect();
        sub.connect();
    }
}

private long cts()()
{
    import std.datetime;
    return Clock.currStdTime;
}