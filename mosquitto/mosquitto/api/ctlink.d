module mosquitto.api.ctlink;

import mosquitto.api.types;

version (ctlink):
extern (C):

int mosquitto_lib_version(int* major, int* minor, int* revision);
int mosquitto_lib_init();
int mosquitto_lib_cleanup();
mosquitto_t mosquitto_new(const(char)* id, bool clean_session, void* obj);
void mosquitto_destroy(mosquitto_t mosq);
int mosquitto_reinitialise(mosquitto_t mosq, const(char)* id, bool clean_session, void* obj);
int mosquitto_will_set(mosquitto_t mosq, const(char)* topic, int payloadlen, const(void)* payload, int qos, bool retain);
int mosquitto_will_clear(mosquitto_t mosq);
int mosquitto_username_pw_set(mosquitto_t mosq, const(char)* username, const(char)* password);
int mosquitto_connect(mosquitto_t mosq, const(char)* host, int port, int keepalive);
int mosquitto_connect_bind(mosquitto_t mosq, const(char)* host, int port, int keepalive, const(char)* bind_address);
int mosquitto_connect_async(mosquitto_t mosq, const(char)* host, int port, int keepalive);
int mosquitto_connect_bind_async(mosquitto_t mosq, const(char)* host, int port, int keepalive, const(char)* bind_address);
int mosquitto_connect_srv(mosquitto_t mosq, const(char)* host, int keepalive, const(char)* bind_address);
int mosquitto_reconnect(mosquitto_t mosq);
int mosquitto_reconnect_async(mosquitto_t mosq);
int mosquitto_disconnect(mosquitto_t mosq);
int mosquitto_publish(mosquitto_t mosq, int* mid, const(char)* topic, int payloadlen, const(void)* payload, int qos, bool retain);
int mosquitto_subscribe(mosquitto_t mosq, int* mid, const(char)* sub, int qos);
int mosquitto_unsubscribe(mosquitto_t mosq, int* mid, const(char)* sub);
int mosquitto_message_copy(mosquitto_message* dst, const mosquitto_message* src);
void mosquitto_message_free(mosquitto_message** message);
int mosquitto_loop(mosquitto_t mosq, int timeout, int max_packets);
int mosquitto_loop_forever(mosquitto_t mosq, int timeout, int max_packets);
int mosquitto_loop_start(mosquitto_t mosq);
int mosquitto_loop_stop(mosquitto_t mosq, bool force);
int mosquitto_socket(mosquitto_t mosq);
int mosquitto_loop_read(mosquitto_t mosq, int max_packets);
int mosquitto_loop_write(mosquitto_t mosq, int max_packets);
int mosquitto_loop_misc(mosquitto_t mosq);
bool mosquitto_want_write(mosquitto_t mosq);
int mosquitto_threaded_set(mosquitto_t mosq, bool threaded);
int mosquitto_opts_set(mosquitto_t mosq, MOSQ_OPT option, void* value);
int mosquitto_tls_set(mosquitto_t mosq,
                        const(char)* cafile,   const(char)* capath,
                        const(char)* certfile, const(char)* keyfile,
                        int function(char* buf, int size, int rwflag, void* userdata) pw_callback);
int mosquitto_tls_insecure_set(mosquitto_t mosq, bool value);
int mosquitto_tls_opts_set(mosquitto_t mosq, int cert_reqs, const(char)* tls_version, const(char)* ciphers);
int mosquitto_tls_psk_set(mosquitto_t mosq, const(char)* psk, const(char)* identity,  const(char)* ciphers);

alias mosq_base_callback = void function(mosquitto_t, void*, int);

void mosquitto_connect_callback_set(mosquitto_t mosq, mosq_base_callback on_connect);
void mosquitto_disconnect_callback_set(mosquitto_t mosq, mosq_base_callback on_disconnect);
void mosquitto_publish_callback_set(mosquitto_t mosq, mosq_base_callback on_publish);
void mosquitto_message_callback_set(mosquitto_t mosq, void function(mosquitto_t, void*, const mosquitto_message*) on_message);
void mosquitto_subscribe_callback_set(mosquitto_t mosq, void function(mosquitto_t, void*, int, int, const int*)on_subscribe);
void mosquitto_unsubscribe_callback_set(mosquitto_t mosq, mosq_base_callback on_unsubscribe);
void mosquitto_log_callback_set(mosquitto_t mosq, void function(mosquitto_t, void*, int, const(char)*) on_log);
int mosquitto_reconnect_delay_set(mosquitto_t mosq, uint reconnect_delay, uint reconnect_delay_max,
                                    bool reconnect_exponential_backoff);
int mosquitto_max_inflight_messages_set(mosquitto_t mosq, uint max_inflight_messages);
void mosquitto_message_retry_set(mosquitto_t mosq, uint message_retry);
void mosquitto_user_data_set(mosquitto_t mosq, void* obj);

int mosquitto_socks5_set(mosquitto_t mosq, const(char)* host, int port, const(char)* username, const(char)* password);

const(char)* mosquitto_strerror(int mosq_errno);
const(char)* mosquitto_connack_string(int connack_code);
int mosquitto_sub_topic_tokenise(const(char)* subtopic, char*** topics, int* count);
int mosquitto_sub_topic_tokens_free(char*** topics, int count);
int mosquitto_topic_matches_sub(const(char)* sub, const(char)* topic, bool* result);
int mosquitto_pub_topic_check(const(char)* topic);
int mosquitto_sub_topic_check(const(char)* topic);