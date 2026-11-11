//! Bounded reads and atomic persistence. Never silently replace a corrupt config.
use std::{fs::{self, File, OpenOptions}, io::{Read, Write}, path::Path};
use crate::config::MAX_CONFIG_BYTES;

pub fn read_config(path: &Path) -> Result<Option<String>, String> {
    let file = match File::open(path) {
        Ok(file) => file,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => return Err(format!("Cannot open {}: {e}", path.display())),
    };
    let mut content = String::new();
    file.take(MAX_CONFIG_BYTES + 1).read_to_string(&mut content)
        .map_err(|e| format!("Cannot read configuration: {e}"))?;
    if content.len() as u64 > MAX_CONFIG_BYTES {
        return Err("Configuration exceeds the 64 KiB limit.".into());
    }
    Ok(Some(content))
}

pub fn atomic_write(path: &Path, content: &[u8]) -> Result<(), String> {
    let parent = path.parent().filter(|p| !p.as_os_str().is_empty())
        .ok_or("Configuration must have a parent directory.")?;
    fs::create_dir_all(parent).map_err(|e| format!("Cannot create configuration directory: {e}"))?;
    // create_new prevents symlink following and clobbering an existing temporary file.
    let name = path.file_name().ok_or("Missing configuration filename.")?.to_string_lossy();
    let mut pending = None;
    for n in 0..100 {
        let tmp = parent.join(format!(".{name}.{}.{}.tmp", std::process::id(), n));
        let mut options = OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)] {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        match options.open(&tmp) {
            Ok(file) => { pending = Some((tmp, file)); break; }
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(format!("Cannot save configuration: {e}")),
        }
    }
    let (tmp, mut file) = pending.ok_or("Too many pending configuration files.")?;
    let result = (|| {
        file.write_all(content)?;
        file.sync_all()?;
        fs::rename(&tmp, path)?;
        // Directory fsync is best-effort: a committed rename must not be reported as rolled back.
        if let Ok(dir) = File::open(parent) { let _ = dir.sync_all(); }
        Ok::<(), std::io::Error>(())
    })();
    if result.is_err() { let _ = fs::remove_file(&tmp); }
    result.map_err(|e| format!("Cannot persist configuration: {e}"))
}
