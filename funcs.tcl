proc split_outp {outp} {
    set spl [split $outp :]
    return 0x[string trim [lindex $spl 1]]
}

proc getv {addr} {
    set outp [string trim [mdw $addr]]
    return [split_outp $outp]
}

proc bits {val} {
    set bitv [format %032b $val]
    return [regexp -all -inline .... $bitv]
}

proc abits {addr} {
    bits [getv $addr]
}

proc regs {ary} {
    foreach {rnam raddr} $ary {
        echo [format "%15s: %s" $rnam [abits $raddr]]
    }
}
