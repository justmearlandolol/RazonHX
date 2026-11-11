use razon_core::{config::{Config, MAX_CONFIG_BYTES}, engine::Engine, ffi::*, themes::valid_color};
use std::{ffi::{CStr, CString}, fs, path::PathBuf, ptr, sync::atomic::{AtomicUsize, Ordering}};

static SEQUENCE: AtomicUsize = AtomicUsize::new(0);
struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        let dir = std::env::temp_dir().join(format!("razon-test-{}-{}", std::process::id(), SEQUENCE.fetch_add(1, Ordering::SeqCst)));
        fs::create_dir_all(&dir).unwrap();
        Self(dir)
    }
    fn path(&self) -> PathBuf { self.0.join("nested/config.json") }
}
impl Drop for Fixture { fn drop(&mut self) { let _ = fs::remove_dir_all(&self.0); } }

#[test]
fn bundled_defaults_are_valid() { Config::default().validate().unwrap(); }
#[test]
fn validates_colors() {
    for color in ["#62F5D0", "#abcdef", "#000000"] { assert!(valid_color(color)); }
    for color in ["62F5D0", "#GGFFFF", "#FFF", "#FFFFFF00", "#ééé"] { assert!(!valid_color(color)); }
}
#[test]
fn creates_persists_and_reopens() {
    let f = Fixture::new();
    let mut engine = Engine::open(f.path()).unwrap();
    let mut config = engine.config().clone();
    config.general.show_settings_on_launch = false;
    config.appearance.accent_color = "#ABCDEF".into();
    engine.update(config.clone()).unwrap();
    drop(engine);
    assert_eq!(Engine::open(f.path()).unwrap().config(), &config);
}
#[test]
fn rejects_relative_path() { assert!(Engine::open(PathBuf::from("config.json")).is_err()); }
#[test]
fn corrupt_file_is_not_overwritten() {
    let f = Fixture::new();
    fs::create_dir_all(f.path().parent().unwrap()).unwrap();
    fs::write(f.path(), b"not json").unwrap();
    assert!(Engine::open(f.path()).is_err());
    assert_eq!(fs::read(f.path()).unwrap(), b"not json");
}
#[test]
fn rejects_newer_schema_and_unknown_fields() {
    let json = razon_core::config::DEFAULT_JSON;
    assert!(Config::parse(&json.replace("\"schema_version\": 1", "\"schema_version\": 2")).is_err());
    assert!(Config::parse(&json.replace("\"general\":", "\"extra\": true, \"general\":")).is_err());
    assert!(Config::parse(&json.replace("\"hide_on_close\": true", "\"hide_on_close\": true, \"extra\": 1")).is_err());
}
#[test]
fn rejects_oversized_config() {
    let f = Fixture::new();
    fs::create_dir_all(f.path().parent().unwrap()).unwrap();
    fs::write(f.path(), vec![b' '; MAX_CONFIG_BYTES as usize + 1]).unwrap();
    assert!(Engine::open(f.path()).is_err());
    assert!(Config::parse(&" ".repeat(MAX_CONFIG_BYTES as usize + 1)).is_err());
}
#[test]
fn invalid_update_does_not_mutate_or_emit() {
    let f = Fixture::new();
    let mut engine = Engine::open(f.path()).unwrap();
    let before = fs::read(f.path()).unwrap();
    let mut invalid = engine.config().clone();
    invalid.appearance.window_opacity = 0.1;
    assert!(engine.update(invalid).is_err());
    assert_eq!(engine.config(), &Config::default());
    assert_eq!(fs::read(f.path()).unwrap(), before);
    assert!(engine.next_event().is_none());
}
#[test]
fn rejects_non_finite_opacity() {
    let mut config = Config::default();
    for n in [f64::NAN, f64::INFINITY, f64::NEG_INFINITY, 1.1, 0.84] {
        config.appearance.window_opacity = n;
        assert!(config.validate().is_err());
    }
}
#[test]
fn failed_write_does_not_change_memory() {
    let f = Fixture::new();
    let mut engine = Engine::open(f.path()).unwrap();
    fs::remove_file(f.path()).unwrap();
    fs::create_dir(f.path()).unwrap(); // rename of a file over this directory must fail
    let mut config = engine.config().clone();
    config.general.hide_on_close = false;
    assert!(engine.update(config).is_err());
    assert_eq!(engine.config(), &Config::default());
    assert!(engine.next_event().is_none());
    assert_eq!(fs::read_dir(f.path().parent().unwrap()).unwrap().count(), 1);
}
#[test]
fn no_op_emits_no_event_and_reset_restores_defaults() {
    let f = Fixture::new();
    let mut engine = Engine::open(f.path()).unwrap();
    engine.update(Config::default()).unwrap();
    assert!(engine.next_event().is_none());
    let mut config = engine.config().clone();
    config.general.hide_on_close = false;
    engine.update(config).unwrap();
    assert!(engine.next_event().is_some());
    engine.reset().unwrap();
    assert_eq!(engine.config(), &Config::default());
    assert!(engine.next_event().is_some());
}
#[test]
fn event_queue_is_bounded() {
    let f = Fixture::new();
    let mut engine = Engine::open(f.path()).unwrap();
    for i in 0..80 {
        let mut config = engine.config().clone();
        config.general.hide_on_close = i % 2 != 0;
        engine.update(config).unwrap();
    }
    let mut count = 0;
    while engine.next_event().is_some() { count += 1; }
    assert_eq!(count, 32);
}
#[test]
fn ffi_ownership_and_error_contract() {
    let f = Fixture::new();
    let path = CString::new(f.path().to_str().unwrap()).unwrap();
    unsafe {
        let mut handle = ptr::null_mut();
        let mut error = ptr::null_mut();
        assert_eq!(rx_engine_create(path.as_ptr(), &mut handle, &mut error), 0);
        assert!(!handle.is_null());
        assert!(error.is_null());
        let mut output = ptr::null_mut();
        assert_eq!(rx_engine_snapshot(handle, &mut output, &mut error), 0);
        Config::parse(CStr::from_ptr(output).to_str().unwrap()).unwrap();
        rx_string_free(output);
        let bad = CString::new("{}").unwrap();
        assert_ne!(rx_engine_update(handle, bad.as_ptr(), &mut error), 0);
        assert!(!error.is_null());
        rx_string_free(error);
        error = ptr::null_mut();
        assert_eq!(rx_engine_next_event(handle, &mut output, &mut error), 0);
        assert!(output.is_null());
        assert_ne!(rx_engine_snapshot(handle, ptr::null_mut(), &mut error), 0);
        rx_string_free(error);
        rx_engine_destroy(handle);
        rx_engine_destroy(ptr::null_mut());
        rx_string_free(ptr::null_mut());
    }
}
#[test]
fn ffi_null_and_invalid_utf8_inputs_fail_safely() {
    unsafe {
        let mut error = ptr::null_mut();
        let mut handle = ptr::null_mut();
        assert_ne!(rx_engine_create(ptr::null(), &mut handle, &mut error), 0);
        assert!(handle.is_null());
        rx_string_free(error);
        let invalid = [0xffu8, 0];
        assert_ne!(rx_engine_create(invalid.as_ptr().cast(), &mut handle, &mut error), 0);
        rx_string_free(error);
        assert_ne!(rx_engine_reset(ptr::null_mut(), &mut error), 0);
        rx_string_free(error);
        assert_ne!(rx_engine_create(ptr::null(), ptr::null_mut(), ptr::null_mut()), 0);
    }
}
