///
module drmi.ps.types;

///
enum QoS : int
{
    ///
    undefined = -1,
    ///
    l0 = 0,
    ///
    l1 = 1,
    ///
    l2 = 2,
    ///
    reserved = 3,
    ///
    failure = 0x80
}