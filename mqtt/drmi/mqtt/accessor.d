///
module drmi.mqtt.accessor;

import drmi.ps.accessor;
import drmi.mqtt.transport;

import sfw;
public import sfw.func;

import std.algorithm;
import std.array;
import std.datetime;
import core.thread;
import std.conv;
import std.experimental.logger;

///
class MqttAccessor(T) : Accessor!T
{
protected:
    MqttTransport tr;

    void callTransportLoop() { tr.loop(); }

public:
    SFWApp app;

    alias Settings = MosquittoClient.Settings;

    ///
    this(T obj, string uniq="") { this(obj, Settings.init, uniq); }

    ///
    this(T obj, Settings sets, string uniq="")
    {
        tr = new MqttTransport(sets);
        super(tr, obj, uniq, (s){ sfw.sleep(s); });
        app = new SFWApp(128);
        app.spawnInfLoop({ callTransportLoop(); });
    }
}