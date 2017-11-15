//#![deny(warnings)]
#![allow(dead_code)]
extern crate rustorm;
#[macro_use]
extern crate serde_derive;
mod reference;
mod widget;

pub mod window;
mod tab;
mod field;
mod table_intel;
mod service;
pub mod data_service;


pub use window::Window;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
