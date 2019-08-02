# (generated with --quick)

import collections
from typing import Callable, Dict, Iterable, Optional, Sized, Tuple, Type, TypeVar, Union

Failure: Return
Success: Return

_TMachineInfo = TypeVar('_TMachineInfo', bound=MachineInfo)
_TRAPLConfig = TypeVar('_TRAPLConfig', bound=RAPLConfig)
_TRAPLPackageConfig = TypeVar('_TRAPLPackageConfig', bound=RAPLPackageConfig)
_TTemperatureSamples = TypeVar('_TTemperatureSamples', bound=TemperatureSamples)

class CoreID(int):
    def __init__(self, val: int) -> None: ...

class EnergySamples(Dict[PkgID, MicroJoules]):
    def __init__(self, val: Dict[PkgID, MicroJoules]) -> None: ...

class FreqControl(Dict[CoreID, Hz]):
    def __init__(self, val: Dict[CoreID, Hz]) -> None: ...

class Hz(int):
    def __init__(self, val: int) -> None: ...

class MachineInfo(tuple):
    __slots__ = ["energySamples", "tempSamples", "time", "time_last"]
    __dict__: collections.OrderedDict[str, Optional[Union[EnergySamples, TemperatureSamples, Time]]]
    _field_defaults: collections.OrderedDict[str, Optional[Union[EnergySamples, TemperatureSamples, Time]]]
    _field_types: collections.OrderedDict[str, type]
    _fields: Tuple[str, str, str, str]
    energySamples: Optional[EnergySamples]
    tempSamples: TemperatureSamples
    time: Time
    time_last: Time
    def __getnewargs__(self) -> Tuple[Time, Time, Optional[EnergySamples], TemperatureSamples]: ...
    def __getstate__(self) -> None: ...
    def __init__(self, *args, **kwargs) -> None: ...
    def __new__(cls: Type[_TMachineInfo], time_last: Time, time: Time, energySamples: Optional[EnergySamples], tempSamples: TemperatureSamples) -> _TMachineInfo: ...
    def _asdict(self) -> collections.OrderedDict[str, Optional[Union[EnergySamples, TemperatureSamples, Time]]]: ...
    @classmethod
    def _make(cls: Type[_TMachineInfo], iterable: Iterable[Optional[Union[EnergySamples, TemperatureSamples, Time]]], new = ..., len: Callable[[Sized], int] = ...) -> _TMachineInfo: ...
    def _replace(self: _TMachineInfo, **kwds: Optional[Union[EnergySamples, TemperatureSamples, Time]]) -> _TMachineInfo: ...

class MicroJoules(int):
    def __init__(self, val: int) -> None: ...

class MicroWatts(int):
    def __init__(self, val: int) -> None: ...

class PcapControl(Dict[PkgID, MicroWatts]):
    def __init__(self, val: Dict[PkgID, MicroWatts]) -> None: ...

class PkgID(int):
    def __init__(self, val: int) -> None: ...

class RAPLConfig(tuple):
    __slots__ = ["packageConfig"]
    __dict__: collections.OrderedDict[str, Dict[PkgID, RAPLPackageConfig]]
    _field_defaults: collections.OrderedDict[str, Dict[PkgID, RAPLPackageConfig]]
    _field_types: collections.OrderedDict[str, type]
    _fields: Tuple[str]
    packageConfig: Dict[PkgID, RAPLPackageConfig]
    def __getnewargs__(self) -> Tuple[Dict[PkgID, RAPLPackageConfig]]: ...
    def __getstate__(self) -> None: ...
    def __init__(self, *args, **kwargs) -> None: ...
    def __new__(cls: Type[_TRAPLConfig], packageConfig: Dict[PkgID, RAPLPackageConfig]) -> _TRAPLConfig: ...
    def _asdict(self) -> collections.OrderedDict[str, Dict[PkgID, RAPLPackageConfig]]: ...
    @classmethod
    def _make(cls: Type[_TRAPLConfig], iterable: Iterable[Dict[PkgID, RAPLPackageConfig]], new = ..., len: Callable[[Sized], int] = ...) -> _TRAPLConfig: ...
    def _replace(self: _TRAPLConfig, **kwds: Dict[PkgID, RAPLPackageConfig]) -> _TRAPLConfig: ...

class RAPLPackageConfig(tuple):
    __slots__ = ["constraint_0_max_power_uw", "constraint_0_name", "constraint_0_time_window_us", "constraint_1_max_power_uw", "constraint_1_name", "constraint_1_time_window_us", "enabled"]
    __dict__: collections.OrderedDict[str, Union[int, str]]
    _field_defaults: collections.OrderedDict[str, Union[int, str]]
    _field_types: collections.OrderedDict[str, type]
    _fields: Tuple[str, str, str, str, str, str, str]
    constraint_0_max_power_uw: MicroWatts
    constraint_0_name: str
    constraint_0_time_window_us: int
    constraint_1_max_power_uw: MicroWatts
    constraint_1_name: str
    constraint_1_time_window_us: int
    enabled: bool
    def __getnewargs__(self) -> Tuple[bool, MicroWatts, str, int, MicroWatts, str, int]: ...
    def __getstate__(self) -> None: ...
    def __init__(self, *args, **kwargs) -> None: ...
    def __new__(cls: Type[_TRAPLPackageConfig], enabled: bool, constraint_0_max_power_uw: MicroWatts, constraint_0_name: str, constraint_0_time_window_us: int, constraint_1_max_power_uw: MicroWatts, constraint_1_name: str, constraint_1_time_window_us: int) -> _TRAPLPackageConfig: ...
    def _asdict(self) -> collections.OrderedDict[str, Union[int, str]]: ...
    @classmethod
    def _make(cls: Type[_TRAPLPackageConfig], iterable: Iterable[Optional[Union[int, str]]], new = ..., len: Callable[[Sized], int] = ...) -> _TRAPLPackageConfig: ...
    def _replace(self: _TRAPLPackageConfig, **kwds: Optional[Union[int, str]]) -> _TRAPLPackageConfig: ...

class Return(bool):
    def __init__(self, val: bool) -> None: ...

class Temperature(float):
    def __init__(self, val: float) -> None: ...

class TemperatureSamples(tuple):
    __slots__ = ["core_t_celcius", "pkg_t_celcius"]
    __dict__: collections.OrderedDict[str, Dict[Union[CoreID, PkgID], Temperature]]
    _field_defaults: collections.OrderedDict[str, Dict[Union[CoreID, PkgID], Temperature]]
    _field_types: collections.OrderedDict[str, type]
    _fields: Tuple[str, str]
    core_t_celcius: Dict[CoreID, Temperature]
    pkg_t_celcius: Dict[PkgID, Temperature]
    def __getnewargs__(self) -> Tuple[Dict[CoreID, Temperature], Dict[PkgID, Temperature]]: ...
    def __getstate__(self) -> None: ...
    def __init__(self, *args, **kwargs) -> None: ...
    def __new__(cls: Type[_TTemperatureSamples], core_t_celcius: Dict[CoreID, Temperature], pkg_t_celcius: Dict[PkgID, Temperature]) -> _TTemperatureSamples: ...
    def _asdict(self) -> collections.OrderedDict[str, Dict[Union[CoreID, PkgID], Temperature]]: ...
    @classmethod
    def _make(cls: Type[_TTemperatureSamples], iterable: Iterable[Dict[Union[CoreID, PkgID], Temperature]], new = ..., len: Callable[[Sized], int] = ...) -> _TTemperatureSamples: ...
    def _replace(self: _TTemperatureSamples, **kwds: Dict[Union[CoreID, PkgID], Temperature]) -> _TTemperatureSamples: ...

class Time(float):
    def __init__(self, val: float) -> None: ...

class _PUID(int):
    def __init__(self, val: int) -> None: ...

def coreid(s: str) -> CoreID: ...
def pkgid(s: str) -> PkgID: ...
def puid(s: str) -> _PUID: ...
