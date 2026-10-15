"""Store desktop secrets in the native credential service.

Windows uses Credential Manager directly. Linux uses the desktop Secret
Service through ``keyring`` (normally GNOME Keyring or KWallet). Secrets are
never written to HaizFlow's JSON settings files.
"""

from __future__ import annotations

import ctypes
import os
import shutil
import subprocess
from ctypes import wintypes


_CRED_TYPE_GENERIC = 1
_CRED_PERSIST_LOCAL_MACHINE = 2
_ERROR_NOT_FOUND = 1168
_KEYRING_SERVICE = "HaizFlow"


def _secret_tool(arguments: list[str], *, secret: str | None = None) -> subprocess.CompletedProcess[str]:
    executable = shutil.which("secret-tool")
    if not executable:
        raise OSError(
            "Linux secret storage is unavailable. Install libsecret-tools and "
            "start the desktop keyring."
        )
    try:
        return subprocess.run(
            [executable, *arguments],
            input=secret,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
            check=False,
        )
    except subprocess.SubprocessError as exc:
        raise OSError("Could not connect to the Linux Secret Service.") from exc


class _CredentialW(ctypes.Structure):
    _fields_ = (
        ("Flags", wintypes.DWORD),
        ("Type", wintypes.DWORD),
        ("TargetName", wintypes.LPWSTR),
        ("Comment", wintypes.LPWSTR),
        ("LastWritten", wintypes.FILETIME),
        ("CredentialBlobSize", wintypes.DWORD),
        ("CredentialBlob", ctypes.POINTER(ctypes.c_ubyte)),
        ("Persist", wintypes.DWORD),
        ("AttributeCount", wintypes.DWORD),
        ("Attributes", ctypes.c_void_p),
        ("TargetAlias", wintypes.LPWSTR),
        ("UserName", wintypes.LPWSTR),
    )


def _advapi32():
    if os.name != "nt":
        raise OSError("Windows Credential Manager is unavailable on this platform.")
    library = ctypes.WinDLL("Advapi32.dll", use_last_error=True)
    library.CredWriteW.argtypes = (ctypes.POINTER(_CredentialW), wintypes.DWORD)
    library.CredWriteW.restype = wintypes.BOOL
    library.CredReadW.argtypes = (
        wintypes.LPCWSTR,
        wintypes.DWORD,
        wintypes.DWORD,
        ctypes.POINTER(ctypes.POINTER(_CredentialW)),
    )
    library.CredReadW.restype = wintypes.BOOL
    library.CredDeleteW.argtypes = (wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD)
    library.CredDeleteW.restype = wintypes.BOOL
    library.CredFree.argtypes = (ctypes.c_void_p,)
    library.CredFree.restype = None
    return library


def write_secret(target: str, secret: str, *, username: str = "HaizFlow") -> None:
    target_name = str(target or "").strip()
    value = str(secret or "")
    if not target_name or not value:
        raise ValueError("Credential target and secret are required.")
    if os.name != "nt":
        result = _secret_tool(
            ["store", "--label", str(username or _KEYRING_SERVICE), "application", _KEYRING_SERVICE, "target", target_name],
            secret=value,
        )
        if result.returncode != 0:
            raise OSError("Could not save the secret in the Linux Secret Service.")
        return
    encoded = value.encode("utf-16-le")
    blob = (ctypes.c_ubyte * len(encoded)).from_buffer_copy(encoded)
    credential = _CredentialW()
    credential.Type = _CRED_TYPE_GENERIC
    credential.TargetName = target_name
    credential.CredentialBlobSize = len(encoded)
    credential.CredentialBlob = ctypes.cast(blob, ctypes.POINTER(ctypes.c_ubyte))
    credential.Persist = _CRED_PERSIST_LOCAL_MACHINE
    credential.UserName = str(username or "HaizFlow")
    library = _advapi32()
    if not library.CredWriteW(ctypes.byref(credential), 0):
        raise ctypes.WinError(ctypes.get_last_error())


def read_secret(target: str) -> str:
    target_name = str(target or "").strip()
    if not target_name:
        return ""
    if os.name != "nt":
        result = _secret_tool(["lookup", "application", _KEYRING_SERVICE, "target", target_name])
        if result.returncode not in {0, 1}:
            raise OSError("Could not read the secret from the Linux Secret Service.")
        return result.stdout.rstrip("\r\n") if result.returncode == 0 else ""
    library = _advapi32()
    pointer = ctypes.POINTER(_CredentialW)()
    if not library.CredReadW(target_name, _CRED_TYPE_GENERIC, 0, ctypes.byref(pointer)):
        error = ctypes.get_last_error()
        if error == _ERROR_NOT_FOUND:
            return ""
        raise ctypes.WinError(error)
    try:
        size = int(pointer.contents.CredentialBlobSize)
        if not size or not pointer.contents.CredentialBlob:
            return ""
        return ctypes.string_at(pointer.contents.CredentialBlob, size).decode("utf-16-le")
    finally:
        library.CredFree(pointer)


def delete_secret(target: str) -> bool:
    target_name = str(target or "").strip()
    if not target_name:
        return False
    if os.name != "nt":
        if not read_secret(target_name):
            return False
        result = _secret_tool(["clear", "application", _KEYRING_SERVICE, "target", target_name])
        if result.returncode != 0:
            raise OSError("Could not delete the secret from the Linux Secret Service.")
        return True
    library = _advapi32()
    if library.CredDeleteW(target_name, _CRED_TYPE_GENERIC, 0):
        return True
    error = ctypes.get_last_error()
    if error == _ERROR_NOT_FOUND:
        return False
    raise ctypes.WinError(error)
