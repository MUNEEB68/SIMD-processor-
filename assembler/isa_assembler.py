OPCODES = {
    "ADDH":0,
    "ADDO":1,
    "ADDQ":2,
    "SETH":44,
    "SETO":45,
    "SETQ":46,
    "HALT":63
}


def encode_set(op, r0, imm):
    opcode = OPCODES[op]
    return (opcode << 12) | (r0 << 10) | imm


print(bin(encode_set("SETH",0,5))[2:].zfill(18))