use std::path::PathBuf;
use crate::{config::Config, events::{Event, Events}, system};

pub struct Engine {
    path: PathBuf,
    config: Config,
    revision: u64,
    events: Events,
}

impl Engine {
    pub fn open(path: PathBuf) -> Result<Self, String> {
        if !path.is_absolute() { return Err("Configuration path must be absolute.".into()); }
        let config = match system::read_config(&path)? {
            Some(json) => Config::parse(&json)?,
            None => {
                let config = Config::default();
                let json = serde_json::to_vec_pretty(&config).map_err(|e| e.to_string())?;
                system::atomic_write(&path, &json)?;
                config
            }
        };
        Ok(Self { path, config, revision: 0, events: Events::default() })
    }

    pub fn config(&self) -> &Config { &self.config }
    pub fn snapshot(&self) -> Result<String, String> {
        serde_json::to_string(&self.config).map_err(|e| e.to_string())
    }
    pub fn update(&mut self, config: Config) -> Result<(), String> {
        config.validate()?;
        if self.config == config { return Ok(()); }
        let json = serde_json::to_vec_pretty(&config).map_err(|e| e.to_string())?;
        // Persist first. Failed writes must not mutate in-memory state or emit events.
        system::atomic_write(&self.path, &json)?;
        self.config = config;
        self.revision += 1;
        self.events.push(Event::ConfigChanged { revision: self.revision });
        Ok(())
    }
    pub fn update_json(&mut self, json: &str) -> Result<(), String> { self.update(Config::parse(json)?) }
    pub fn reset(&mut self) -> Result<(), String> { self.update(Config::default()) }
    pub fn next_event(&mut self) -> Option<Event> { self.events.pop() }
}
