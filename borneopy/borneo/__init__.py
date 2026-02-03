
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

@dataclass
class LyfiInfo:
    nominal_power: int
    channel_count: int
    channels: List[Dict[str, Any]]

@dataclass
class ThermalSettings:
    kp: float
    ki: float
    kd: float
    temp_keep: int
    temp_overheated: int

@dataclass
class ScheduleEntry:
    instant: int
    color: List[int]

from .esptouch import EspTouch
from .lyfi import LyfiCoapClient, LedState
from .device import AbstractBorneoDeviceCoapClient

__all__ = ['EspTouch', 'LyfiCoapClient', 'AbstractBorneoDeviceCoapClient', 'LedState', 'LyfiInfo', 'ThermalSettings', 'ScheduleEntry']
