use serde::Serialize;
use std::collections::VecDeque;

#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Event { ConfigChanged { revision: u64 } }

/// Old notifications may coalesce; the snapshot is always authoritative.
#[derive(Default)]
pub struct Events(VecDeque<Event>);
impl Events {
    pub fn push(&mut self, event: Event) {
        if self.0.len() == 32 { self.0.pop_front(); }
        self.0.push_back(event);
    }
    pub fn pop(&mut self) -> Option<Event> { self.0.pop_front() }
}
