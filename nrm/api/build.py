from cffi import FFI
import subprocess
import os

ffi = FFI()

ffi.set_source(
    "nrm.api._build._nrm_cffi",
    """
    #include "nrm.h"
    """,
    libraries=["nrm"],
)

def my_temporary_header_locator():
    return subprocess.Popen(["find", "../libnrm", "-name", "nrm.h"], stdout=subprocess.PIPE).communicate()[0].decode().split("\n")[0]

nrmh = my_temporary_header_locator()

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

avoid_tokens = ["#", "extern \"C\" {", "	nrm_log_printf("]
avoid_block = [
"\tdo {                                                                   \\\n",
"\t\tchar *__nrm_errstr = strerror(errno);                          \\\n",
"\t\tnrm_log_printf(NRM_LOG_ERROR, __FILE__, __LINE__,              \\\n",
"\t\t               __VA_ARGS__);                                   \\\n",
"\t\tnrm_log_printf(NRM_LOG_ERROR, __FILE__, __LINE__,              \\\n",
"\t\t               \"perror: %s\\n\", __nrm_errstr);                  \\\n",
"\t} while (0)\n",
]

for line in lines:
    if not any([line.startswith(token) for token in avoid_tokens]) and line not in avoid_block:
        cdef_base += line


ffi.cdef(cdef_base)

if __name__ == "__main__":
    ffi.compile(verbose=True)
