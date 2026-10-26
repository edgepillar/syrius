"""An owned Windows process tree for the manual debug-loop qualification.

A new Python child waits for START before it launches the Flutter tool. Assigning
that gated child to a private job prevents an application launch before ownership
is established. Closing the job is forced cleanup, never a successful app exit.
"""

import ctypes
from ctypes import wintypes
import os
from pathlib import Path


class ProcessRefused(Exception):
    pass


class _Basic(ctypes.Structure):
    _fields_ = [("process_time", ctypes.c_longlong), ("job_time", ctypes.c_longlong),
                ("flags", wintypes.DWORD), ("min_working", ctypes.c_size_t),
                ("max_working", ctypes.c_size_t), ("active_limit", wintypes.DWORD),
                ("affinity", ctypes.c_size_t), ("priority", wintypes.DWORD),
                ("scheduling", wintypes.DWORD)]


class _Io(ctypes.Structure):
    _fields_ = [(name, ctypes.c_ulonglong) for name in
                ("read_ops", "write_ops", "other_ops", "read_bytes", "write_bytes", "other_bytes")]


class _Extended(ctypes.Structure):
    _fields_ = [("basic", _Basic), ("io", _Io), ("process_memory", ctypes.c_size_t),
                ("job_memory", ctypes.c_size_t), ("peak_process", ctypes.c_size_t),
                ("peak_job", ctypes.c_size_t)]


class _Accounting(ctypes.Structure):
    _fields_ = [(name, ctypes.c_longlong) for name in
                ("user", "kernel", "period_user", "period_kernel")] + [
                (name, wintypes.DWORD) for name in
                ("faults", "total", "active", "terminated")]


class WindowsJob:
    def __init__(self):
        if os.name != "nt":
            raise ProcessRefused("PLATFORM_REFUSED")
        if (ctypes.sizeof(ctypes.c_void_p) != 8 or ctypes.sizeof(_Extended) != 144
                or ctypes.sizeof(_Accounting) != 48):
            raise ProcessRefused("PLATFORM_REFUSED")
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        declarations = {
            "CreateJobObjectW": ([ctypes.c_void_p, wintypes.LPCWSTR], wintypes.HANDLE),
            "SetInformationJobObject": ([wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p,
                                           wintypes.DWORD], wintypes.BOOL),
            "AssignProcessToJobObject": ([wintypes.HANDLE, wintypes.HANDLE], wintypes.BOOL),
            "QueryInformationJobObject": ([wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p,
                                             wintypes.DWORD, ctypes.c_void_p], wintypes.BOOL),
            "IsProcessInJob": ([wintypes.HANDLE, wintypes.HANDLE,
                                 ctypes.POINTER(wintypes.BOOL)], wintypes.BOOL),
            "OpenProcess": ([wintypes.DWORD, wintypes.BOOL, wintypes.DWORD], wintypes.HANDLE),
            "QueryFullProcessImageNameW": ([wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR,
                                              ctypes.POINTER(wintypes.DWORD)], wintypes.BOOL),
            "GetExitCodeProcess": ([wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)], wintypes.BOOL),
            "WaitForSingleObject": ([wintypes.HANDLE, wintypes.DWORD], wintypes.DWORD),
            "CloseHandle": ([wintypes.HANDLE], wintypes.BOOL),
        }
        for name, (arguments, result) in declarations.items():
            function = getattr(kernel, name)
            function.argtypes, function.restype = arguments, result
        self.kernel, self.handle, self.application = kernel, None, None
        self.forced = False
        self.active_at_close = None
        self.handle = kernel.CreateJobObjectW(None, None)
        if not self.handle:
            raise ProcessRefused("JOB_REFUSED")
        limits = _Extended()
        limits.basic.flags = 0x00002000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if not kernel.SetInformationJobObject(self.handle, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            kernel.CloseHandle(self.handle)
            self.handle = None
            raise ProcessRefused("JOB_REFUSED")

    def assign(self, original):
        if self.handle is None or original.poll() is not None:
            raise ProcessRefused("JOB_REFUSED")
        if not self.kernel.AssignProcessToJobObject(self.handle, wintypes.HANDLE(int(original._handle))):
            raise ProcessRefused("JOB_REFUSED")

    def bind_application(self, pid, expected):
        if self.application is not None or type(pid) is not int or not 0 < pid < 0x100000000:
            raise ProcessRefused("PROCESS_REFUSED")
        handle = self.kernel.OpenProcess(0x1000 | 0x100000, False, pid)
        if not handle:
            raise ProcessRefused("PROCESS_REFUSED")
        try:
            member = wintypes.BOOL()
            if not self.kernel.IsProcessInJob(handle, self.handle, ctypes.byref(member)) or not member.value:
                raise ProcessRefused("PROCESS_REFUSED")
            size = wintypes.DWORD(32768)
            image = ctypes.create_unicode_buffer(size.value)
            if not self.kernel.QueryFullProcessImageNameW(handle, 0, image, ctypes.byref(size)):
                raise ProcessRefused("PROCESS_REFUSED")
            if os.path.normcase(str(Path(image.value).resolve())) != os.path.normcase(str(expected.resolve())):
                raise ProcessRefused("PROCESS_REFUSED")
            if self.kernel.WaitForSingleObject(handle, 0) != 0x102:
                raise ProcessRefused("PROCESS_REFUSED")
            self.application = handle
        finally:
            if self.application != handle:
                self.kernel.CloseHandle(handle)

    def application_exit(self, milliseconds=10000):
        if self.application is None or self.kernel.WaitForSingleObject(self.application, milliseconds) != 0:
            raise ProcessRefused("APPLICATION_EXIT_UNCONFIRMED")
        code = wintypes.DWORD()
        if not self.kernel.GetExitCodeProcess(self.application, ctypes.byref(code)):
            raise ProcessRefused("APPLICATION_EXIT_UNCONFIRMED")
        return code.value

    def active(self):
        if self.handle is None:
            raise ProcessRefused("JOB_REFUSED")
        value = _Accounting()
        if not self.kernel.QueryInformationJobObject(self.handle, 1, ctypes.byref(value), ctypes.sizeof(value), None):
            raise ProcessRefused("JOB_REFUSED")
        return value.active

    def close(self):
        if self.handle is not None:
            try:
                self.active_at_close = self.active()
                self.forced = self.forced or self.active_at_close != 0
            except ProcessRefused:
                self.forced = True
            self.kernel.CloseHandle(self.handle)
            self.handle = None
        if self.application is not None:
            self.kernel.CloseHandle(self.application)
            self.application = None
