///
module drmi.ps.accessor;

import drmi.exceptions;
import drmi.types;
import drmi.base;

import drmi.ps.helpers;
import drmi.ps.iface;

import std.datetime;
import std.string;
import std.exception : enforce;

public import vibe.data.json : Json;
import vibe.data.json;
import vibe.core.core;
import vibe.core.log;

enum REQ_ROOM = "/request";
enum RES_ROOM = "/response/";

///
interface Broadcaster
{
    ///
    void publish(Json, Rel lvl=Rel.undefined);
    ///
    void publish(T)(T val, Rel lvl=Rel.undefined)
    { this.publish(val.serializeToPrettyJson, lvl); }
}

///
class Accessor(T)
{
protected:
    Transport ll;

    Rel defaultRel;

    Duration waitTime;
    Duration waitSleepStep;
    size_t maxWaitResponses;

    string name;

    void publish(V)(string topic, V val, Rel lvl=Rel.undefined)
    {
        if (lvl == Rel.undefined) lvl = defaultRel;
        ll.publish(topic, cast(const(ubyte)[])val.serializeToPrettyJson, lvl);
    }

    class BCaster : Broadcaster
    {
        string topic;
        this(string t) { topic = t; }
        override void publish(Json d, Rel lvl=Rel.undefined)
        { this.outer.publish(topic, d, lvl); }
    }

    RMISkeleton!T skeleton;

    void receive(string t, Json msg)
    {
        RMICall call = void;
        try call = msg.deserializeJson!RMICall;
        catch (Throwable e)
        {
            logError("error in parse request: %s", e.msg);
            return;
        }
        import std.range : repeat;
        import std.algorithm : joiner;

        logDebug("[%s] *** %s %s %s", cts, call.caller, call.ts, call.func);
        auto res = skeleton.process(call);
        publish(name ~ RES_ROOM ~ call.caller, res, defaultRel);
        logDebug("[%s] === %s %s", cts, " ".repeat(call.caller.length).joiner(""), call.ts);
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

        void receive(string t, Json msg)
        {
            RMIResponse r = void;
            try r = msg.deserializeJson!RMIResponse;
            catch (Throwable e)
            {
                logError("unexpected request message: %s (%s)", msg, e.msg);
                return;
            }
            if (r.call.caller != caller)
            {
                logError("unexpected response for %s in bus for %s", r.call.caller, caller);
                return;
            }
            logDebug("[%s]  in %s %s", cts, r.call.ts, r.call.func);
            auto ch = calcHash(r.call);
            if (ch in waitList)
            {
                enforce(ch !in responses, format("internal error: unexpect having result in res for %s", ch));
                responses[ch] = r;
                waitList.remove(ch);
            }
            else logError("unexpected %s for calls: %s", r, waitList.keys);
        }

        override string caller() const @property { return name; }

        override RMIResponse process(RMICall call)
        {
            while (waitList.length >= maxWaitResponses)
                sleep(waitSleepStep * 10);
            auto ch = calcHash(call);
            waitList[ch] = ch;
            logDebug("[%s] out %s %s", cts, call.ts, call.func);
            publish(reqbus, call, defaultRel);
            auto tm = StopWatch(AutoStart.yes);
            while (ch in waitList)
            {
                if (cast(Duration)tm.peek > waitTime)
                {
                    logDebug("[%s] ### %s %s", cts, call.ts, call.func);
                    waitList.remove(ch);
                    throw new RMITimeoutException(call);
                }
                else sleep(waitSleepStep);
            }
            enforce(ch in responses, format("internal error: no result then not wait and not except for %s", ch));
            auto r = responses[ch];
            responses.remove(ch);
            return r;
        }
    }

public:

    this(Transport t, T serv, string uniqName="")
    {
        ll = enforce(t, "transport is null");
        name = rmiPSClientName!T(uniqName);
        ll.init(name);

        defaultRel = Rel.level1;
        waitTime = 30.seconds;
        waitSleepStep = 1.msecs;
        maxWaitResponses = 100;

        skeleton = new RMISkeleton!T(serv);

        subscribe(name~REQ_ROOM, &this.receive);
    }

    Broadcaster getBroadcaster(string topic) { return new BCaster(topic); }

    void subscribe(string topic, void delegate(string, const(ubyte)[]) dlg)
    { ll.subscribe(topic, dlg, defaultRel); }

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

    void subscribe(V)(string bus, void delegate(string, V bm) dlg)
    {
        subscribe(bus, (string t, const(ubyte)[] data)
        {
            V bm = void;
            // for accurance exception handling
            bool converted = false;
            try // catch exceptions only while deserialization
            {
                bm = (cast(string)data).deserializeJson!V;
                converted = true;
            }
            catch (Exception e)
                // vibe.data.json.deserializeJson has no throwable exception
                // list in documentation
                logError("error while parse %s: %s", V.stringof, e.msg);

            // if all is ok call delegate
            if (converted) dlg(t, bm);
        });
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