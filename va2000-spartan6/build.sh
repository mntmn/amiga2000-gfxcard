#!/bin/sh

xst -intstyle ise -ifn "va2000.xst" -ofn "va2000.syr"

ngdbuild -intstyle ise -dd _ngo -sd xilinx_modules -nt timestamp -uc pins.ucf -p xc6slx25-ftg256-3 va2000.ngc va2000.ngd

map -intstyle ise -p xc6slx25-ftg256-3 -w -logic_opt off -ol high -xe n -t 1 -xt 0 -register_duplication off -r 4 -global_opt off -mt 2 -ir off -pr b -lc off -power off -o va2000_map.ncd va2000.ngd va2000.pcf

par -w -intstyle ise -ol high -xe n -mt 4 va2000_map.ncd va2000.ncd va2000.pcf

trce -intstyle ise -v 3 -s 3 -n 3 -fastpaths -xml va2000.twx va2000.ncd -o va2000.twr va2000.pcf -ucf pins.ucf

bitgen -intstyle ise -f va2000.ut va2000.ncd

