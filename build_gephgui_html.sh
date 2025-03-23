#! /bin/sh

cd gephgui

npm i
npm run build

cd ..

rsync -av --delete ./gephgui/dist/ ./Geph/dist/

