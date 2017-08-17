///
module drmi.core.exceptions;

import drmi.core.types;

import std.conv : text;

///
class RMIProcessException : Exception
{
    ///
    RMIResponse res;
    ///
    this(RMIResponse r, string msg) { res = r; super(msg); }
}

///
class RMITimeoutException : Exception
{
    ///
    RMICall call;
    ///
    this(RMICall c) { call = c; super("timeout for " ~ text(c)); }
}