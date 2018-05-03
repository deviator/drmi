### D Remote Method Invocation

[![Build Status](https://travis-ci.org/deviator/drmi.svg?branch=master)](https://travis-ci.org/deviator/drmi)
(Posix only)

This package provide high level wraps for remote method invocation and MQTT low level transport (`drmi:mqtt`) as example.

`RMICom` base interface with one method `RMIResponse process(RMICall)`.

`class RMISkeleton(T) : RMICom` is server-side wrap, method `process` must be used in your event loop for dispatch process to real object.

`class RMIStub(T) : T` is client-side wrap, it's use `class RMIStubCom : RMICom` for sending messages and get's responses. `RMIStubCom` has `string caller() const @property` field for filling `caller` field in `RMICall`.

Your interface methods must have paramters and return value serializable with `drmi.sbin` (simple binary serialize/deserialize).

See `example` dir.

`drmi:mqtt` required `libmosquitto`.