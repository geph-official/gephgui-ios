#! /bin/sh
cd ./geph5/binaries/geph5-client/
~/.cargo/bin/cargo lipo --release

cd ../../.. # in gephgui-ios
rsync -av ./geph5/target/universal/release/libgeph5_client.a ./libGeph5Client/
