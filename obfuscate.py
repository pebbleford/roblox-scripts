"""
Pebbleford Hub - Script Obfuscator
Reads source Lua files from src/ and outputs obfuscated versions to root.

Obfuscation layers:
1. XOR encrypt all bytes with a rotating multi-byte key
2. Encode as comma-separated byte table
3. Wrap with compact decoder stub + loadstring
4. Variable names randomized per build

Usage: python obfuscate.py
"""

import os
import random
import string
import sys

SRC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src")
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

SCRIPTS = [
    "synapsex.lua",
    "nbtf.lua",
    "99nights.lua",
    "elected.lua",
    "keysystem.lua",
    "brookhaven.lua",
    "sharkbite.lua",
    "rivals.lua",
    "mm2.lua",
    "prisonlife.lua",
    "industrialist.lua",
    "psteleport.lua",
    "translator.lua",
]

def random_var(length=8):
    """Generate a random variable name like _Ix3aF2q"""
    first = random.choice("_" + string.ascii_letters)
    rest = ''.join(random.choices(string.ascii_letters + string.digits + "_", k=length - 1))
    return first + rest

def xor_encrypt(data: bytes, key: bytes) -> list:
    """XOR encrypt bytes with a rotating key"""
    result = []
    for i, b in enumerate(data):
        result.append(b ^ key[i % len(key)])
    return result

def generate_key(length=16):
    """Generate a random XOR key (avoid 0 bytes)"""
    return bytes([random.randint(1, 255) for _ in range(length)])

def obfuscate_script(source_code: str) -> str:
    """Obfuscate a Lua script with XOR encryption + loadstring wrapper"""
    raw_bytes = source_code.encode("utf-8")

    # Generate random XOR key
    key = generate_key(16)
    encrypted = xor_encrypt(raw_bytes, key)

    # Random variable names for the decoder stub
    v_key = random_var()
    v_data = random_var()
    v_out = random_var()
    v_i = random_var()
    v_v = random_var()
    v_xor = random_var()
    v_char = random_var()
    v_cat = random_var()
    v_load = random_var()

    # Format key as byte table
    key_str = "{" + ",".join(str(b) for b in key) + "}"

    # Split encrypted data into chunks for readability (lines of ~80 bytes)
    chunk_size = 80
    data_chunks = []
    for i in range(0, len(encrypted), chunk_size):
        chunk = encrypted[i:i+chunk_size]
        data_chunks.append(",".join(str(b) for b in chunk))
    data_str = "{" + ",\n".join(data_chunks) + "}"

    # Build the decoder stub
    # Uses bit32.bxor for Luau compatibility, with fallback
    stub = f"""-- Pebbleford Hub | Protected
local {v_key}={key_str}
local {v_data}={data_str}
local {v_xor}=bit32 and bit32.bxor or function(a,b) local r,p=0,1 for i=0,31 do local a1,b1=a%2,b%2 if a1~=b1 then r=r+p end a=(a-a1)/2 b=(b-b1)/2 p=p*2 end return r end
local {v_out}={{}}
for {v_i},{v_v} in ipairs({v_data}) do
{v_out}[{v_i}]=string.char({v_xor}({v_v},{v_key}[({v_i}-1)%#{v_key}+1]))
end
local {v_load}=table.concat({v_out})
local {v_load}_fn,{v_load}_err=loadstring({v_load})
if not {v_load}_fn then error("Load failed: "..tostring({v_load}_err)) end
return {v_load}_fn()
"""
    return stub

def main():
    success = 0
    failed = 0

    for script_name in SCRIPTS:
        src_path = os.path.join(SRC_DIR, script_name)
        out_path = os.path.join(OUT_DIR, script_name)

        if not os.path.exists(src_path):
            print(f"  SKIP  {script_name} (not found in src/)")
            failed += 1
            continue

        with open(src_path, "r", encoding="utf-8") as f:
            source = f.read()

        obfuscated = obfuscate_script(source)

        with open(out_path, "w", encoding="utf-8") as f:
            f.write(obfuscated)

        src_size = len(source)
        obf_size = len(obfuscated)
        ratio = obf_size / src_size if src_size > 0 else 0
        print(f"  OK    {script_name} ({src_size:,} -> {obf_size:,} bytes, {ratio:.1f}x)")
        success += 1

    print(f"\nDone: {success} obfuscated, {failed} skipped")

if __name__ == "__main__":
    print("Pebbleford Hub - Obfuscator")
    print("=" * 40)
    main()
