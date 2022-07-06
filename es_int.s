* Inicializa el SP y el PC
**************************
        ORG     $0
        DC.L    $8000           * Pila
        DC.L    INICIO4          * PC
		
        ORG     $400


		IMR_2: DS.B 2			*copia de IMR

* Definicion de equivalencias
*********************************

MR1A    EQU     $effc01       * de modo A (escritura)
MR2A    EQU     $effc01       * de modo A (2 escritura)
SRA     EQU     $effc03       * de estado A (lectura)
CSRA    EQU     $effc03       * de seleccion de reloj A (escritura)
CRA     EQU     $effc05       * de control A (escritura)
TBA     EQU     $effc07       * buffer transmision A (escritura)
RBA     EQU     $effc07       * buffer recepcion A  (lectura)

ACR		EQU		$effc09	      * de control auxiliar
IMR     EQU     $effc0B       * de mascara de interrupcion A (escritura)
ISR     EQU     $effc0B       * de estado de interrupcion A (lectura)
IVR		EQU		$effc19		  * de vector de interrupcion

MR1B    EQU     $effc11       * de modo B (escritura)
MR2B    EQU     $effc11       * de modo B (2 escritura)
CRB     EQU     $effc15	      * de control A (escritura)
TBB     EQU     $effc17       * buffer transmision B (escritura)
RBB		EQU		$effc17       * buffer recepcion B (lectura)
SRB     EQU     $effc13       * de estado B (lectura)
CSRB	EQU		$effc13       * de seleccion de reloj B (escritura)


CR		EQU	$0D	      * Carriage Return
LF		EQU	$0A	      * Line Feed
FLAGT	EQU	2	      * Flag de transmision
FLAGR   EQU 0	      * Flag de recepcion



**************************** INIT *************************************************************
INIT:
	
        MOVE.B          #%00010000,CRA      * Reinicia el puntero MR1A
        MOVE.B          #%00000011,MR1A     * 8 bits por caracter A.
        MOVE.B          #%00000000,MR2A     * Eco desactivado A.
        MOVE.B          #%11001100,CSRA     * Velocidad = 38400 bps.
		MOVE.B          #%00000000,ACR      * seleccionamos el conjunto 1
        MOVE.B          #%00000101,CRA      * Transmision y recepcion activados A.
        
		MOVE.B    		#%00010000,CRB       * Reinicia el puntero MR1B
        MOVE.B    		#%00000011,MR1B      * 8 bits por caracter B.
        MOVE.B    		#%00000000,MR2B      * Eco desactivado B
        MOVE.B    		#%11001100,CSRB      * Velocidad = 38400 bps
		MOVE.B          #%00000101,CRB 		 * Transmision y recepcion activados B
		
		MOVE.B			#%00100010,IMR_2	 *interrupciones de recepcion habilitadas
		MOVE.B			IMR_2,IMR		 	 *copio el valor a IMR
		
		MOVE.B			#$40,IVR			 *vector de interrupcion establecido a 40
		MOVE.L 			#RTI,$100			 *actualiza la direccion de la rutina de interrupcion
		
    
	*inicializacion buffers
		BSR	 			INI_BUFS			*branch a subrutina INI_BUFS
	
		RTS *Retorno
**************************** FIN INIT *********************************************************

**************************** PRINT ************************************************************
PRINT:
	LINK 		A6,#-16 						
	MOVE.L  	A0,-4(A6)
    MOVE.L  	D1,-8(A6)
    MOVE.L  	D2,-12(A6)
	MOVE.L		D4,-16(A6)

	*limpiamos registros para cargar parametros de entrada, de salida y auxiliares
	EOR.L		D0,D0			* Inicializa 'Resultado' a 0 (XOR)
	EOR.L		D1,D1			* Inicializa 'Descriptor' a 0 (XOR)
	EOR.L		D2,D2			* Inicializa 'Tamaño' a 0 (XOR)
	EOR.L       D4,D4			* Inicializa un auxiliar para 'Resultado'

	MOVE.L 		8(A6),A0 		* Carga Parametro 'Buffer'
	MOVE.W		12(A6),D1		* Carga Parametro 'Descriptor'
	MOVE.W 		14(A6),D2 		* Carga Parametro 'Tamaño'

    CMP.W 		#0,D2			* Si 'Tamaño' == 0 --> fin
	BEQ 		FIN_PRINT
    CMP.W       #0,D2           * Tamaño < 0 --> error
    BLT         ERROR_PRINT

	CMP.W		#0,D1			* comparo el descriptor con el 0 (linea A)	
	BEQ			ESP_PRINTA
	CMP.W		#1,D1			* comparo el descriptor con el 1 (linea B)
	BEQ			ESPPRINTB

	BRA			ERROR_PRINT		* el descriptor no es ni A ni B

*bucle de sincronizacion con la linea

ESP_PRINTA: 	

	MOVE.B      (A0)+,D1	    * Carga caracter del buffer en D1	
	MOVE.L 		#2,D0			* Parametro 'buffer' para LEECAR linea A,transmision
	BSR         ESCCAR			* Llamada a ESCCAR, resultado en D0
	CMP.L 		#-1,D0 			* buffer interno lleno, terminar
	BEQ			FIN_PRINT

	BSET		#0,IMR_2		* TxRDYA = 1 se solicita una interrupción
	MOVE.B 		IMR_2,IMR		

	ADD.L       #1,D4     	    * Incremento 'Resultado'
	SUB.W       #1,D2     	    * Un caracter menos, Decremento 'Tamaño'
	
	BNE         ESP_PRINTA		* Siguen quedando caracteres
    BRA         FIN_PRINT

ESPPRINTB: 

	MOVE.B      (A0)+,D1	   	* Carga caracter del buffer en D1
	MOVE.L 		#3,D0			* Parametro 'buffer' para LEECAR linea B,transmision
	BSR         ESCCAR			* Llamada a ESCCAR, resultado en D0
	CMP 		#-1,D0		* buffer interno lleno, terminar
	BEQ			FIN_PRINT
	
	BSET		#4,IMR_2		* TxRDYB = 1 se solicita una interrupción
	MOVE.B 		IMR_2,IMR		
	
	ADD.L       #1,D4     	    * Incremento 'Resultado'
	SUB.W       #1,D2     	    * Un caracter menos, Decremento 'Tamaño'
	
	BNE         ESPPRINTB		* Siguen quedando caracteres
    BRA         FIN_PRINT

ERROR_PRINT:
	MOVE.L 		#-1,D0
  	BRA 		FINPRINT2

FIN_PRINT:
	MOVE.L		D4,D0			* movemos del auxiliar a D0 nuestro resultado


FINPRINT2:
								* restauramos los registros
		
	MOVE.L  	-16(A6),D4
    MOVE.L  	-12(A6),D2
    MOVE.L  	-8(A6),D1
    MOVE.L  	-4(A6),A0
    UNLK    	A6

	RTS                         
**************************** FIN PRINT ********************************************************

**************************** SCAN ************************************************************
SCAN: 
	LINK 		A6,#-16  						
	MOVE.L  	A0,-4(A6)
    MOVE.L  	D1,-8(A6)
    MOVE.L  	D2,-12(A6)
    MOVE.L  	D3,-16(A6)

	*limpiamos registros para cargar parametros de entrada,de salida y auxiliares

	EOR.L		D1,D1			* Inicializa 'Descriptor' a 0 (XOR)
	EOR.L		D2,D2			* Inicializa 'Tamaño' a 0 (XOR)
	EOR.L		D0,D0			* Inicializa 'Resultado' a 0 (XOR)
	EOR.L       D3,D3			* Inicializa un auxiliar para 'Resultado'

	MOVE.L 		8(A6),A0 		* Carga Parametro 'Buffer'
	MOVE.W		12(A6),D1		* Carga Parametro 'Descriptor'
	MOVE.W 		14(A6),D2 		* Carga Parametro 'Tamaño'


    CMP.W		#0,D2			* Si 'Tamaño' == 0 --> fin
	BEQ 		FIN_SCAN
	CMP.W 		#0,D2			* Si 'Tamaño" < 0 --> error
	BLT			ERROR_SCAN

	CMP.W		#0,D1			* comparo el descriptor con el 0 (linea A)		
	BEQ			ESP_SCANA
	CMP.W		#1,D1			* comparo el descriptor con el 1 (linea B)
	BEQ			ESPSCANB
	
	BRA			ERROR_SCAN		* el descriptor no es ni A ni B

ESP_SCANA:

  	MOVE.L      #0,D0           * Parametro 'buffer' para LEECAR linea A,recepcion
	
    BSR         LEECAR			* llamada a LEECAR, resultado en D0
	CMP.L 		#-1,D0 			* buffer interno vacio, terminar
	BEQ			FIN_SCAN
	
    MOVE.B      D0,(A0)+        * Almaceno caracter en buffer
	ADD.L 		#1,D3      		* Incremento 'Resultado'
	SUB.W 		#1,D2     		* Un caracter menos, Decremento 'Tamaño'
	
	BNE 		ESP_SCANA	 	* Siguen quedando caracteres 
    BRA         FIN_SCAN


ESPSCANB:	

    MOVE.L      #1,D0          * Parametro 'buffer' para LEECAR linea B,recepcion
	BSR         LEECAR			* Llamada a LEECAR, resultado en D0
	CMP.L 		#-1,D0 			* buffer interno vacio, terminar
	BEQ			FIN_SCAN
	
    MOVE.B      D0,(A0)+        * Almaceno caracter en buffer
	ADD.L 		#1,D3      		* Incremento 'Resultado'
	SUB.W 		#1,D2     		* Un caracter menos, Decremento 'Tamaño'
	
	BNE 		ESPSCANB	 	* Siguen quedando caracteres 
	BRA         FIN_SCAN
	
ERROR_SCAN:
	MOVE.L 		#-1,D0
  	BRA 		FINSCAN2

FIN_SCAN:
    MOVE.L      D3,D0			* movemos del auxiliar a D0 nuestro resultado
	
FINSCAN2:								* restauramos los registros
	MOVE.L  	-16(A6),D3
    MOVE.L  	-12(A6),D2
    MOVE.L  	-8(A6),D1
    MOVE.L  	-4(A6),A0
    UNLK    	A6
    RTS

**************************** FIN SCAN ********************************************************

**************************** RTI ************************************************************
RTI:
	LINK    A6,#-12 
	MOVE.L  D0,-4(A6)
    MOVE.L  D1,-8(A6)
	MOVE.L  D2,-12(A6)
	 							* Guardamos los registros que se usan en la pila


ESP_RTI:
	MOVE.B  	ISR,D2			* Identificación de la fuente de interrupción
    AND.B   	IMR_2,D2	
								* Interrupciones de recepcion
	BTST 		#1,D2				*RxRDYA = 1 --> Z = 0. Recepcion A activada
	BNE 		REC_A
	BTST 		#5,D2				*RxRDYB = 1 --> Z = 0. Recepcion B activada
	BNE 		REC_B			* Interrupciones de transmision
	BTST 		#0,D2				*TxRDYA = 1 --> Z = 0. Transmision A activada
	BNE 		TRA_A
	BTST 		#4,D2				*TxRDYA = 1 --> Z = 0. Transmision B activada
	BNE 		TRA_B	

	BRA			FIN_RTI 		* No hay interrupcion	


								* Interrupciones de recepcion
								* FIFO de recepcion no vacia --> ESCCAR
REC_A:
	MOVE.L      #0,D0          	* Parametro 'buffer' para ESCCAR linea A,recepcion                 
    EOR.L		D1,D1			* Parametro 'Caracter' a 0 para ESCCAR
    MOVE.B 		RBA,D1          * Almaceno 'caracter' en D1 
    BSR 		ESCCAR			* Llamada a ESCCAR, resultado en D0
    CMP.L 		#-1,D0          
    BEQ 		FIN_RTI			* buffer interno lleno, terminar
    BRA 		ESP_RTI  		* siguen quedando caracteres

REC_B:
	MOVE.L      #1,D0          	* Parametro 'buffer' para ESCCAR linea B,recepcion                 
    EOR.L		D1,D1			* Parametro 'Caracter' a 0 para ESCCAR
    MOVE.B 		RBB,D1          * Almaceno 'caracter' en D1 
    BSR 		ESCCAR			* Llamada a ESCCAR, resultado en D0
    CMP.L 		#-1,D0          
    BEQ 		FIN_RTI			* buffer interno lleno, terminar
    BRA 		ESP_RTI  		* siguen quedando caracteres 
								* Interrupciones de transmision
								* linea preparada para transmitir
TRA_A:
	MOVE.L      #2,D0          	* Parametro 'buffer' para LEECAR linea A,transmision                  
    BSR 		LEECAR			* Llamada a LEECAR, resultado en D0
    CMP.L 		#-1,D0          
    BEQ 		FIN_A			* buffer interno vacio --> FIN_A
    MOVE.B  	D0,TBA  		* Carga caracter de D0 en TBA
	BRA 		ESP_RTI

TRA_B:
	MOVE.L      #3,D0          	* Parametro 'buffer' para LEECAR linea B,transmision                  
    BSR 		LEECAR			* Llamada a LEECAR, resultado en D0
    CMP.L 		#-1,D0          
    BEQ 		FIN_B			* buffer interno vacio --> FIN_B
    MOVE.B  	D0,TBB  		* Carga caracter de D0 en TBB
	BRA 		ESP_RTI

FIN_A:
	BCLR    	#0,IMR_2    * Inhibe interrupciones transmision A
    MOVE.B 		IMR_2,IMR      	* Actualizamos el IMR
    BRA 		FIN_RTI

FIN_B:

	BCLR    #4,IMR_2      * Inhibe interrupciones transmision B
    MOVE.B  IMR_2,IMR		* Actualizamos el IMR
	BRA 	FIN_RTI


FIN_RTI:

	MOVE.L  -12(A6),D2			
	MOVE.L  -8(A6),D1
    MOVE.L  -4(A6),D0
    UNLK    A6
    RTE

**************************** FIN RTI ********************************************************

**************************** PROGRAMA PRINCIPAL **********************************************
    ORG $5000

BUFFER:     DS.B    2100 	* Buffer para lectura y escritura de caracteres
PARDIR:     DC.L    0 		* Direccion que se pasa como parametro
PARTAM:     DC.W    0 		* Tama~no que se pasa como parametro
CONTC:      DC.W    0 		* Contador de caracteres a imprimir
DESA:       EQU     0 		* Descriptor linea A
DESB:       EQU     1 		* Descriptor linea B
TAMBS:      EQU     4 		* Tama~no de bloque para SCAN
TAMBP:      EQU     7 		* Tama~no de bloque para PRINT

* Manejadores de excepciones
INICIO:     MOVE.L #BUS_ERROR,8 		* Bus error handler
            MOVE.L #ADDRESS_ER,12 		* Address error handler
            MOVE.L #ILLEGAL_IN,16 		* Illegal instruction handler
            MOVE.L #PRIV_VIOLT,32 		* Privilege violation handler
            MOVE.L #ILLEGAL_IN,40 		* Illegal instruction handler
            MOVE.L #ILLEGAL_IN,44 		* Illegal instruction handler

            BSR INIT
            MOVE.W #$2000,SR 			* Permite interrupciones

BUCPR:      MOVE.W #TAMBS,PARTAM 		* Inicializa parametro de tama~no
            MOVE.L #BUFFER,PARDIR 		* Parametro BUFFER = comienzo del buffer
OTRAL:      MOVE.W PARTAM,-(A7) 		* Tamano de bloque
            MOVE.W #DESB,-(A7) 			* Puerto A
            MOVE.L PARDIR,-(A7) 		* Direccion de lectura
ESPL:       BSR SCAN
            ADD.L #8,A7 				* Restablece la pila
            ADD.L D0,PARDIR 			* Calcula la nueva direccion de lectura
            SUB.W D0,PARTAM 			* Actualiza el numero de caracteres leidos
            BNE OTRAL 					* Si no se han leido todas los caracteres

            MOVE.W #TAMBS,CONTC 		* Inicializa contador de caracteres a imprimir
            MOVE.L #BUFFER,PARDIR 		* Parametro BUFFER = comienzo del buffer
OTRAE:      MOVE.W #TAMBP,PARTAM 		* Tama~no de escritura = Tama~no de bloque
ESPE:       MOVE.W PARTAM,-(A7) 		* Tama~no de escritura
            MOVE.W #DESB,-(A7) 			* Puerto B
            MOVE.L PARDIR,-(A7) 		* Direccion de escritura
            BSR PRINT
            ADD.L #8,A7 				* Restablece la pila
            ADD.L D0,PARDIR 			* Calcula la nueva direccion del buffer
            SUB.W D0,CONTC 				* Actualiza el contador de caracteres
            BEQ SALIR 					* Si no quedan caracteres se acaba
            SUB.W D0,PARTAM 			* Actualiza el tama~no de escritura
            BNE ESPE 					* Si no se ha escrito todo el bloque se insiste
            CMP.W #TAMBP,CONTC 			* Si el no de caracteres que quedan es menor que
            							* el tama~no establecido se imprime ese numero

            BHI OTRAE 					* Siguiente bloque
            MOVE.W CONTC,PARTAM
            BRA ESPE 					* Siguiente bloque

SALIR:      BRA BUCPR

**************************** FIN PROGRAMA PRINCIPAL ******************************************

BUS_ERROR:  
    BREAK                    * Bus error handler
    NOP

ADDRESS_ER:
    BREAK                    * Address error handler
    NOP

ILLEGAL_IN:
    BREAK                    * Illegal instruction handler
    NOP

PRIV_VIOLT:
    BREAK                    * Priviledge violation handler
    NOP
    


*** Prueba scan 1: inserta 100 caracteres en el buffer interno de recepcion de la linea A (0)
*** se leen 100. Resultado esperado -> D0 = 64 (100 en hex)

p_scan_1:
    MOVE.L  #$100,D3
    MOVE.L  #0,D7
    BSR     BUCESNFF
    MOVE.W  #$100,-(A7)
    MOVE.W  #0,-(A7)
    MOVE.L  #$5000,-(A7)
    BSR     SCAN
    ADD.L #8,A7 * Restablece la pila
    CMP.L   #$100,D0
    BNE     AMENTET

*** Prueba scan 2: inserta 100 caracteres en el buffer interno de recepcion de la linea B (1)
*** se leen 25 caracteres 4 veces de tal manera que el buffer quede vacio. Resultado esperado:
*** D0 = 19 (25 en hex). Pos $50FF en memoria = pos $D01
                                  
p_scan_2:
            MOVE.L  #$94,D3         * 25 * 4 es 94 en hex
            MOVE.L  #1,D7
            BSR    BUCESNFF
            MOVE.L  #0,D4
p_s_2_b:    CMP.L   #4,D4
            BEQ     p_s_2_e
            MOVE.W  #$25,-(A7)
            MOVE.W  #1,-(A7)
            MOVE.L  #$5000,-(A7)
            BSR     SCAN
            ADD.L #8,A7 * Restablece la pila
            CMP.L   #$25,D0
            BNE     AMENTET
            ADD.L   #1,D4
            BRA     p_s_2_b
p_s_2_e:    MOVE.L  D3,D4


*** Prueba scan 3: inserta 10 caracteres y se intenta leer 20 en el buffer interno de recepcion A (0)
*** El resultado esperado es 10 en D0 y guardar desde 00 hasta 09 en la posicion $5000 de memoria
p_scan_3:   MOVE.L  #10,D3
            MOVE.L  #0,D7
            BSR     BUCESNFF
            MOVE.W  #20,-(A7)
            MOVE.W  #0,-(A7)
            MOVE.L  #$5000,-(A7)
            BSR     SCAN
            ADD.L #8,A7 * Restablece la pila
            CMP.L   #10,D0
            BNE     AMENTET
            MOVE.L  D3,D4



p_scan_4:
            MOVE.L  #3000,D3         * 25 * 4 es 94 en hex
            MOVE.L  #0,D7
            BSR     BUCESNFF
            MOVE.L  #0,D5
p_s_4_b:    CMP.L   #300,D5
            BEQ     p_s_4_e
            MOVE.W  #10,-(A7)
            MOVE.W  #0,-(A7)
            MOVE.L  #$4000,-(A7)
            BSR     SCAN
            ADD.L   #8,A7           * Restablece la pila
            CMP.L   #10,D0
            BNE     AMENTET
            ADD.L   #1,D5
            BRA     p_s_4_b
p_s_4_e:    MOVE.L  D3,D5


INICIO4:
            BSR INIT
            MOVE.W #$2000,SR    *Permite interrupciones
            MOVE.W #0,D0
            MOVE.W #1,D1
            BSR ESCCAR
            MOVE.W #0,D0
            MOVE.W #2,D1
            BSR ESCCAR
            MOVE.W #0,D0
            MOVE.W #13,D1
            BSR ESCCAR
            MOVE.L #0,A0 
            MOVE.L #BUFFER,A0
            MOVE.W #1,D0
            MOVE.W #3,D3
            MOVE.W D3,-(A7)
            MOVE.W D0,-(A7)
            MOVE.L A0,-(A7)     * 32E4
            BSR SCAN            * SEE 2A60
            BREAK





    *██████╗ ██████╗ ██╗███╗   ██╗████████╗*
  ***██╔══██╗██╔══██╗██║████╗  ██║╚══██╔══╝***
*****██████╔╝██████╔╝██║██╔██╗ ██║   ██║   *****
*****██╔═══╝ ██╔══██╗██║██║╚██╗██║   ██║   *****
  ***██║     ██║  ██║██║██║ ╚████║   ██║   ***
    *╚═╝     ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝   ╚═╝   *

*** Prueba print 1: inserta $100 caracteres en el buffer interno de transmision B (3),
*** estos caracteres estan contenidos a partir de la dir mem $5000.

p_prt_1:
            MOVE.W  #$100,-(A7)
            MOVE.W  #1,-(A7)
            MOVE.L  #$5000,-(A7)
            BSR     PRINT
            ADD.L #8,A7 * Restablece la pila
            CMP.L   #$100,D0
            BNE     AMENTET
            MOVE.L  D3,D4

*** Prueba print 2: inserta 2000 caracteres en el buffer interno de transmision B (3),
*** estos estan contenido a partir de la dir mem $5001. Para que empiece por 1 y no por 0
*** Como ya se han escrito antes $100, no se podran escribir todos, devolviendo el numero
*** de caracteres escritos en D0 con valor: 6D0

p_prt_2:
            MOVE.W  #2000,-(A7)
            MOVE.W  #1,-(A7)
            MOVE.L  #$5001,-(A7)
            BSR     PRINT
            ADD.L #8,A7 * Restablece la pila
            CMP.L   #$6D0,D0
            BNE     AMENTET
            MOVE.L  D3,D4

*** Two error cases: wrong descriptor, wrong read number
p_prt_3:
            MOVE.W  #2000,-(A7)
            MOVE.W  #-1,-(A7)
            MOVE.L  #$5001,-(A7)
            BSR     PRINT
            ADD.L #8,A7 * Restablece la pila
            CMP.L   #-1,D0
            BNE     AMENTET
            MOVE.L  D3,D4

p_prt_4:
            MOVE.W  #-5,-(A7)
            MOVE.W  #1,-(A7)
            MOVE.L  #$5001,-(A7)
            BSR     PRINT
            ADD.L #8,A7 * Restablece la pila
            CMP.L   #-1,D0
            BNE     AMENTET
            MOVE.L  D3,D4


p_prt_5:
            MOVE.W  #0,-(A7)
            MOVE.W  #1,-(A7)
            MOVE.L  #$5001,-(A7)
            BSR     PRINT
            ADD.L #8,A7 * Restablece la pila
            CMP.L   #0,D0
            BNE     AMENTET
            MOVE.L  D3,D4



    * █████╗ ██╗   ██╗██╗  ██╗██╗██╗     ██╗ █████╗ ██████╗ *
  ***██╔══██╗██║   ██║╚██╗██╔╝██║██║     ██║██╔══██╗██╔══██╗***
*****███████║██║   ██║ ╚███╔╝ ██║██║     ██║███████║██████╔╝*****
*****██╔══██║██║   ██║ ██╔██╗ ██║██║     ██║██╔══██║██╔══██╗*****
  ***██║  ██║╚██████╔╝██╔╝ ██╗██║███████╗██║██║  ██║██║  ██║***
    *╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚══════╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝*

* La rutina AMENTET hace referencia a la diosa egipcia homonima la cual era la patrona de las puertas
* del inframundo en el que esperaba a los difuntos que no superaban las pruebas en su camino al paraiso.
* En este caso, las subrutinas que no superen las pruebas, las esperara AMENTET que para indicar su fallo
* y mandarlas corregir.
AMENTET:
            MOVE.L  #-1,D0
            MOVE.L  #-1,D1
            MOVE.L  #-1,D2
            MOVE.L  #-1,D3
            MOVE.L  #-1,D4
            MOVE.L  #-1,D5
            MOVE.L  #-1,D6
            MOVE.L  #-1,D7
            MOVE.L  #-1,A0
            MOVE.L  #-1,A1
            MOVE.L  #-1,A2
            MOVE.L  #-1,A3
            MOVE.L  #-1,A4
            MOVE.L  #-1,A5
            BREAK
                                                       
BUCESN1S:
    EOR D4,D4 *Contador de elementos
    buc1:
        MOVE.L #1,D1 *Variable 1 que queremos meter en el buffer n veces
        MOVE.L D7,D0
        BSR ESCCAR
        ADD.L #1,D4
        CMP.L D3,D4
        BNE buc1
    RTS



BUCESNFF:
    EOR D4,D4
    EOR D1,D1
    buc2:
        MOVE.L D7,D0
        BSR ESCCAR
        ADD.L #1,D4
        ADD.L #1,D1
        CMP.L #$100,D1
        BEQ D1ZERO
        BRA FINB1
        D1ZERO: EOR D1,D1
        FINB1: CMP.L D3,D4
        BNE buc2
    RTS




BUCESN09:
    EOR D4,D4
    EOR D1,D1
    buc4:
        MOVE.L D7,D0
        BSR ESCCAR
        ADD.L #1,D4
        ADD.L #1,D1
        CMP.L #10,D1
        BEQ D1ZERO2
        BRA FINB12
        D1ZERO2: EOR D1,D1
        FINB12: CMP.L D3,D4
        BNE buc4
    RTS


BUCLEEN:
    EOR D4,D4
    buc3:
        MOVE.L D7,D0
        BSR LEECAR
        ADD.L #1,D4
        CMP.L D3,D4
        BNE buc3
    RTS

COMPCOR: CMP.L #0,D0
    BEQ BIEN
    BRA MAL

COMPF: CMP #-1,D0
    BEQ BIEN
    BRA MAL

BIEN: MOVE.L #$abcdef10,D5
    BRA FINC

MAL: MOVE.L #-1,D5

FINC: BREAK


INCLUDE bib_aux.s	 
