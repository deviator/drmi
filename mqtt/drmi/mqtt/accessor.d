///
module drmi.mqtt.accessor;

import drmi.ps.accessor;
import drmi.mqtt.transport;

import std.datetime : Duration;

///
class MqttAccessor(T) : Accessor!T
{
    ///
    this(T obj, void delegate(Duration d) sp=null) { super(new MqttTransport, obj, sp); }
    ///
    this(T obj, string uniq, void delegate(Duration d) sp=null) { super(new MqttTransport, obj, uniq, sp); }
}