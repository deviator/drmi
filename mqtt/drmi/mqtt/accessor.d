///
module drmi.mqtt.accessor;

import drmi.ps.accessor;
import drmi.mqtt.transport;

///
class MqttAccessor(T) : Accessor!T
{
    ///
    this(T obj) { super(new MqttTransport, obj); }
}