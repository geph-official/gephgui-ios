#! /bin/bash

echo "Compiling geph4-client binary + moving it to gephgui-ios 
libGeph4Client!";

cd ../geph4-client;
cargo-lipo --release;

mv ./target/universal/release/libgeph4client.a 
../gephgui-ios/libGeph4Client

echo "...done!"
