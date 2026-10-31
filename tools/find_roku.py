import socket, time
msg = ("M-SEARCH * HTTP/1.1\r\nHost: 239.255.255.250:1900\r\n"
       "Man: \"ssdp:discover\"\r\nST: roku:ecp\r\nMX: 3\r\n\r\n").encode()
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
s.settimeout(1.0)
for _ in range(3):
    s.sendto(msg, ("239.255.255.250", 1900))
found = set()
end = time.time() + 5
while time.time() < end:
    try:
        data, addr = s.recvfrom(2048)
    except socket.timeout:
        continue
    for line in data.decode(errors="ignore").splitlines():
        if line.lower().startswith("location:"):
            found.add(line.split(":", 1)[1].strip())
print("\n".join(sorted(found)) or "nenhuma Roku respondeu")
