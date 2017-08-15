
sudo dd if=../loader_test/boot of=/dev/sdb bs=512
sudo dd if=../sdcard/mntsd.device of=/dev/sdb bs=512 seek=2

sudo sync

