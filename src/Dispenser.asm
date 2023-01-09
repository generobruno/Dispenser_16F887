;***************************************************************************************
; Autores: Bruno Andrés Genero, Antonio Viglietti
; Comision: COM 8 - Martin Ayarde   
; Descripcion: Dosificador controlado de alcohol en gel     
;****************************************************************************************
	LIST    P=16F887
	#INCLUDE <p16f887.inc>

; CONFIG1
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_ON & _FCMEN_ON & _LVP_OFF
; CONFIG2
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF
 
	    CBLOCK  0X20
	    KEYNUM
	    AUX_KEYNUM
	    AUX_FILE
	    CRITICAL_BAT_H
	    CRITICAL_BAT_L
	    CRITICAL_GEL_H
	    CRITICAL_GEL_L
	    AUX_TMR0
	    AUX_VUELTA
	    DIG_A_1
	    DIG_A_2
	    DIG_A_3
	    DIG_B_1
	    DIG_B_2
	    DIG_B_3
	    AUX_DISP
	    AUX_MSG
	    ADQ_DELAY
	    PORTC_ROT
	    ENDC
	    CBLOCK  0X70
	    STATUS_TEMP
	    W_TEMP
	    ENDC
	
	    ORG	    0x00
	    GOTO    MAIN
	    ORG	    0x04
	    GOTO    INT
	    ORG	    0x05
    
; -------------------------- CONFIGURACION INICIAL -----------------------------
MAIN
    BANKSEL	ANSELH
    CLRF	ANSELH
    MOVLW	B'10100000'
    MOVWF	ANSEL		; Canales AN5 Y AN7 del ADC como entrada analogica
    BCF		STATUS,RP1
    BCF		OSCCON,0	; Fuente de Reloj definida por CONFIG1 (XT Externo)
    MOVLW	B'00110111'	; Pull-ups:ON, T0CS:T0CKI pin(para desactivar el Timer), PSA:TMR0, PR:256  
    MOVWF	OPTION_REG	; INTEDG: RB0 interrumpe por flanco de bajada
    MOVLW	B'00000101'	
    MOVWF	TRISE		; Entradas Analógicas del ADC
    MOVLW	B'11000000'
    MOVWF	TRISA		; Salidas para el Dispenser y el Buzzer, Entradas para Reloj
    MOVLW	B'00000111'
    MOVWF	TRISC		; Puerto de Seleccion de Displays
    MOVLW	B'01110001'	; RB<1;3>: Salidas, RB<4;6>: Entradas, RB0: Entrada para sensor de proximidad
    MOVWF	TRISB		; Para el teclado matricial
    CLRF	TRISD		; Puerto de Datos de Displays
    MOVWF	WPUB		; Resistencias de Pull-up habilitadas 
    MOVLW	B'01110000'
    MOVWF	IOCB		; Interrupcion por cambio de nivel en RB<4;7>
    BSF		PIE1,ADIE	; Habilitamos interrupcion por ADC
    CLRF	ADCON1		; ADC Justificado a la derecha, y referencias Vss y Vdd
    BSF		ADCON1,ADFM
    BCF		STATUS,RP0
    CLRF	INTCON		; Se limpian banderas de interrupcion y se deshabilita interrupcion por TMR0
    MOVLW	B'11001000'	; Se habilita interrupcion por cambio de nivel en Puerto B, PEIE y GIE
    MOVWF	INTCON  
    MOVLW	B'11011100'	
    MOVWF	ADCON0		; ADCS: Frc, CHS: AN7(Sensor Bateria), GO/DONE: 0, ADON: 0 (ADC Apagado)
    MOVLW	0x33
    MOVWF	CRITICAL_BAT_L
    CLRF	CRITICAL_BAT_H	; Seteamos el valor de la Bateria Critica
    CLRF	AUX_TMR0
    CLRF	AUX_VUELTA
    MOVLW	0x7C		; Letra B en 7 segmentos
    MOVWF	DIG_B_3	
    MOVLW	0x5F		; Letra A en 7 segmentos
    MOVWF	DIG_B_2
    MOVLW	0x78		; Letra T en 7 segmentos
    MOVWF	DIG_B_1
    MOVLW	0x7D		; Letra G en 7 segmentos
    MOVWF	DIG_A_3	
    MOVLW	0x79		; Letra E en 7 segmentos
    MOVWF	DIG_A_2
    MOVLW	0x38		; Letra L en 7 segmentos
    MOVWF	DIG_A_1
    CLRF	PORTB		; Se limpia el puerto B  
    MOVF	PORTB,F		; Referencia para puerto B
    CLRF	PORTA
    CLRF	PORTC
    CLRF	PORTD
    NOP
    GOTO	DORMIR		; Se pone el micro a dormir

; ------------------------------------------------------------------------------
; ---------------------------------- SLEEP -------------------------------------
DORMIR
    NOP
    SLEEP			; Se pone el micro en modo bajo consumo
    NOP
    BTFSC	AUX_TMR0,0	; Si el auxiliar esta en 1
    GOTO	$-1		; Espero a que termine el tiempo de anti-rebote
    BTFSC	AUX_VUELTA,1	; Verificamos si podemos ir a chequear los valores
    GOTO	VERIFICACIONES	; Vamos a chequear los valores
    GOTO	DORMIR		; Si no, vuelvo a dormir

; ------------------------------------------------------------------------------
VERIFICACIONES   
    BTFSC	AUX_VUELTA,0	; Vemos si ya analizamos la bateria
    GOTO	CHECK_GEL	; Si ya lo hicimos, vamos a analizar el alcohol en gel
    GOTO	CHECK_BAT	; Si no, analizamos la bateria 

; ------------------------------------------------------------------------------
; Subrutina para chequear los valores de la bateria y la cantidad de alcohol en
; gel disponible.
CHECK_BAT   ; Chequeo del nivel de bateria
    BSF		AUX_VUELTA,0	; Se usa un auxiliar para marcar que es la primera vuelta
    
    ; Resta --------------------
    MOVF	ADRESH,W
    SUBWF	CRITICAL_BAT_H,W; Restamos a el valor de bat actual(obtenido por ADC) CRITICAL_BAT_H
    BTFSS	STATUS,C        ; Chequeamos el resultado
    GOTO	CHECK_BAT_OK	; Si el nivel de bateria actual > CRITICAL_BAT, vamos a "CHECK_BAT_OK"
    BANKSEL	ADRESL		; Vamos al banco donde esta ADRESL
    MOVF	ADRESL,W	; Si no, repetimos para CRITICAL_BAT_L
    BCF		STATUS,RP0	; Volvemos al banco 0
    SUBWF	CRITICAL_BAT_L,W	
    BTFSC	STATUS,C
    CALL	DISP_MSG_BAT	; Si el nivel de bateria actual <= CRITICAL_BAT, vamos a "DISP_MSG_BAT"
    ; --------------------------
    
CHECK_BAT_OK
    MOVLW	B'11010101'	; Seleccionamos el canal del Alcohol en Gel
    MOVWF	ADCON0		; ADCS: Frc, CHS: AN5(Sensor Alcohol en Gel), GO/DONE: 0
    CALL	ADQTIME		; Esperamos 11,5 ms
    BSF		ADCON0,1	; Se pone el ADC a convertir
    GOTO	DORMIR
    
CHECK_GEL   ; Chequeo del nivel de gel
    BCF		AUX_VUELTA,0	; Marcamos que ya hicimos la segunda vuelta.
    BCF		AUX_VUELTA,1	  
    BCF		ADCON0,ADON	; Se apaga el ADC
    ; Resta --------------------
    MOVF	ADRESH,W	; Buscamos los 2 MSB del valor critico de alcohol en gel
    SUBWF	CRITICAL_GEL_H,W; Restamos a los 2 MSB del nivel actual de alcohol en gel(obtenido por ADC) los 2 MSB de CRITICAL_GEL_H
    BTFSS	STATUS,C        ; Chequeamos el resultado
    GOTO	CHECK_OK	; Si los 2 MSB del nivel actual de alcohol en gel > los 2 MSB de CRITICAL_GEL_H, vamos a "CHECK_OK" 
    BTFSS	STATUS,Z	; Si los 2 MSB del nivel actual de alcohol en gel = los 2 MSB de CRITICAL_GEL_H, verificamos los otros 8 bits
    CALL	DISP_MSG_GEL	; Sino, si el nivel actual de alcohol en gel < CRITICAL_GEL_H, vamos a "DISP_MSG_GEL" 
    BANKSEL	ADRESL
    MOVF	ADRESL,W	; Buscamos los 8 LSB del valor critico de alcohol en gel
    BANKSEL	ADRESH
    SUBWF	CRITICAL_GEL_L,W; Restamos a los 8 LSB del nivel actual de alcohol en gel(obtenido por ADC) los 8 LSB de CRITICAL_GEL_L
    BTFSS	STATUS,C	; Chequeamos el resultado
    GOTO	CHECK_OK	; Si los 8 LSB del nivel actual de alcohol en gel > los 8 LSB de CRITICAL_GEL_L, vamos a "CHECK_OK" 
    CALL	DISP_MSG_GEL	; S--i el nivel actual de alcohol en gel <= CRITICAL_GEL_L, vamos a "DISP_MSG_GEL" 
    ; --------------------------
    
    BTFSS	ADRESH,1	; Verificamos que el nivel actual de alcohol en gel no sea menor al 1%, viendo los
    BTFSC	ADRESH,0	; 2 MSB del valor actual
    GOTO	CHECK_OK	; Si el valor es mayor al 1%, se va a "CHECK_OK" para dispensar
    BANKSEL	ADRESL
    MOVLW	ADRESL	; Valor que representa 1% de alcohol en binario(segun tabla)
    SUBLW	b'00001010'	; Restamos los 2 valores
    BANKSEL	ADRESH
    BTFSS	STATUS,C	; Vemos si el nivel actual de alcohol en gel <= 1%
    GOTO	CHECK_OK
    BSF		INTCON,INTE	; Volvemos a habilitar la interrupcion por RB0/INT
    GOTO	DORMIR		; Si lo es, no se dispensara alcohol en gel

CHECK_OK    ; Es posible dispensar gel	
    MOVLW	.3 
    MOVWF	AUX_DISP	; Inicializamos AUX_DISP
CONTA1
    BSF		PORTA,1		; Abrimos el pulso de alcohol en gel por puerto RA1
    CALL	RETARDO_500MS
    BCF		PORTA,1		; Cerramos el pulso de alcohol en gel por puerto RA1
    CALL	RETARDO_500MS	; Llamamos 2 veces al retardo de 500ms,llevandolo
    CALL	RETARDO_500MS	; a 1 segundo de retardo total (0.5seg*2)      
    DECFSZ	AUX_DISP,F	; Contamos 3 pulsos de alcohol en gel
    GOTO	CONTA1  	
    CLRF	AUX_DISP
    BSF		INTCON,INTE	; Volvemos a habilitar la interrupcion por RB0/INT
    GOTO	DORMIR  

;------------------------ Subrutinas de Interrupcion ---------------------------
INT
;-------------------------------------------------------------------------------
;Resguardo del contexto
    MOVWF	W_TEMP		; Se guarda valor del registro W
    SWAPF	STATUS,W	; Se guarda valor del registro STATUS
    MOVWF	STATUS_TEMP
    
;-------------------------------------------------------------------------------
;Identificacion y asignacion de prioridades de interrupcion	
    BTFSC	INTCON,T0IF
    GOTO	ISR_TMR0	; ISR que realiza un rapido escaneo de las teclas 
    BTFSC	INTCON,RBIF
    GOTO	ISR_PORTB	; ISR que ante algun cero en RB<4;7> activa el antirebote
    BTFSC	INTCON,INTF
    GOTO	ISR_INTF	; ISR que analiza los valores criticos
    BTFSC	PIR1,ADIF
    GOTO	ISR_ADIF	; ISR que compara valores
    GOTO	ENDINT
;-------------------------------------------------------------------------------
; Rutina anti-rebote: Genera un retardo de unos 50 milisegundos.
ISR_PORTB
    BCF		STATUS,RP0
    BCF		STATUS,RP1
    BSF		AUX_TMR0,0	; Seteamos el auxiliar de TMR0
    MOVF	PORTB,F		; Referencia para limpiar RBIF
    BCF		INTCON,RBIF	; Se limpia la bandera de RBIF
    BCF		INTCON,RBIE	; Se deshabilita interrupcion por puerto B	
    MOVLW	.60		; Valor que setea 50 mseg aprox. para el antirebote por timer
    MOVWF	TMR0		; Se carga el valor deseado en el TMR0
    BSF		STATUS,RP0
    BCF		OPTION_REG,T0CS	; Hacemos que TMR0 comienze a contar 		    
    BCF		INTCON,T0IF	; Se limpia bandera de interrupcion por TMR0
    BSF		INTCON,T0IE	; Se habilita interrupcion por desbordamiento en TMR0
    GOTO	ENDINT
;---------------------------------------------------
; Rutina de escaneo de teclado: Se presiona una tecla que representa el porcentaje de alcohol
; en gel se considerara como critico.
ISR_TMR0
    BSF		STATUS,RP0
    BCF		STATUS,RP1
    BSF		OPTION_REG,T0CS	; Timer0 deja de contar	    
    BCF		INTCON,T0IF	; Se limpia bandera de interrupcion por TMR0
    BCF		INTCON,T0IE	; Se deshabilita interrupcion por TMR0
    CLRF	AUX_TMR0	; Reinicio el auxiliar del TMR0
    BCF		STATUS,RP0	    
    CALL	SCAN		; Se escanea la tecla presionada
    CLRF	PORTB		; Se llevan a cero las salidas del Puerto B
    MOVF	PORTB,F		; Se establece estado de referencia para la interrupcion por Puerto B
    BCF		INTCON,RBIE	; Se deshabilita interrupcion por cambio de nivel en Puerto B
    BSF		INTCON,INTE	; Se habilita interrupcion por RB0/INT
    CLRF	AUX_TMR0	; Volvemos a reiniciar el auxiliar de TMR0
    GOTO	ENDINT
;---------------------------------------------------
; Rutina de INTF: Cada vez que se presiona un pulsador en RB0 se analizan los valores analogicos
; de la cantidad de Bateria y Alcohol en Gel.
ISR_INTF
    BCF		INTCON,INTF	; Se limpia la bandera INTF
    BCF		INTCON,INTE	; Deshabilitamos interrupcion por RB0/INT
    BCF		PIR1,ADIF	; Se limpia la bandera del ADC
    MOVLW	B'11011100'	
    MOVWF	ADCON0		; Se vuelve a seleccionar el canal de la bateria
    BSF		ADCON0,ADON	; Se enciende el ADC
    CALL	ADQTIME		; Esperamos 11,5 ms
    BSF		ADCON0,1	; Se pone el ADC a convertir
    GOTO	ENDINT
;---------------------------------------------------
; Rutina de ADIF: Se comparan los valores convertidos con los criticos y, si es posible, se
; dispensa alcohol en gel. En caso contrario se muestra un mensaje por los displays.
ISR_ADIF
    BCF		PIR1,ADIF	; Se limpia la bandera del ADC
    BSF		AUX_VUELTA,1	; Habilitamos el chequeo
    GOTO	ENDINT
    
;---------------------------------------------------
;Recuperacion del contexto    
ENDINT    
    BCF		STATUS,RP0
    BCF		STATUS,RP1
    SWAPF	STATUS_TEMP,W
    MOVWF	STATUS		; a STATUS se le da su contenido original
    SWAPF	W_TEMP,F	; a W se le da su contenido original
    SWAPF	W_TEMP,W
    RETFIE    
;-------------------------------------------------------------------------------

    
;----------------------------- Otras Subrutinas --------------------------------
;*******************************************************************************
; Escaneo del Teclado
SCAN
    MOVF	KEYNUM,W
    MOVWF	AUX_KEYNUM
    CLRF	KEYNUM		; Se lleva a cero el contador del numero de tecla
    MOVLW	b'00001101'	; Evaluamos primera fila del teclado
    MOVWF	AUX_FILE	; Auxiliar para cambiar de fila
    
SCAN_NEXT
    MOVF	AUX_FILE,W    
    MOVWF	PORTB	
    BTFSS	PORTB,RB4	; Columna 1 es 0?
    GOTO	SR_KEY
    INCF	KEYNUM,F
    BTFSS	PORTB,RB5	; Columna 2 es 0?
    GOTO	SR_KEY
    INCF	KEYNUM,F
    BTFSS	PORTB,RB6	; Columna 3 es 0?
    GOTO	SR_KEY
    BSF		STATUS,C	; Ninguna columna es 0
    RLF		AUX_FILE,F	; Se evalua la proxima fila
    INCF	KEYNUM,F	; Se incrementa el contador
    MOVLW	.9		
    SUBWF	KEYNUM,W	; Se testea si ya se escaneo las 9 teclas
    BTFSS	STATUS,Z		
    GOTO	SCAN_NEXT	; Si no llego a 9, busca proxima fila
    MOVF	AUX_KEYNUM,W	; Si no se ha presionado ninguna tecla se
    MOVWF	KEYNUM		; mantiene el ultimo valor de tecla presionada
    RETURN
    
;*******************************************************************************
; Servicio al teclado
SR_KEY
    MOVF	KEYNUM,W	; Se mueve el valor de la tecla a W
    MOVWF	AUX_KEYNUM	; y también se guarda en el auxiliar
    CALL	TABLA_GEL_LOW	; Se llama a la tabla para la parte baja
    MOVWF	CRITICAL_GEL_L	; y se mueve el resultado a su variable
    MOVF	AUX_KEYNUM,W	; Se vuelve a mover el valor de la tecla a W
    CALL	TABLA_GEL_HIGH	; Se llama a la tabla para la parte alta
    MOVWF	CRITICAL_GEL_H	; y se mueve el resultado a la variable
    RETURN	

;*******************************************************************************
; Tablas de equivalencias para porcentajes
TABLA_GEL_LOW
    ADDWF	PCL,F
    RETLW	0x0A		; Tecla 1 = 1% = 0.05V
    RETLW	0x33		; Tecla 2 = 5% = 0.25V
    RETLW	0x66		; Tecla 3 = 10% = 0.5V
    RETLW	0x9A		; Tecla 4 = 15% = 0.75V
    RETLW	0xCD		; Tecla 5 = 20% = 1V
    RETLW	0x00		; Tecla 6 = 25% = 1.25V
    RETLW	0x33		; Tecla 7 = 30% = 1.5V
    RETLW	0x66		; Tecla 8 = 35% = 1.75V
    RETLW	0x99		; Tecla 9 = 40% = 2V
    
TABLA_GEL_HIGH
    ADDWF	PCL,F
    RETLW	0x00		; Tecla 1 = 1% = 0.05V
    RETLW	0x00		; Tecla 2 = 5% = 0.25V
    RETLW	0x00		; Tecla 3 = 10% = 0.5V
    RETLW	0x00		; Tecla 4 = 15% = 0.75V
    RETLW	0x01		; Tecla 5 = 20% = 1V
    RETLW	0x01		; Tecla 6 = 25% = 1.25V
    RETLW	0x01		; Tecla 7 = 30% = 1.5V
    RETLW	0x01		; Tecla 8 = 35% = 1.75V
    RETLW	0x01		; Tecla 9 = 40% = 2V
    
;*******************************************************************************
; Subrutina para generar un retardo de 500ms mediante Timer1   
RETARDO_500MS
    MOVLW	B'00110001'	; Configuramos el TMR1
    MOVWF	T1CON
    BCF		PIR1,TMR1IF	; Limpiamos la bandera del timer
    CLRF	TMR1H 
    CLRF	TMR1L		; Reiniciamos el timer
    BTFSS	PIR1,TMR1IF	; Esperamos hasta que desborte del Timer1, levantando 
    GOTO	$-1		; la bandera TMRIF, habiendo contado medio segundo aprox
    
    RETURN

;*******************************************************************************
; Subrutina para Mensaje por Batería Critica: Se muestra por los displays 7 segmentos
; la palabra "BAT", indicando que se necesita un cambio de baterias. Además, hacemos 
; sonar un buzzer por unos segundos.
DISP_MSG_BAT
    MOVLW	.3
    MOVWF	AUX_MSG		; Variable con la que multiplicamos x6 el tiempo del Timer1
    BCF		PIR1,0
    BANKSEL	PIE1
    BCF		PIE1,TMR1IE	; Desabilitamos la interrupción por Timer1
    BCF		STATUS,RP0
    MOVLW	B'00110001'	; Configuramos el TMR1
    MOVWF	T1CON
    BSF		PORTA,0
DIGIT_B
    BCF		PIR1,0		; Limpiamos la bandera del timer
    CLRF	TMR1H
    CLRF	TMR1L		; Reiniciamos el timer 0
    
DIGITOS_B
    MOVLW	DIG_B_1
    MOVWF	FSR		; Se apunta al primer digito a mostrar
    MOVLW	B'00010000'
    MOVWF	PORTC_ROT
    MOVWF	PORTC		; Se habilita el digito a mostrar   
DIGITO_B    
    MOVF	INDF,W		; Lee dato a mostrar y lo guarda en W
    MOVWF	PORTD		; Escribe digito en el display
    CALL	RETARDO_DISP; Lo mantiene encendido
    BCF		STATUS,C	; Carry en 0 para poder rotar
    RLF		PORTC_ROT,F
    MOVF	PORTC_ROT,W
    MOVWF	PORTC		; Habilitamos el siguiente display
    INCF	FSR,F		; Apunta al proximo dato a mostrar
    BTFSS	PORTC_ROT,7		; Ya mostro los 3 digitos?
    GOTO	DIGITO_B    	; No mostro todo, va al proximo digito
    BTFSS	PIR1,0		; Si ya mostro todo, vemos si ya ha desbordado el Timer1
    GOTO	DIGITOS_B	; Si no lo hizo vuelve a refrescar
    DECFSZ	AUX_MSG		; Decrementamos la variable 
    GOTO	DIGIT_B		; Si no es cero, se resetea el timer y vuelve a refrescar
    BCF		PORTA,0
    RETURN			; Si lo es, ya mostro el mensaje por 2 segundos y vuelve

;*******************************************************************************
; Subrutina para Mensaje por Alcohol en Gel Critico: Se muestra por los displays 7
; segmentos la palabra "LOW", indicando que se necesita alcohol en gel. Además, hacemos
; sonar un buzzer por unos segundos.
DISP_MSG_GEL
    MOVLW	.3
    MOVWF	AUX_MSG		; Variable con la que multiplicamos x6 el tiempo del Timer1
    BCF		PIR1,0
    BANKSEL	PIE1
    BCF		PIE1,TMR1IE	; Desabilitamos la interrupción por Timer1
    BCF		STATUS,RP0
    MOVLW	B'00110001'	; Configuramos el TMR1
    MOVWF	T1CON
    BSF		PORTA,0
DIGIT_A
    BCF		PIR1,0		; Limpiamos la bandera del timer
    CLRF	TMR1H
    CLRF	TMR1L		; Reiniciamos el timer 0	 
DIGITOS_A
    BTFSS	AUX_MSG,0
    BSF		PORTA,0
    MOVLW	DIG_A_1
    MOVWF	FSR		; Se apunta al primer digito a mostrar
    MOVLW	B'00010000'
    MOVWF	PORTC_ROT
    MOVWF	PORTC		; Se habilita el digito a mostrar
DIGITO_A    
    MOVF	INDF,W		; Lee dato a mostrar y lo guarda en W
    MOVWF	PORTD		; Escribe digito en el display
    CALL	RETARDO_DISP; Lo mantiene encendido
    BCF		STATUS,C	; Carry en 0 para poder rotar
    RLF		PORTC_ROT,F
    MOVF	PORTC_ROT,W
    MOVWF	PORTC		; Habilitamos el siguiente display
    INCF	FSR,F		; Apunta al proximo dato a mostrar
    BTFSS	AUX_MSG,1
    BCF		PORTA,0
    BTFSS	PORTC_ROT,7		; Ya mostro los 3 digitos?
    GOTO	DIGITO_A    	; No mostro todo, va al proximo digito
    BTFSS	PIR1,0		; Si ya mostro todo, vemos si ya ha desbordado el Timer1
    GOTO	DIGITOS_A	; Si no lo hizo vuelve a refrescar
    DECFSZ	AUX_MSG		; Decrementamos la variable 
    GOTO	DIGIT_A		; Si no es cero, se resetea el timer y vuelve a refrescar
    RETURN			; Si lo es, ya mostro el mensaje por 2 segundos y vuelve
    
;*******************************************************************************
; Subrutina para dar tiempo a los distintos displays. Como tenemos 3 displays, cada
; uno de ellos esta encendido por aproximadamente 6 ms.
RETARDO_DISP
    BSF		STATUS,RP0
    BCF		OPTION_REG,T0CS	; Hacemos que TMR0 comienze a contar
    BCF		STATUS,RP0
    BCF		INTCON,T0IF	; Limpiamos la flag del Timer0
    BCF		INTCON,T0IE	; Deshabilitamos interrupcion por TMR0
    MOVLW	.233		; Cargamos el Timer0 con 234, lo que lo haria desbordar a los 6ms 
    MOVWF	TMR0
    BTFSS	INTCON,T0IF
    GOTO	$-1
    RETURN
    
;*******************************************************************************
; Subrutina para darle el tiempo de adquisicion necesario al ADC (11,5 ms)
ADQTIME
    BSF		STATUS,RP0
    BCF		OPTION_REG,T0CS	; Hacemos que TMR0 comienze a contar
    BCF		STATUS,RP0
    BCF		INTCON,T0IF	; Limpiamos la flag del Timer0
    MOVLW	.211		; Cargamos el Timer0 con 214, lo que lo haria desbordar a los 12ms 
    MOVWF	TMR0
    BTFSS	INTCON,T0IF
    GOTO	$-1
    RETURN

;*******************************************************************************
    
    END