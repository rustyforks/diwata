reset
cd webclient && ./compile.sh
cd ..
cargo run -p diwata -- --db-url=postgres://postgres:p0stgr3s@localhost/mock -p 8003 -a 0.0.0.0
