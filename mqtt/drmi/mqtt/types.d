module drmi.mqtt.types;

import vibe.data.json;

struct BusData
{
    Json value;
    string type;

    this(T)(T value, string type="")
    {
        this.value = value.serializeToJson;
        this.type = type.length != 0 ? type : T.stringof;
    }

    T as(T)() const @property { return value.deserializeJson!T; }
}