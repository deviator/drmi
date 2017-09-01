module mosquitto.api.rtload;

import mosquitto.api.types;

version (ctlink) {} else:

import ssll;

version (Posix)   private enum libmosquitto_name = "libmosquitto.so";
version (Windows) private enum libmosquitto_name = "libmosquitto.dll";

private __gshared void* lib;

int initMosquittoLib()
{
    if (lib is null)
    {
        lib = loadLibrary(libmosquitto_name);
        loadApiSymbols();
        return mosquitto_lib_init();
    }
    return MOSQ_ERR.SUCCESS;
}

void cleanupMosquittoLib()
{
    mosquitto_lib_cleanup();
    unloadLibrary(&lib);
}

mixin apiSymbols;

alias mosq_tls_callback = extern(C) int function(char* buf, int size, int rwflag, void* userdata);
alias mosq_base_callback = extern(C) void function(mosquitto_t, void*, int);
alias mosq_msg_callback = extern(C) void function(mosquitto_t, void*, const mosquitto_message*);
alias mosq_sub_callback = extern(C) void function(mosquitto_t, void*, int, int, const int*);
alias mosq_log_callback = extern(C) void function(mosquitto_t, void*, int, const(char)*);

@api("lib")
{
    int mosquitto_lib_init() { mixin(rtLib); }
    int mosquitto_lib_cleanup() { mixin(rtLib); }
    mosquitto_t mosquitto_new(const(char)* id, bool clean_session, void* obj) { mixin(rtLib); }
    void mosquitto_destroy(mosquitto_t mosq) { mixin(rtLib); }
    int mosquitto_reinitialise(mosquitto_t mosq, const(char)* id, bool clean_session, void* obj) { mixin(rtLib); }
    int mosquitto_will_set(mosquitto_t mosq, const(char)* topic, int payloadlen, const(void)* payload, int qos, bool retain) { mixin(rtLib); }
    int mosquitto_will_clear(mosquitto_t mosq) { mixin(rtLib); }
    int mosquitto_username_pw_set(mosquitto_t mosq, const(char)* username, const(char)* password) { mixin(rtLib); }
    int mosquitto_connect(mosquitto_t mosq, const(char)* host, int port, int keepalive) { mixin(rtLib); }
    int mosquitto_connect_bind(mosquitto_t mosq, const(char)* host, int port, int keepalive, const(char)* bind_address) { mixin(rtLib); }
    int mosquitto_connect_async(mosquitto_t mosq, const(char)* host, int port, int keepalive) { mixin(rtLib); }
    int mosquitto_connect_bind_async(mosquitto_t mosq, const(char)* host, int port, int keepalive, const(char)* bind_address) { mixin(rtLib); }
    int mosquitto_connect_srv(mosquitto_t mosq, const(char)* host, int keepalive, const(char)* bind_address) { mixin(rtLib); }
    int mosquitto_reconnect(mosquitto_t mosq) { mixin(rtLib); }
    int mosquitto_reconnect_async(mosquitto_t mosq) { mixin(rtLib); }
    int mosquitto_disconnect(mosquitto_t mosq) { mixin(rtLib); }
    int mosquitto_publish(mosquitto_t mosq, int* mid, const(char)* topic, int payloadlen, const(void)* payload, int qos, bool retain) { mixin(rtLib); }
    int mosquitto_subscribe(mosquitto_t mosq, int* mid, const(char)* sub, int qos) { mixin(rtLib); }
    int mosquitto_unsubscribe(mosquitto_t mosq, int* mid, const(char)* sub) { mixin(rtLib); }
    int mosquitto_message_copy(mosquitto_message* dst, const mosquitto_message* src) { mixin(rtLib); }
    void mosquitto_message_free(mosquitto_message** message) { mixin(rtLib); }
    int mosquitto_loop(mosquitto_t mosq, int timeout, int max_packets) { mixin(rtLib); }
    int mosquitto_loop_forever(mosquitto_t mosq, int timeout, int max_packets) { mixin(rtLib); }
    int mosquitto_loop_start(mosquitto_t mosq) { mixin(rtLib); }
    int mosquitto_loop_stop(mosquitto_t mosq, bool force) { mixin(rtLib); }
    int mosquitto_socket(mosquitto_t mosq) { mixin(rtLib); }
    int mosquitto_loop_read(mosquitto_t mosq, int max_packets) { mixin(rtLib); }
    int mosquitto_loop_write(mosquitto_t mosq, int max_packets) { mixin(rtLib); }
    int mosquitto_loop_misc(mosquitto_t mosq) { mixin(rtLib); }
    bool mosquitto_want_write(mosquitto_t mosq) { mixin(rtLib); }
    int mosquitto_threaded_set(mosquitto_t mosq, bool threaded) { mixin(rtLib); }
    int mosquitto_opts_set(mosquitto_t mosq, MOSQ_OPT option, void* value) { mixin(rtLib); }
    int mosquitto_tls_set(mosquitto_t mosq,
                            const(char)* cafile,   const(char)* capath,
                            const(char)* certfile, const(char)* keyfile,
                            mosq_tls_callback pw_callback) { mixin(rtLib); }
    int mosquitto_tls_insecure_set(mosquitto_t mosq, bool value) { mixin(rtLib); } int mosquitto_tls_opts_set(mosquitto_t mosq, int cert_reqs, const(char)* tls_version, const(char)* ciphers) { mixin(rtLib); }
    int mosquitto_tls_psk_set(mosquitto_t mosq, const(char)* psk, const(char)* identity,  const(char)* ciphers) { mixin(rtLib); }
    void mosquitto_connect_callback_set(mosquitto_t mosq, mosq_base_callback on_connect) { mixin(rtLib); }
    void mosquitto_disconnect_callback_set(mosquitto_t mosq, mosq_base_callback on_disconnect) { mixin(rtLib); }
    void mosquitto_publish_callback_set(mosquitto_t mosq, mosq_base_callback on_publish) { mixin(rtLib); }
    void mosquitto_message_callback_set(mosquitto_t mosq, mosq_msg_callback on_message) { mixin(rtLib); }
    void mosquitto_subscribe_callback_set(mosquitto_t mosq, mosq_sub_callback on_subscribe) { mixin(rtLib); }
    void mosquitto_unsubscribe_callback_set(mosquitto_t mosq, mosq_base_callback on_unsubscribe) { mixin(rtLib); }
    void mosquitto_log_callback_set(mosquitto_t mosq, mosq_log_callback on_log) { mixin(rtLib); }
    int mosquitto_reconnect_delay_set(mosquitto_t mosq, uint reconnect_delay, uint reconnect_delay_max,
                                        bool reconnect_exponential_backoff) { mixin(rtLib); }
    int mosquitto_max_inflight_messages_set(mosquitto_t mosq, uint max_inflight_messages) { mixin(rtLib); }
    void mosquitto_message_retry_set(mosquitto_t mosq, uint message_retry) { mixin(rtLib); }
    void mosquitto_user_data_set(mosquitto_t mosq, void* obj) { mixin(rtLib); }
    int mosquitto_socks5_set(mosquitto_t mosq, const(char)* host, int port, const(char)* username, const(char)* password) { mixin(rtLib); }
    const(char)* mosquitto_strerror(int mosq_errno) { mixin(rtLib); }
    const(char)* mosquitto_connack_string(int connack_code) { mixin(rtLib); }
    int mosquitto_sub_topic_tokenise(const(char)* subtopic, char*** topics, int* count) { mixin(rtLib); }
    int mosquitto_sub_topic_tokens_free(char*** topics, int count) { mixin(rtLib); }
    int mosquitto_topic_matches_sub(const(char)* sub, const(char)* topic, bool* result) { mixin(rtLib); }
    int mosquitto_pub_topic_check(const(char)* topic) { mixin(rtLib); }
    int mosquitto_sub_topic_check(const(char)* topic) { mixin(rtLib); }
}