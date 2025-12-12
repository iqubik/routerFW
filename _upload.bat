"C:\Program Files\PuTTY\pscp.exe" -scp "C:\Users\iqubik\Documents\GitHub\ewp\beeline\firmware_output\tplink-sysupgrade.bin" root@192.168.3.1:/tmp/firmware.bin
ssh root@192.168.3.1 sysupgrade -v -n /tmp/firmware.bin
pause