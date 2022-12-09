from _nrm_cffi import ffi,lib

client = ffi.new("nrm_client_t **")
uri = ffi.new("char[]", b"tcp://127.0.0.1")
err = lib.nrm_client_create(client, uri, 2345, 3456)

print(err)