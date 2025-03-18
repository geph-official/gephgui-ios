#! /bin/bash

cd ./gephgui; 
source ~/.bashrc; 
npm i; npm build;

rsync -r dist/ ../Geph/dist/
