# Dispenser_16F887

Este trabajo práctico consiste en un “Dosificador controlado de alcohol en gel”. Utilizaremos un microcontrolador 16F887 para 
realizar las funcionalidades principales del sistema.

El sistema en cuestión consta de un dispenser de alcohol en gel con una capacidad fija (CAPACIDAD EN LÍTROS), 
y un sensor de proximidad que detecta cuando la mano de un usuario se acerca, entregando una dosis de alcohol en gel para desinfectar. 
Luego de cargar el dispensador, la persona que administre el dispositivo debe de informarle al PIC, mediante un teclado matricial, cuál es la 
cantidad crítica de alcohol en gel que considere como mínima. Cuando el dosificador llegue a esta cantidad, el PIC debe transmitir el mensaje “LOW” 
por 3 displays 7-segmentos, y sonará un buzzer por unos segundos (DEFINIR). 

Además, el sistema cuenta con un medidor de batería que, al alcanzar otro nivel crítico (DEFINIR), transmitirá el mensaje “BAT” por los displays.
Las funcionalidades mencionadas anteriormente son manejadas por interrupciones para utilizar el menor porcentaje de batería posible. 
Es por esta razón también que el dispositivo entra en modo “idle” (Sleep) luego de cierto tiempo sin estímulos externos.

