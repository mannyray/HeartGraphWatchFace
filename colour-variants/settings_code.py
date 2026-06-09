"""Mirror of source/SettingsCode.mc — encodes a settings dict into the
12-char shareable code (`v1.0-XXXXX-Y`).

Bit layout (LSB = bit 0): see source/SettingsCode.mc for the canonical spec.
This is encode-only — we use it to name image files after their code.
"""

BASE32 = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"


def _bg(c):    return 1 if c == 0xFFFFFF else 0
def _tc(c):    return 1 if c == 0x555555 else 0
def _gn(c):
    if c == -3: return 1
    if c == 0xAAAAAA: return 2
    return 0


def _hr_min(hr):
    v = (hr - 30) // 5
    return max(0, min(7, v))


def _hr_max_delta(hr_max, hr_min):
    d = (hr_max - hr_min - 20) // 10
    return max(0, min(31, d))


def _hr_step(step):
    if step <= 5: return 0
    if step <= 10: return 1
    if step <= 15: return 2
    return 3


def _band(px):  return 1 if px == 20 else 0
def _minutes(m):
    if m == 3:  return 0
    if m == 5:  return 1
    return 2


def encode_settings(v: dict) -> str:
    hr_min = v["HRMin"]
    packed = 0
    # bit 0: ShowGraphAxis (inverted; defaults to True / on / bit=0)
    packed |= (0 if v.get("ShowGraphAxis", True) else 1) & 0x1
    packed |= (_bg(v["BackgroundColor"])         & 0x3)  << 1
    packed |= (_tc(v["TimeColor"])               & 0x3)  << 3
    packed |= (_gn(v["GraphNumberColor"])        & 0x3)  << 5
    packed |= (_hr_min(hr_min)                   & 0x7)  << 7
    packed |= (_hr_max_delta(v["HRMax"], hr_min) & 0x1F) << 10
    packed |= (_hr_step(v["HRStep"])             & 0x3)  << 15
    packed |= (v["PaletteIndex"]                 & 0xF)  << 17
    packed |= (_band(v["GraphBandPixels"])       & 0x1)  << 21
    packed |= (_minutes(v["HeartGraphMinutes"])  & 0x3)  << 22
    packed |= ((1 if v["MinimalMode"] else 0)    & 0x1)  << 24

    payload = "".join(BASE32[(packed >> (i * 5)) & 0x1F] for i in range(4, -1, -1))
    checksum = BASE32[sum(BASE32.index(c) for c in payload) & 0x1F]
    return f"v1.0-{payload}-{checksum}"


if __name__ == "__main__":
    # Sanity: default settings → known code
    defaults = {
        "BackgroundColor": 0x000000,
        "TimeColor": -2,
        "GraphNumberColor": -2,
        "HRMin": 40,
        "HRMax": 100,
        "HRStep": 10,
        "PaletteIndex": 0,
        "GraphBandPixels": 10,
        "HeartGraphMinutes": 3,
        "MinimalMode": False,
    }
    print(encode_settings(defaults))
