///
module drmi.types;

public import vibe.data.json;

///
Json rmiEmptyArrayData() { return Json.emptyArray; }

///
struct RMICall
{
    ///
    string caller;
    ///
    string func;
    ///
    long ts;
    ///
    Json data;
}

///
struct RMIResponse
{
    ///
    uint status;
    ///
    RMICall call;
    ///
    Json data;
}
