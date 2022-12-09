from cffi import FFI
ffi = FFI()

ffi.set_source("_nrm_cffi",
"""
    #include "nrm.h"
""",
    libraries=["nrm"])

ffi.cdef("""
typedef struct nrm_client_s nrm_client_t;

int nrm_client_create(nrm_client_t **client,
                      const char *uri,
                      int pub_port,
                      int rpc_port);
""")

if __name__ == "__main__":
    ffi.compile(verbose=True)
    

