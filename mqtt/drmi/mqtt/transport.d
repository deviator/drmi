module drmi.mqtt.transport;

import std.exception : enforce;

public import drmi.ps.iface;

public import mosquittod;

///
class MqttTransport : Transport
{
private:
    MosquittoClient cli;
    MosquittoClient ecli() @property { return enforce(cli, "cli is null"); }

    MosquittoClient.Settings sets;
public:

    ///
    this(MosquittoClient.Settings sets)
    {
        this.sets = sets;
        initMosquittoLib();
    }

    ///
    void init(string name)
    {
        sets.clientId = name;
        cli = new MosquittoClient(sets);
    }

    ///
    void connect() { ecli.connect(); }
    ///
    bool connected() { return ecli.connected(); }
    ///
    void reconnect() { ecli.reconnect(); }

    ///
    void loop() { ecli.loop(); }

    ///
    void publish(string topic, const(ubyte)[] data, QoS qos)
    { ecli.publish(topic, qos, data); }

    ///
    void subscribe(string pattern, void delegate(const(char)[], const(void)[]) dlg, QoS qos)
    { ecli.subscribe(pattern, cast(int)qos, dlg); }
}