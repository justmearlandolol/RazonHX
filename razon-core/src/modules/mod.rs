use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Desktop {
    pub toolbar: Surface,
    pub dock: Surface,
    pub clock: bool,
    pub clock_corner: Corner,
    pub twenty_four_hour: bool,
    pub seconds: bool,
    pub widgets: bool,
    pub dock_apps: Vec<String>,
    pub library: Vec<Wallpaper>,
    pub wallpapers: BTreeMap<String, String>,
    pub scaling: Scaling,
    pub media_paused: bool,
    pub media_volume: f64,
    pub weather: Option<Weather>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Surface {
    pub display: Display,
    pub edge: Edge,
    pub opacity: f64,
    pub blur: bool,
    pub size: u32,
    pub radius: u32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Wallpaper {
    pub id: String,
    pub name: String,
    pub kind: Media,
    pub category: String,
    pub favorite: bool,
    pub archived: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Weather {
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
}

macro_rules! choices {
    ($name:ident: $($item:ident),+) => {
        #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
        #[serde(rename_all = "snake_case")]
        pub enum $name { $($item),+ }
    };
}
choices!(Display: Always, Overlay, Hidden);
choices!(Edge: Top, Bottom, Left, Right);
choices!(Corner: TopLeft, TopRight, BottomLeft, BottomRight);
choices!(Scaling: Fill, Fit, Stretch, Center);
choices!(Media: Png, Gif, Mp4, Html, Wav);

impl Default for Desktop {
    fn default() -> Self {
        serde_json::from_str::<serde_json::Value>(crate::config::DEFAULT_JSON)
            .and_then(|json| serde_json::from_value(json["desktop"].clone()))
            .expect("bundled desktop defaults must be valid")
    }
}

impl Desktop {
    pub fn validate(&self) -> Result<(), String> {
        if !matches!(self.toolbar.edge, Edge::Top | Edge::Bottom) {
            return Err("Toolbar position must be Top or Bottom.".into());
        }
        for surface in [&self.toolbar, &self.dock] {
            if !(0.20..=1.0).contains(&surface.opacity)
                || !(28..=64).contains(&surface.size)
                || surface.radius > 32
            {
                return Err("Desktop panel size, corner radius or opacity is out of range.".into());
            }
        }
        if !(0.0..=1.0).contains(&self.media_volume) {
            return Err("Media volume must be between 0% and 100%.".into());
        }
        if self.dock_apps.len() > 12
            || self.dock_apps.iter().any(|id| !short_label(id, 200))
            || self.dock_apps.iter().collect::<BTreeSet<_>>().len() != self.dock_apps.len()
        {
            return Err("Dock favorites must contain at most 12 unique applications.".into());
        }
        if self.library.len() > 100 || self.wallpapers.len() > 24 {
            return Err("The library supports 100 files and 24 display assignments.".into());
        }
        let mut ids = BTreeSet::new();
        for item in &self.library {
            if !valid_id(&item.id)
                || !ids.insert(&item.id)
                || !short_label(&item.name, 160)
                || !short_label(&item.category, 80)
            {
                return Err("Invalid or duplicate wallpaper metadata.".into());
            }
        }
        for (display, id) in &self.wallpapers {
            if !(display == "all" || valid_id(display) || display.parse::<u32>().is_ok())
                || !self
                    .library
                    .iter()
                    .any(|item| &item.id == id && !item.archived)
            {
                return Err("A wallpaper assignment references an invalid display or file.".into());
            }
        }
        if let Some(weather) = &self.weather {
            if !short_label(&weather.name, 80)
                || !(-90.0..=90.0).contains(&weather.latitude)
                || !(-180.0..=180.0).contains(&weather.longitude)
            {
                return Err("Enter a location name and valid latitude and longitude.".into());
            }
        }
        Ok(())
    }
}

fn short_label(value: &str, limit: usize) -> bool {
    !value.trim().is_empty() && value.len() <= limit && !value.chars().any(char::is_control)
}

fn valid_id(value: &str) -> bool {
    value.len() == 36
        && value.bytes().enumerate().all(|(index, byte)| {
            if matches!(index, 8 | 13 | 18 | 23) {
                byte == b'-'
            } else {
                byte.is_ascii_hexdigit()
            }
        })
}
