import zymkey

rand = zymkey.client.get_random(32)
print('Random bytes:', rand.hex())
locked = zymkey.client.lock(b'secret data')
print('Locked:', locked.hex()[:40], '...')
unlocked = zymkey.client.unlock(locked)
print('Unlocked:', unlocked.decode())
