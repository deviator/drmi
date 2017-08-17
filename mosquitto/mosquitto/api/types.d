module mosquitto.api.types;

enum MOSQ_ERR 
{
    CONN_PENDING = -1,
    SUCCESS = 0,
    NOMEM = 1,
    PROTOCOL = 2,
    INVAL = 3,
    NO_CONN = 4,
    CONN_REFUSED = 5,
    NOT_FOUND = 6,
    CONN_LOST = 7,
    TLS = 8,
    PAYLOAD_SIZE = 9,
    NOT_SUPPORTED = 10,
    AUTH = 11,
    ACL_DENIED = 12,
    UNKNOWN = 13,
    ERRNO = 14,
    EAI = 15,
    PROXY = 16
}

enum MOSQ_OPT
{
    PROTOCOL_VERSION = 1,
}

struct mosquitto_message
{
    int mid;
    char* topic;
    void* payload;
    int payloadlen;
    int qos;
    bool retain;
}

alias mosquitto_t = void*;