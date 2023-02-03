from cffi import FFI

ffi = FFI()

ffi.set_source(
    "_build._nrm_cffi",
    """
    #include "nrm.h"
    """,
    libraries=["nrm"],
)

ffi.cdef(
    """

typedef int... time_t;

typedef struct timespec{
    time_t tv_sec;
    long tv_nsec;
    ...;
};

typedef struct nrm_client_s nrm_client_t;
typedef struct nrm_actuator_s nrm_actuator_t;
typedef struct nrm_slice_s nrm_slice_t;
typedef struct nrm_sensor_s nrm_sensor_t;
typedef struct nrm_scope nrm_scope_t;
typedef struct nrm_vector_s nrm_vector_t;
typedef char *nrm_string_t;
typedef struct timespec nrm_time_t;
typedef nrm_string_t nrm_uuid_t;

typedef int(nrm_client_event_listener_fn)(nrm_string_t sensor_uuid,
                                          nrm_time_t time,
                                          nrm_scope_t *scope,
                                          double value);
typedef int(nrm_client_actuate_listener_fn)(nrm_uuid_t *uuid, double value);

nrm_time_t nrm_time_fromns(int64_t ns);

// PY STUFF

extern "Python" int _event_listener_wrap(void *pyclient,
                                         nrm_string_t sensor_uuid,
                                         nrm_scope_t *scope,
                                         double value);

extern "Python" int _actuate_listener_wrap(void *pyclient,
                                           nrm_uuid_t uuid,
                                           double value);

int nrm_client_set_event_Pylistener(nrm_client_t *client,
                                    void *pyclient,
                                    nrm_client_event_listener_fn *fn);

int nrm_client_set_actuate_Pylistener(nrm_client_t *client,
                                      void *pyclient,
                                      nrm_client_actuate_listener_fn *fn);

int nrm_client_start_event_Pylistener(const nrm_client_t *client,
                                      nrm_string_t topic);

int nrm_client_start_actuate_Pylistener(const nrm_client_t *client);

// END PY STUFF

int nrm_init(int *argc, char **argv[]);

nrm_string_t nrm_string_fromchar(const char *buf);

void nrm_time_gettime(nrm_time_t *now);

nrm_actuator_t *nrm_actuator_create(const char *name);

nrm_scope_t *nrm_scope_create(const char *name);

nrm_sensor_t *nrm_sensor_create(const char *name);

nrm_slice_t *nrm_slice_create(const char *name);

int nrm_client_create(nrm_client_t **client,
                      const char *uri,
                      int pub_port,
                      int rpc_port);

int nrm_client_actuate(const nrm_client_t *client,
                       nrm_actuator_t *actuator,
                       double value);

int nrm_client_add_actuator(const nrm_client_t *client,
                            nrm_actuator_t *actuator);

int nrm_client_add_scope(const nrm_client_t *client, nrm_scope_t *scope);

int nrm_client_add_sensor(const nrm_client_t *client, nrm_sensor_t *sensor);

int nrm_client_add_slice(const nrm_client_t *client, nrm_slice_t *slice);

int nrm_client_find(const nrm_client_t *client,
                    int type,
                    const char *uuid,
                    nrm_vector_t **results);

int nrm_client_remove(const nrm_client_t *client, int type, nrm_string_t uuid);

int nrm_client_send_event(const nrm_client_t *client,
                          nrm_time_t time,
                          nrm_sensor_t *sensor,
                          nrm_scope_t *scope,
                          double value);

int nrm_client_set_event_listener(nrm_client_t *client,
                                  nrm_client_event_listener_fn fn);

int nrm_client_start_event_listener(const nrm_client_t *client,
                                    nrm_string_t topic);

int nrm_client_set_actuate_listener(nrm_client_t *client,
                                    nrm_client_actuate_listener_fn fn);

int nrm_client_start_actuate_listener(const nrm_client_t *client);

void nrm_client_destroy(nrm_client_t **client);

"""
)

if __name__ == "__main__":
    ffi.compile(verbose=True)
