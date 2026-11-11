//! Single-thread-affine C ABI. All input pointers must be valid for the call.
//! Returned strings are owned by Rust and must be released with rx_string_free.
use std::{ffi::{CStr, CString}, os::raw::c_char, panic::{catch_unwind, AssertUnwindSafe}, path::PathBuf, ptr};
use crate::engine::Engine;

fn c_string(value: String) -> *mut c_char {
    // Error text can contain user-supplied paths. Do not panic on embedded NULs.
    CString::new(value.replace('\0', "�")).expect("NUL removed").into_raw()
}
unsafe fn text<'a>(value: *const c_char) -> Result<&'a str, String> {
    if value.is_null() { return Err("Null string argument.".into()); }
    CStr::from_ptr(value).to_str().map_err(|_| "Input is not UTF-8.".into())
}
unsafe fn engine<'a>(value: *mut Engine) -> Result<&'a mut Engine, String> {
    value.as_mut().ok_or_else(|| "Null engine handle.".into())
}
unsafe fn run(error: *mut *mut c_char, body: impl FnOnce() -> Result<(), String>) -> i32 {
    if !error.is_null() { *error = ptr::null_mut(); }
    let result = catch_unwind(AssertUnwindSafe(body)).unwrap_or_else(|_| Err("Internal engine panic.".into()));
    match result {
        Ok(()) => 0,
        Err(message) => { if !error.is_null() { *error = c_string(message); } 1 }
    }
}

/// # Safety
/// Pointers must obey the ownership, lifetime and thread rules in RazonHXBridge.h.
#[no_mangle]
pub unsafe extern "C" fn rx_engine_create(path: *const c_char, output: *mut *mut Engine, error: *mut *mut c_char) -> i32 {
    if !output.is_null() { *output = ptr::null_mut(); }
    run(error, || {
        if output.is_null() { return Err("Missing output handle.".into()); }
        let value = Engine::open(PathBuf::from(text(path)?))?;
        *output = Box::into_raw(Box::new(value));
        Ok(())
    })
}
/// # Safety
/// Pointers must obey the ownership, lifetime and thread rules in RazonHXBridge.h.
#[no_mangle]
pub unsafe extern "C" fn rx_engine_destroy(handle: *mut Engine) {
    if !handle.is_null() { drop(Box::from_raw(handle)); }
}
/// # Safety
/// Pointers must obey the ownership, lifetime and thread rules in RazonHXBridge.h.
#[no_mangle]
pub unsafe extern "C" fn rx_engine_snapshot(handle: *mut Engine, output: *mut *mut c_char, error: *mut *mut c_char) -> i32 {
    if !output.is_null() { *output = ptr::null_mut(); }
    run(error, || {
        if output.is_null() { return Err("Missing output string.".into()); }
        *output = c_string(engine(handle)?.snapshot()?);
        Ok(())
    })
}
/// # Safety
/// Pointers must obey the ownership, lifetime and thread rules in RazonHXBridge.h.
#[no_mangle]
pub unsafe extern "C" fn rx_engine_update(handle: *mut Engine, json: *const c_char, error: *mut *mut c_char) -> i32 {
    run(error, || engine(handle)?.update_json(text(json)?))
}
/// # Safety
/// Pointers must obey the ownership, lifetime and thread rules in RazonHXBridge.h.
#[no_mangle]
pub unsafe extern "C" fn rx_engine_reset(handle: *mut Engine, error: *mut *mut c_char) -> i32 {
    run(error, || engine(handle)?.reset())
}
/// # Safety
/// Pointers must obey the ownership, lifetime and thread rules in RazonHXBridge.h.
#[no_mangle]
pub unsafe extern "C" fn rx_engine_next_event(handle: *mut Engine, output: *mut *mut c_char, error: *mut *mut c_char) -> i32 {
    if !output.is_null() { *output = ptr::null_mut(); }
    run(error, || {
        if output.is_null() { return Err("Missing output string.".into()); }
        if let Some(event) = engine(handle)?.next_event() {
            *output = c_string(serde_json::to_string(&event).map_err(|e| e.to_string())?);
        }
        Ok(())
    })
}
/// # Safety
/// Pointers must obey the ownership, lifetime and thread rules in RazonHXBridge.h.
#[no_mangle]
pub unsafe extern "C" fn rx_string_free(value: *mut c_char) {
    if !value.is_null() { drop(CString::from_raw(value)); }
}
