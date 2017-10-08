module mosquitto.client;

import std.algorithm : map;
import std.exception;
import std.array : array;
import std.string;

public import mosquitto.api;

class MosquittoException : Exception
{
    MOSQ_ERR err;
    this(MOSQ_ERR err, string func)
    {
        this.err = err;
        super(format("%s returns %d (%s)", func, err, err));
    }
}

private void mosqCheck(alias fnc, Args...)(Args args)
{
    if (auto r = cast(MOSQ_ERR)fnc(args))
        throw new MosquittoException(r, __traits(identifier, fnc));
}

class MosquittoClient
{
protected:
    mosquitto_t mosq;

    static struct Callback
    {
        string pattern;
        void delegate(string, const(ubyte)[]) func;
        int qos;
    }

    Callback[] slist;

    bool _connected;

public:

    struct Message
    {
        string topic;
        const(ubyte)[] payload;
    }

    struct Settings
    {
        string host = "::1";
        ushort port = 1883;
        string clientId;
        bool cleanSession = false;
        int keepalive = 5;
    }

    Settings settings;

    void delegate() onConnect;

    extern(C) protected static
    {
        void onConnectCallback(mosquitto_t mosq, void* cptr, int res)
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
            cli._connected = true;
            cli.subscribeList();
            if (cli.onConnect !is null) cli.onConnect();
        }

        void onDisconnectCallback(mosquitto_t mosq, void* cptr, int res)
        {
            auto cli = enforce(cast(MosquittoClient)cptr, "null cli");
            cli._connected = false;
        }

        void onMessageCallback(mosquitto_t mosq, void* cptr, const mosquitto_message* msg)
        {
            auto cli = enforce(cast(MosquittoClient)cptr, "null cli");
            cli.onMessage(Message(msg.topic.fromStringz.idup, cast(ubyte[])msg.payload[0..msg.payloadlen]));
        }
    }

    protected void subscribeList()
    {
        foreach (cb; slist)
            mosqCheck!mosquitto_subscribe(mosq, null,
                            cb.pattern.toStringz, cb.qos);
    }

    protected void onMessage(Message msg)
    {
        foreach (cb; slist)
        {
            bool res;
            mosqCheck!mosquitto_topic_matches_sub(cb.pattern.toStringz,
                                              msg.topic.toStringz,
                                              &res);
            if (res) cb.func(msg.topic, msg.payload);
        }
    }

    this(Settings s)
    {
        import core.stdc.errno;

        settings = s;

        mosq = enforce(mosquitto_new(s.clientId.toStringz,
                        s.cleanSession, cast(void*)this),
        format("error while create mosquitto: %d", errno));

        mosquitto_connect_callback_set(mosq, &onConnectCallback);
        mosquitto_message_callback_set(mosq, &onMessageCallback);
    }

    ~this() { disconnect(); }

    bool connected() const @property { return _connected; }

    void loop() { mosqCheck!mosquitto_loop(mosq, 0, 1); }

    void connect()
    {
        mosqCheck!mosquitto_connect(mosq,
                settings.host.toStringz, settings.port,
                settings.keepalive);
    }

    void reconnect() { mosqCheck!mosquitto_reconnect(mosq); }

    void disconnect() { mosqCheck!mosquitto_disconnect(mosq); }

    void publish(string t, const(ubyte)[] d, int qos=0,
                 bool retain=false)
    {
        mosqCheck!mosquitto_publish(mosq, null, t.toStringz,
        cast(int)d.length, d.ptr, qos, retain);
    }

    void subscribe(string pattern, void delegate(string,
                    const(ubyte)[]) cb, int qos)
    {
        slist ~= Callback(pattern, cb, qos);
        if (connected) mosqCheck!mosquitto_subscribe(mosq,
                                null, pattern.toStringz, qos);
    }
}