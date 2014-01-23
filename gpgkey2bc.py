# Require Python 3.2 or later

import sys, binascii, hashlib
from subprocess import check_output

b58chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

def b58encode(bytes_str):
  l = int.from_bytes(bytes_str, byteorder='big')
  result = ''
  while l >= 58:
    l, mod = divmod(l, 58)
    result = b58chars[mod] + result
  result = b58chars[l] + result
  # leading 0-bytes in the input will be leading-1s.
  n = 0
  for c in bytes_str:
    if c == 0:
        n += 1
    else:
        break
  return ('1'*n) + result

def get_public_key_data(keyid):
    r = check_output(["gpg2", "-k", "--with-colons", "--with-key-data", keyid])
    i = 0
    keyid_bytes = bytes(keyid, 'ascii')
    while True:
        i = r.find(b'\nsub:u:256:19:', i)
        if i < 0:
            print("Not found (1)")
            exit(2)
        elif r[i+22:i+30] == keyid_bytes:
            i_pkd = i+30
            while True:
                i_pkd = r.find(b'\npkd', i_pkd)
                if i_pkd < 0:
                    print("Not found (2)")
                    exit(2)
                elif r[i_pkd+5:i_pkd+6] == b'1':
                    i_pub = i_pkd + 11
                    break
                else:
                    i_pkd += 4
            break
        else:
            i += 14
    return r[i_pub:i_pub+130]

def main(keyid):
    pubkey_raw = binascii.unhexlify(get_public_key_data(keyid))
    pubkey_raw_sha256sum = hashlib.sha256(pubkey_raw).digest()
    ripemd160sum = hashlib.new('ripemd160',pubkey_raw_sha256sum).digest()
    pubkey_internal = b'\x00' + ripemd160sum
    pubkey_sha256sum_1st = hashlib.sha256(pubkey_internal).digest()
    pubkey_sha256sum = hashlib.sha256(pubkey_sha256sum_1st).digest()
    address = pubkey_internal + pubkey_sha256sum[0:4]
    b58address = b58encode(address)
    print(b58address)

if __name__ == '__main__':
   keyid=sys.argv[1]
   main(keyid)
