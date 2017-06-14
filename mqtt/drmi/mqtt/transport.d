module drmi.mqtt.transport;

import std.exception : enforce;

public import drmi.ps.iface;

import mqttd;
import drmi.mqtt.subscriber;

///
class MqttTransport : Transport
{
    MqttClient pub;
    Subscriber sub;

    ///
    void init(string name)
    {
        Settings sset, pset;
        sset.clientId = name ~ ".sub";
        pset.clientId = name ~ ".pub";

        pub = new MqttClient(pset);
        sub = new Subscriber(sset);
    }

    ///
    void connect()
    {
        pub.connect();
        sub.connect();
    }

    ///
    void publish(string topic, const(ubyte)[] data, Rel lvl)
    { enforce(pub).publish(topic, data, trRel2QoS(lvl)); }

    ///
    void subscribe(string topic, void delegate(string, const(ubyte)[]) dlg, Rel lvl)
    { enforce(sub).subscribe(topic, dlg, trRel2QoS(lvl)); }
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