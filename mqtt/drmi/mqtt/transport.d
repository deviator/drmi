module drmi.mqtt.transport;

import std.exception : enforce;

public import drmi.ps.iface;

import mqttd;
import drmi.mqtt.client;

///
class MqttTransport : Transport
{
    IMClient cli;

    ///
    void init(string name)
    {
        Settings sets;
        sets.clientId = name;
        cli = new IMClient(sets);
    }

    ///
    void connect() { cli.connect(); }

    ///
    void publish(string topic, const(ubyte)[] data, Rel lvl)
    { enforce(cli).publish(topic, data, trRel2QoS(lvl)); }

    ///
    void subscribe(string topic, void delegate(string, const(ubyte)[]) dlg, Rel lvl)
    { enforce(cli).subscribe(topic, dlg, trRel2QoS(lvl)); }
}

private QoSLevel trRel2QoS(Rel r)
{
    with (Rel) with (QoSLevel) final switch (r)
    {
        case undefined: return QoS0;
        case level0: return QoS0;
        case level1: return QoS1;
        case level2: return QoS2;
    }
}