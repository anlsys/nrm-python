from cffi import FFI
import subprocess

ffi = FFI()

ffi.set_source(
    "nrm.api._build._nrm_cffi",
    """
    #include "nrm.h"
    """,
    libraries=["nrm"],
)

nrmh = subprocess.Popen(["locate", "nrm.h"], stdout=subprocess.PIPE).communicate()[0].decode().split("\n")[0]

cdef_base = \
"""

typedef int... time_t;

typedef struct timespec{
    time_t tv_sec;
    long tv_nsec;
};

typedef struct timespec nrm_time_t;

nrm_time_t nrm_time_fromns(int64_t ns);
typedef char *nrm_string_t;
typedef nrm_string_t nrm_uuid_t;
typedef struct nrm_vector_s nrm_vector_t;
typedef struct nrm_scope nrm_scope_t;

extern "Python" int _event_listener_wrap(nrm_string_t sensor_uuid,
                                         nrm_time_t time,
                                         nrm_scope_t *scope,
                                         double value,
                                         void *arg);

extern "Python" int _actuate_listener_wrap(nrm_uuid_t *uuid,
                                           double value,
                                           void *arg);

nrm_string_t nrm_string_fromchar(const char *buf);

void nrm_time_gettime(nrm_time_t *now);

int nrm_scope_destroy(nrm_scope_t *scope);

"""

with open(nrmh, "r") as f:
    lines = f.readlines()

for line in lines:
    cdef_base += line

ffi.cdef(cdef_base)

if __name__ == "__main__":
    ffi.compile(verbose=True)
