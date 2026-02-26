import base64

b64 = "Cktwcm9qZWN0cy9zZWZpcm90LWZmOWFmL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9jaGF0cy9pbmRleGVzL18QARoQCgxwYXJ0aWNpcGFudHMQARoRCg1sYXN0VGltZXN0YW1wEAIaDAoIX19uYW1lX18QAg"
padded = b64 + "=" * ((4 - len(b64) % 4) % 4)
data = base64.urlsafe_b64decode(padded)

for i in range(0, len(data), 16):
    chunk = data[i:i+16]
    hex_str = " ".join(f"{b:02x}" for b in chunk)
    ascii_str = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
    print(f"{i:04x}  {hex_str:<48}  {ascii_str}")
