source [find interface/stlink.cfg]

transport select hla_swd

source [find target/stm32f4x.cfg]

source [find addrs.tcl]
source [find funcs.tcl]

## PB2 is INDICATOR_LIGHT
proc led {arg} {
    global RCC GPIOB

    set PP $GPIOB

    mmw $RCC(AHB1ENR) $(1 << 1) 0 ;# turn on clock

    if [string equal $arg init] {
        mmw $PP(MODER)   $(0b01 <<  4) $(0b11 <<  4)
        mmw $PP(OSPEEDR) $(0b11 << 14) $(0b11 << 14)
    } else {
        if {$arg} {
            mmw $PP(BSRR) $(1 << 2) 0
        } else {
            mmw $PP(BSRR) $(1 << 18) 0
        }
    }
}

proc iic_init {} {
    global RCC GPIOB IIC

    mmw $RCC(AHB1ENR) $(1 << 1) 0 ;# GPIOBEN=1
    mmw $RCC(APB2ENR) $(1 << 21) 0 ;# I2C1EN=1

    sleep 1

    ## IIC
    #  PB6 => SCL
    #  PB7 => SDA

    ## PB6
    mmw $GPIOB(MODER) $(0b10 << 12) $(0b11 << 12)    ;# alternate function
    mmw $GPIOB(OTYPER) $(1 << 6) 0                   ;# output open-drain
    mmw $GPIOB(OSPEEDR) $(0b11 << 12) $(0b11 << 12)  ;# H
    mmw $GPIOB(PUPDR) $(0b00 << 12) $(0b11 << 12)    ;# no pull
    mmw $GPIOB(AFRL) $(0b0100 << 24) $(0b1111 << 24) ;# AF4

    ## PB7
    mmw $GPIOB(MODER) $(0b10 << 14) $(0b11 << 14)    ;# alternate function
    mmw $GPIOB(OTYPER) $(1 << 7) 0                   ;# output open-drain
    mmw $GPIOB(OSPEEDR) $(0b11 << 14) $(0b11 << 14)  ;# H
    mmw $GPIOB(PUPDR) $(0b00 << 14) $(0b11 << 14)    ;# no pull
    mmw $GPIOB(AFRL) $(0b0100 << 28) $(0b1111 << 28) ;# AF4

    mmw $IIC(CR1) $(0b0 << 0) 0 ;# disable peripheral

    mmw $IIC(CR2) $(0b010000 << 0) $(0b111111 << 0) ;# 16MHz

    #                Fm          CCR=(t_{w(SCLH)}+t_{r(SCL)})/T_{PCLK1} = (4000ns + 1000ns)/60ns = 83
    mmw $IIC(CCR) $((0 << 15) | (83 << 0)) $(0xFF)

    #                 TRISE=(1000ns/16ns) + 1 = 16 + 1 = 17
    mmw $IIC(TRISE) $(0b010001 << 0) $(0b1111111 << 0)

    mmw $IIC(CR1) $(0b1 << 0) 0 ;# enable peripheral
}

proc read {addr} {
    global IIC

    mmw $IIC(CR1) $(1 << 8) 0 ;# start condition
    mwb $IIC(DR) 0xA6

    mdh $IIC(SR1)
    mdh $IIC(SR2)
    
    mwb $IIC(DR) $(($addr & 0xFF00) >> 8)
    mwb $IIC(DR) $($addr & 0xFF)

    mmw $IIC(CR1) $(1 << 8) 0 ;# start condition
    mww $IIC(DR) 0xA7

    mdh $IIC(SR1)
    mdh $IIC(SR2)

    set res [mdb $IIC(DR)]

    mmw $IIC(CR1) $(1 << 9) 0 ;# stop condition

    return [split_outp $res]
}

proc write {addr val} {
    global IIC

    mmw $IIC(CR1) $(1 << 8) 0 ;# start condition
    mwb $IIC(DR) 0xA6

    mdh $IIC(SR1)
    mdh $IIC(SR2)
    
    mwb $IIC(DR) $(($addr & 0xFF00) >> 8)
    mwb $IIC(DR) $($addr & 0xFF)

    mwb $IIC(DR) $($val & 0xFF)

    mmw $IIC(CR1) $(1 << 9) 0 ;# stop condition
}

$_TARGETNAME configure -event reset-init {
    # HSI clock is at 16MHz after reset.
    adapter speed 1000

    iic_init
}
