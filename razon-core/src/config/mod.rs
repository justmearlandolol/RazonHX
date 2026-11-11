use serde::{Deserialize, Serialize};
use crate::themes::valid_color;

pub const DEFAULT_JSON: &str = include_str!("../../../Config/default.json");
pub const MAX_CONFIG_BYTES: u64 = 64 * 1024;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct General {
    pub show_settings_on_launch: bool,
    pub hide_on_close: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Appearance {
    pub accent_color: String,
    pub background_color: String,
    pub text_color: String,
    pub window_opacity: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub schema_version: u32,
    pub general: General,
    pub appearance: Appearance,
}

impl Default for Config {
    fn default() -> Self {
        serde_json::from_str(DEFAULT_JSON).expect("bundled defaults must be valid")
    }
}

impl Config {
    pub fn parse(json: &str) -> Result<Self, String> {
        if json.len() as u64 > MAX_CONFIG_BYTES {
            return Err("Configuration exceeds the 64 KiB limit.".into());
        }
        let config: Self = serde_json::from_str(json)
            .map_err(|e| format!("Invalid configuration: {e}"))?;
        config.validate()?;
        Ok(config)
    }

    pub fn validate(&self) -> Result<(), String> {
        if self.schema_version != 1 {
            return Err(format!("Unsupported configuration schema {}. File left unchanged.", self.schema_version));
        }
        let a = &self.appearance;
        if ![&a.accent_color, &a.background_color, &a.text_color].iter().all(|c| valid_color(c)) {
            return Err("Colors must use #RRGGBB notation.".into());
        }
        if !a.window_opacity.is_finite() || !(0.85..=1.0).contains(&a.window_opacity) {
            return Err("Window opacity must be between 0.85 and 1.0.".into());
        }
        Ok(())
    }
}
