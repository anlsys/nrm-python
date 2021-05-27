import struct
from contextlib import contextmanager
from ctypes import CDLL, POINTER, LibraryLoader, c_char
import msgpack
import logging


class HSO(CDLL):

    exportPattern = "{name}Export"

    def __init__(self, *args, **kwargs):
        return super(HSO, self).__init__(*args, **kwargs)

    def wrap_into_msgpack(self, fun):
        fun.restype = POINTER(c_char)

        def wrapped_fun(*args):
            packed = msgpack.packb(args)
            length_64bits = struct.pack(">q", len(packed))
            ptr = fun(length_64bits + packed)
            data_length = struct.unpack(">q", ptr[:8])[0]
            res = msgpack.unpackb(ptr[8 : 8 + data_length], raw=False, use_list=False)
            self.free(ptr)
            return res

        return wrapped_fun

    def __getattr__(self, name):
        try:
            return super(HSO, self).__getattr__(name)
        except AttributeError as e:
            expName = self.exportPattern.format(name=name)
            try:
                fun = super(HSO, self).__getattr__(expName)
                return self.wrap_into_msgpack(fun)
            except AttributeError:
                raise e


class WrapEither(object):
    def __init__(self, lib):
        self.lib = lib

    def __getattr__(self, name):
        r = self.lib.__getattr__(name)

        def eitherwrap(*args):
            (success, content) = r(*args)
            if success:
                return content
            elif content == "ExitSuccess":
                raise SystemExit
            elif content in ["ExitError", "ExitFailure 1"]:
                raise SystemError
            else:
                raise Exception(".so library call raised exception: %s" % content)

        return eitherwrap


@contextmanager
def Lib(library, exportPattern="{name}Export"):
    """ Loads the haskell shared library """
    hdll = LibraryLoader(HSO)
    hdll.exportPattern = exportPattern
    lib = hdll.LoadLibrary(library)
    lib.hs_init(0, 0)
    try:
        yield WrapEither(lib)
    finally:
        lib.hs_exit()


def UnsafeLib(library, exportPattern="{name}Export"):
    """ Unsafe version of Lib (no exit via context manager) """
    hdll = LibraryLoader(HSO)
    hdll.exportPattern = exportPattern
    lib = hdll.LoadLibrary(library)
    lib.hs_init(0, 0)
    return WrapEither(lib)
