module drmi.mqtt.client;

import std.algorithm : map;
import std.exception;
import std.array : array;
import std.string;

import drmi.mqtt.mosquitto;
import drmi.ps.types;

static this() { mosquitto_lib_init(); }
static ~this() { mosquitto_lib_cleanup(); }

class MosquittoClient
{
protected:
    mosquitto mosq;

    static struct CB
    {
        string pattern;
        void delegate(string, const(ubyte)[]) func;
        QoS qos;
    }

    CB[] slist;

public:

    struct Message
    {
        string topic;
        const(ubyte)[] payload;
    }

    struct Settings
    {
        string host = "127.0.0.1";
        ushort port = 1883;
        string clientId;
        bool cleanSession;
        int keepalive;
    }

    Settings settings;

    void delegate() onConnect;

    extern(C) static void onConnectCallback(mosquitto mosq, void* cptr, int res)
    {
        auto cli = enforce(cast(MosquittoClient)cptr, "null cli");
        enum Res
        {
            success = 0,
            unacceptable_protocol_version = 1,
            identifier_rejected = 2,
            broker_unavailable = 3
        }
        enforce(res == 0, format("connection error: %s", cast(Res)res));
        cli.subscribeList();
        if (cli.onConnect !is null) cli.onConnect();
    }

    extern(C) static void onMessageCallback(mosquitto mosq, void* cptr, const mosquitto_message* msg)
    {
        auto cli = enforce(cast(MosquittoClient)cptr, "null cli");
        cli.onMessage(Message(msg.topic.fromStringz.idup, cast(ubyte[])msg.payload[0..msg.payloadlen].dup));
    }

    this(Settings s)
    {
        import core.stdc.errno;

        settings = s;

        mosq = enforce(mosquitto_new(s.clientId.toStringz, s.cleanSession, cast(void*)this),
        format("error while create mosquitto: %d", errno));

        mosquitto_connect_callback_set(mosq, &onConnectCallback);
        //mosquitto_disconnect_callback_set(mosq, &onDisconnectCallback);
        mosquitto_message_callback_set(mosq, &onMessageCallback);
    }

    void loop() { mosquitto_loop(mosq, 0, 1); }

    void connect()
    {
        if (auto r = mosquitto_connect(mosq, settings.host.toStringz, settings.port, settings.keepalive))
            enforce(false, format("error while connection: %s", cast(MOSQ_ERR)r));
    }

    protected void onMessage(Message msg)
    {
        foreach (cb; slist)
        {
            bool res;
            mosquitto_topic_matches_sub(cb.pattern.toStringz,
                                        msg.topic.toStringz,
                                        &res);
            if (res) cb.func(msg.topic, msg.payload);
        }
    }

    void publish(string t, const(ubyte)[] d, QoS qos=QoS.l0, bool retain=false)
    { mosquitto_publish(mosq, null, t.toStringz, cast(int)d.length, d.ptr, qos, retain); }

    void subscribe(string pattern, void delegate(string, const(ubyte)[]) cb, QoS qos)
    { slist ~= CB(pattern, cb, qos); }

    protected void subscribeList()
    {
        foreach (cb; slist)
            mosquitto_subscribe(mosq, null, cb.pattern.toStringz, cb.qos);
    }
}