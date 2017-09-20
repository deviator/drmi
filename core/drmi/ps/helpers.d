module drmi.ps.helpers;

/++
 +/
string rmiPSClientName(T)(string uniqId="")
{
    import std.string : format;
    enum tname = T.stringof;
    return uniqId.length ? format("%s_%s", tname, uniqId) : tname;
}