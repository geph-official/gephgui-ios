#! /bin/bash

cd ./gephgui; 
source ~/.bashrc; 
pnpm i; pnpm build;

rsync -r dist/ ../Geph/dist/
