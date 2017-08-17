module drmi.mqtt.transport;

import std.exception : enforce;

public import drmi.ps.iface;

import mosquitto;

///
class MqttTransport : Transport
{
    MosquittoClient cli;

    ///
    void init(string name)
    {
        initMosquittoLib();

        MosquittoClient.Settings sets;
        sets.clientId = name;
        cli = new MosquittoClient(sets);
    }

    ///
    void connect() { cli.connect(); }

    ///
    void publish(string topic, const(ubyte)[] data, QoS qos)
    { enforce(cli).publish(topic, data, qos); }

    ///
    void subscribe(string topic, void delegate(string, const(ubyte)[]) dlg, QoS qos)
    { enforce(cli).subscribe(topic, dlg, qos); }

    void loop() { enforce(cli).loop(); }
}