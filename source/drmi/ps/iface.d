///
module drmi.ps.iface;

public import drmi.ps.types;

///
interface Transport
{
    ///
    void init(string name);
    ///
    void connect();
    ///
    void publish(string topic, const(ubyte)[] data, QoS qos);
    ///
    void subscribe(string topic, void delegate(string, const(ubyte)[]) dlg, QoS qos);
}