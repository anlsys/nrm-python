from ctypes.util import find_library
from ctypes import CDLL

libnrm = CDLL(find_library("nrm"))