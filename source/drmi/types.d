///
module drmi.types;

public import drmi.sbin;

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
    ubyte[] data;
}

///
struct RMIResponse
{
    ///
    uint status;
    ///
    RMICall call;
    ///
    ubyte[] data;
}
